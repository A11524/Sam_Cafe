const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

// Map từ Tên -> ID Flutter (Dùng cho API Lấy danh sách)
const categoryMapping = {
  'Cà Phê & Đá Xay': 1,
  'Trà & Lipton': 2,
  'Sinh Tố & Sữa Chua': 3,
  'Soda & Giải Khát': 4,
  'Điểm Tâm': 5
};

// BỔ SUNG: Map ngược từ ID Flutter -> Tên (Dùng cho API Thêm món)
const flutterIdToName = {
  1: 'Cà Phê & Đá Xay',
  2: 'Trà & Lipton',
  3: 'Sinh Tố & Sữa Chua',
  4: 'Soda & Giải Khát',
  5: 'Điểm Tâm'
};

// 1. Lấy danh sách món 
const getProducts = async (req, res) => {
  try {
    const products = await prisma.product.findMany({
      include: { category: true } // Lấy luôn thông tin danh mục kèm theo
    });

    // Format lại dữ liệu trước khi trả về cho Flutter
    const formattedProducts = products.map(p => {
      const catName = p.category ? p.category.name : '';
      const mappedId = categoryMapping[catName] || 1;

      return {
        id: p.id,
        name: p.name,
        price: p.price,
        categoryId: mappedId // Ép về đúng số 1, 2, 3, 4, 5 khớp với Flutter
      };
    });

    res.status(200).json(formattedProducts);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Lỗi lấy danh sách sản phẩm' });
  }
};

// 2. Thêm món mới (FIX LỖI TRÙNG ID P2002)
const createProduct = async (req, res) => {
  // 🔥 KHÔNG LẤY 'id' TỪ FLUTTER GỬI LÊN NỮA
  const { name, price, categoryId } = req.body; 
  
  try {
    let realCategoryId = parseInt(categoryId);
    const categoryName = flutterIdToName[realCategoryId];

    // Tìm ID thực tế của danh mục
    if (categoryName) {
      const dbCategory = await prisma.category.findFirst({
        where: { name: categoryName }
      });
      
      if (dbCategory) {
        realCategoryId = dbCategory.id;
      }
    }

    // Chuẩn bị dữ liệu lưu
    const dataToSave = {
      id: 'SP' + Date.now(), // 🔥 Tự động tạo ID độc nhất (VD: SP171630987123)
      name: name,
      price: parseInt(price),
      categoryId: realCategoryId 
    };

    // Gọi Prisma lưu vào Database
    const newProduct = await prisma.product.create({
      data: dataToSave
    });
    
    res.status(200).json({ success: true, data: newProduct });

  } catch (error) {
    console.error("❌ LỖI KHI THÊM MÓN:", error);
    res.status(500).json({ success: false, message: error.message || 'Lỗi server' });
  }
};

// 3. Cập nhật món (Sửa giá/tên)
const updateProduct = async (req, res) => {
  const { id } = req.params;
  const { name, price } = req.body;
  try {
    const updated = await prisma.product.update({
      where: { id: id },
      data: { name, price: parseInt(price) }
    });
    res.status(200).json({ success: true, data: updated });
  } catch (error) {
    console.error("❌ LỖI KHI CẬP NHẬT MÓN:", error);
    res.status(500).json({ success: false, message: 'Lỗi khi cập nhật món' });
  }
};

// 4. Xóa món (BỔ SUNG MỚI)
const deleteProduct = async (req, res) => {
  const { id } = req.params;
  
  try {
    const deleted = await prisma.product.delete({
      where: { id: id }
    });
    
    res.status(200).json({ 
      success: true, 
      message: 'Đã xóa món thành công', 
      data: deleted 
    });
  } catch (error) {
    console.error("❌ LỖI KHI XÓA MÓN:", error);
    
    // Prisma sẽ trả về mã lỗi P2025 nếu không tìm thấy bản ghi để xóa
    if (error.code === 'P2025') {
      return res.status(404).json({ success: false, message: 'Không tìm thấy món cần xóa' });
    }
    
    res.status(500).json({ success: false, message: 'Lỗi khi xóa món' });
  }
};

// Đừng quên export thêm deleteProduct nhé
module.exports = { getProducts, createProduct, updateProduct, deleteProduct };