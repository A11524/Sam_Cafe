const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Lấy danh sách toàn bộ hóa đơn
const getInvoices = async (req, res) => {
  try {
    const invoices = await prisma.invoice.findMany({
      where: {
        status: 'PAID' // 🔥 QUAN TRỌNG NHẤT: Chỉ lấy những hóa đơn ĐÃ THANH TOÁN
      },
      include: {
        table: true, 
        details: true 
      },
      orderBy: {
        createdAt: 'desc' // Sắp xếp bill mới thanh toán lên trên cùng
      }
    });

    res.status(200).json({ success: true, data: invoices });
  } catch (error) {
    console.error("Lỗi lấy danh sách giao dịch:", error);
    res.status(500).json({ success: false, message: 'Lỗi server khi lấy lịch sử giao dịch' });
  }
};

// 2. Tính tổng doanh thu ca làm việc hôm nay (MỚI THÊM)
const getShiftSummary = async (req, res) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0); // Đặt mốc thời gian về 00:00:00 sáng hôm nay

    // Lấy tất cả hóa đơn được tạo từ đầu ngày đến giờ
    const invoicesToday = await prisma.invoice.findMany({
      where: {
        createdAt: { gte: today }
      }
    });

    // Tính tổng tiền
    const totalRevenue = invoicesToday.reduce((sum, inv) => sum + inv.totalAmount, 0);
    
    res.status(200).json({
      success: true,
      data: {
        totalRevenue: totalRevenue,
        invoiceCount: invoicesToday.length,
      }
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Lỗi lấy báo cáo ca' });
  }
};

// Hàm chốt bill, đổi trạng thái thành PAID
const payInvoice = async (req, res) => {
  // 1. Hứng thêm paymentMethod từ ứng dụng Flutter gửi lên
  const { tableId, paymentMethod } = req.body; 
  
  try {
    // Tìm hóa đơn đang treo (PENDING) của bàn này và chốt sổ
    await prisma.invoice.updateMany({
      where: { 
        tableId: tableId, 
        status: 'PENDING' 
      },
      data: { 
        status: 'PAID', // Đổi thành Đã thanh toán
        createdAt: new Date(), // Cập nhật thời gian xuất bill là ngay lúc bấm
        
        // 2. DÒNG QUAN TRỌNG: Lưu phương thức thanh toán vào Database (mặc định là 'cash')
        paymentMethod: paymentMethod || 'cash' 
      }
    });
    res.status(200).json({ success: true, message: 'Đã chốt bill' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ success: false, message: 'Lỗi khi chốt bill' });
  }
};

// Cập nhật lại dòng xuất khẩu ở cuối file (Thêm payInvoice vào)
module.exports = { getInvoices, getShiftSummary, payInvoice };