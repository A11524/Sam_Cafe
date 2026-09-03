const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Hàm tạo mới hóa đơn hoặc cập nhật thêm món vào bàn
const createOrUpdateInvoice = async (req, res, io) => {
  const { tableId, items } = req.body; 
  const normalizedTableId = tableId.toLowerCase(); 
  const normalizedTableName = tableId.toUpperCase();

  try {
    const result = await prisma.$transaction(async (tx) => {
      let table = await tx.table.findFirst({ where: { id: normalizedTableId } });
      if (!table) {
        table = await tx.table.create({ data: { id: normalizedTableId, name: normalizedTableName } });
      }
      
      const realTableId = table.id;

      let invoice = await tx.invoice.findFirst({
        where: { tableId: realTableId, status: 'PENDING' }
      });

      if (!invoice) {
        invoice = await tx.invoice.create({
          data: { 
            id: `HD${Date.now()}`, 
            tableId: realTableId, 
            subtotal: 0, 
            totalAmount: 0,
            status: 'PENDING' // 🔥 BỔ SUNG: Bắt buộc hóa đơn phải ở trạng thái Đang Treo
          }
        });
      } else {
        // Xóa chi tiết cũ để ghi đè danh sách mới nhất từ Flutter gửi lên (Tránh bị nhân đôi)
        await tx.invoiceDetail.deleteMany({
          where: { invoiceId: invoice.id }
        });
      }

      let newTotal = 0;
      for (let item of items) {
        await tx.invoiceDetail.create({
          data: {
            invoiceId: invoice.id,
            productId: item.productId,
            quantity: item.quantity, // Lấy chính xác số lượng Flutter gửi
            price: item.price,
            note: item.note || ""
          }
        });
        newTotal += (item.price * item.quantity); 
      }

      const updatedInvoice = await tx.invoice.update({
        where: { id: invoice.id },
        data: { 
          subtotal: newTotal, 
          totalAmount: newTotal,
          status: 'PENDING' // 🔥 BỔ SUNG: Khóa chặt trạng thái, không cho phép biến thành PAID
        },
        include: { details: true }
      });

      return updatedInvoice;
    });

    io.emit('table_updated', { tableId: normalizedTableName, status: 'HAS_ORDER', invoice: result });
    res.status(200).json({ success: true, data: result });

  } catch (error) {
    console.error("Lỗi createOrUpdateInvoice:", error);
    res.status(500).json({ success: false, message: 'Lỗi khi tạo hóa đơn' });
  }
};


const transferTable = async (req, res, io) => {
  const { oldTableId, newTableId } = req.body; // Lấy chính xác tên bàn từ Flutter gửi lên

  try {
    const updatedInvoiceData = await prisma.$transaction(async (tx) => {
      // 1. Tìm ID thật cho BÀN CŨ
      let oldTable = await tx.table.findFirst({ where: { name: oldTableId } });
      if (!oldTable) oldTable = await tx.table.findFirst({ where: { id: oldTableId } }).catch(() => null);
      if (!oldTable) throw new Error('Bàn cũ không tồn tại trong hệ thống!');

      // 2. TÌM HOẶC TỰ ĐỘNG TẠO ID thật cho BÀN MỚI
      let newTable = await tx.table.findFirst({ where: { name: newTableId } });
      if (!newTable) newTable = await tx.table.findFirst({ where: { id: newTableId } }).catch(() => null);
      if (!newTable) newTable = await tx.table.create({ data: { id: `T${Date.now()}`, name: newTableId } }); 

      const realOldId = oldTable.id;
      const realNewId = newTable.id;

      // 3. Tìm hóa đơn đang treo ở bàn cũ
      const existingInvoice = await tx.invoice.findFirst({
        where: { tableId: realOldId, status: 'PENDING' }
      });

      if (!existingInvoice) {
        throw new Error('Bàn này chưa có hóa đơn nào để chuyển!');
      }

      // 4. Kiểm tra xem bàn mới có khách ngồi chưa
      const newTableInvoice = await tx.invoice.findFirst({
        where: { tableId: realNewId, status: 'PENDING' }
      });

      if (newTableInvoice) {
        throw new Error('Bàn mới đang có người ngồi, không thể chuyển!');
      }

      // 5. Cập nhật hóa đơn sang bàn mới VÀ LẤY LUÔN CHI TIẾT MÓN
      const updatedInvoice = await tx.invoice.update({
        where: { id: existingInvoice.id },
        data: { tableId: realNewId },
        include: { details: true } // Kéo theo danh sách món ăn
      });

      return updatedInvoice;
    });

    // Phát tín hiệu cũ để Flutter tải lại danh sách bàn (cần thiết cho bàn Tạm)
    io.emit('table_transferred', { oldTableId, newTableId });

    // THÊM TÍN HIỆU MỚI: Báo cho PC biết Bàn Mới có món gì (Dùng chính xác tên gốc)
    io.emit('table_updated', { 
      tableId: newTableId, 
      status: 'HAS_ORDER', 
      invoice: updatedInvoiceData 
    });

    // THÊM TÍN HIỆU MỚI: Báo cho PC biết Bàn Cũ đã trống
    io.emit('table_updated', { 
      tableId: oldTableId, 
      status: 'PAID' 
    });

    res.status(200).json({ success: true, message: 'Chuyển bàn thành công!' });

  } catch (error) {
    console.error(error);
    const msg = error.message || 'Lỗi hệ thống khi chuyển bàn';
    res.status(400).json({ success: false, message: msg });
  }
};


// 2. HÀM TÁCH MÓN (Đã vá lỗi Bàn Tạm)
const splitAndPayInvoice = async (req, res, io) => {
  const { tableId, paymentMethod, itemsToPay } = req.body; 
  const normalizedTableId = tableId.toLowerCase();
  const normalizedTableName = tableId.toUpperCase();

  try {
    const emitData = await prisma.$transaction(async (tx) => {
      // 1. Quét tìm Bàn ở mọi định dạng chữ Hoa/Thường
      let table = await tx.table.findFirst({
        where: {
          OR: [
            { name: tableId }, { name: normalizedTableName },
            { id: tableId }, { id: normalizedTableId }
          ]
        }
      });

      // 2. Dù không tìm thấy bảng table (do lỗi rác), vẫn truy sát thẳng vào bảng invoice!
      const originalInvoice = await tx.invoice.findFirst({
        where: {
          tableId: { in: [table ? table.id : '', tableId, normalizedTableId, normalizedTableName] },
          status: 'PENDING'
        },
        include: { details: true }
      });

      if (!originalInvoice) throw new Error("Không tìm thấy đơn hàng đang treo");

      const splitTotal = itemsToPay.reduce((sum, item) => sum + (item.price * item.quantity), 0);

      const newPaidInvoice = await tx.invoice.create({
        data: {
          id: `HD${Date.now()}_SPLIT`,
          tableId: originalInvoice.tableId, // Lưu đúng id rác cũ
          status: 'PAID',
          paymentMethod: paymentMethod,
          subtotal: splitTotal,
          totalAmount: splitTotal,
        }
      });

      for (let splitItem of itemsToPay) {
        await tx.invoiceDetail.create({
          data: { invoiceId: newPaidInvoice.id, productId: splitItem.productId, quantity: splitItem.quantity, price: splitItem.price, note: "Tách món" }
        });

        const oldDetail = originalInvoice.details.find(d => d.productId === splitItem.productId);
        if (oldDetail) {
          const remainQty = oldDetail.quantity - splitItem.quantity;
          if (remainQty <= 0) {
            await tx.invoiceDetail.delete({ where: { id: oldDetail.id } });
          } else {
            await tx.invoiceDetail.update({ where: { id: oldDetail.id }, data: { quantity: remainQty } });
          }
        }
      }

      // KIỂM TRA PHẦN CÒN LẠI VÀ CHUẨN BỊ DỮ LIỆU SOCKET
      const remainingDetails = await tx.invoiceDetail.findMany({ where: { invoiceId: originalInvoice.id } });
      if (remainingDetails.length === 0) {
        await tx.invoice.delete({ where: { id: originalInvoice.id } });
        return { tableId: normalizedTableName, status: 'PAID' }; // Báo cho PC biết bàn đã trống
      } else {
        const remainTotal = remainingDetails.reduce((sum, d) => sum + (d.price * d.quantity), 0);
        const updatedOriginal = await tx.invoice.update({
          where: { id: originalInvoice.id },
          data: { subtotal: remainTotal, totalAmount: remainTotal },
          include: { details: true } 
        });
        return { tableId: normalizedTableName, status: 'HAS_ORDER', invoice: updatedOriginal };
      }
    });

    io.emit('table_updated', emitData);
    res.status(200).json({ success: true, data: emitData.invoice, message: 'Thanh toán tách món thành công!' });

  } catch (error) {
    console.error("Lỗi splitAndPayInvoice:", error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi hệ thống khi tách bill' });
  }
};

// HÀM THANH TOÁN (Đã tháo khóa Bàn Tạm)
const payInvoice = async (req, res, io) => {
  const { tableId, paymentMethod } = req.body;
  const normalizedTableName = tableId.toUpperCase();
  const normalizedTableId = tableId.toLowerCase();

  try {
    const result = await prisma.$transaction(async (tx) => {
      let table = await tx.table.findFirst({
        where: {
          OR: [
            { name: tableId }, { name: normalizedTableName },
            { id: tableId }, { id: normalizedTableId }
          ]
        }
      });

      // 🔥 CHỔI QUÉT RÁC TỐI THƯỢNG: Cứ có hóa đơn tên này là gạch nợ luôn, khỏi kiểm tra bàn!
      await tx.invoice.updateMany({
        where: {
          tableId: { in: [table ? table.id : '', tableId, normalizedTableId, normalizedTableName] },
          status: 'PENDING'
        },
        data: {
          status: 'PAID',
          paymentMethod: paymentMethod, 
          createdAt: new Date() 
        }
      });

      // Trả về true luôn để lướt qua mọi lỗi!
      return true;
    });

    io.emit('table_updated', { tableId: normalizedTableName, status: 'PAID' });
    res.status(200).json({ success: true, message: 'Thanh toán thành công' });

  } catch (error) {
    console.error("Lỗi payInvoice:", error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi hệ thống' });
  }
};

const getRevenueReport = async (req, res) => {
  const { filter } = req.query; 
  
  let startDate = new Date();
  let endDate = new Date();

  startDate.setHours(0, 0, 0, 0);
  endDate.setHours(23, 59, 59, 999);

  if (filter === 'week') {
    const day = startDate.getDay();
    const diff = startDate.getDate() - day + (day === 0 ? -6 : 1); 
    startDate.setDate(diff);
  } else if (filter === 'month') {
    startDate.setDate(1);
  } else if (filter === 'lastMonth') {
    startDate.setMonth(startDate.getMonth() - 1);
    startDate.setDate(1);
    endDate = new Date(startDate.getFullYear(), startDate.getMonth() + 1, 0);
    endDate.setHours(23, 59, 59, 999);
  }

  try {
    const invoices = await prisma.invoice.findMany({
      where: {
        status: 'PAID',
        createdAt: {
          gte: startDate,
          lte: endDate
        }
      },
      orderBy: { createdAt: 'desc' } 
    });

    let totalCash = 0;
    let totalTransfer = 0;

    invoices.forEach(inv => {
      if (inv.paymentMethod === 'cash') totalCash += inv.totalAmount;
      if (inv.paymentMethod === 'transfer') totalTransfer += inv.totalAmount;
    });

    res.status(200).json({
      success: true,
      data: {
        totalRevenue: totalCash + totalTransfer,
        totalCash: totalCash,
        totalTransfer: totalTransfer,
        invoices: invoices
      }
    });
  } catch (error) {
    console.error("Lỗi lấy báo cáo doanh thu:", error);
    res.status(500).json({ success: false, message: 'Lỗi hệ thống khi lấy báo cáo' });
  }
};

// HÀM MỚI: Lấy danh sách các bàn đang có khách (hóa đơn PENDING)
// HÀM MỚI: Lấy danh sách các bàn đang có khách (hóa đơn PENDING)
// HÀM MỚI: Lấy danh sách các bàn đang có khách (hóa đơn PENDING)
// HÀM MỚI: Lấy danh sách các bàn đang có khách (hóa đơn PENDING)
// HÀM MỚI: Lấy danh sách các bàn đang có khách (hóa đơn PENDING)
const getActiveInvoices = async (req, res) => {
  try {
    // 1. Đấm vỡ cache của Prisma Database
    await prisma.$executeRaw`SELECT 1`; 

    const activeInvoices = await prisma.invoice.findMany({
      where: { status: 'PENDING' },
      include: { table: true, details: true }
    });

    const formattedInvoices = activeInvoices.map(inv => ({
      ...inv,
      tableId: inv.table ? inv.table.name.toUpperCase() : inv.tableId.toUpperCase() 
    }));

    // 2. KHÓA MÕM CACHE TRÌNH DUYỆT (BẮT BUỘC PHẢI CÓ ĐOẠN NÀY)
    res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
    res.setHeader('Pragma', 'no-cache');
    res.setHeader('Expires', '0');
    res.setHeader('Surrogate-Control', 'no-store');

    res.status(200).json({ 
      success: true, 
      timestamp: Date.now(), // Ép tải mới
      data: formattedInvoices 
    });
  } catch (error) {
    console.error("Lỗi lấy hóa đơn đang treo:", error);
    res.status(500).json({ success: false, message: 'Lỗi server' });
  }
};

module.exports = { 
  createOrUpdateInvoice, 
  transferTable,
  splitAndPayInvoice,
  payInvoice,
  getRevenueReport,
  getActiveInvoices
};