const express = require('express');
const http = require('http');
const cors = require('cors');
const { Server } = require('socket.io');
const path = require('path');



// BỔ SUNG: Import thêm hàm transferTable từ invoiceController
// BỔ SUNG: Import thêm hàm deleteProduct vào đây
const { getProducts, createProduct, updateProduct, deleteProduct } = require('./controllers/productController');

const { getInvoices, getShiftSummary } = require('./controllers/reportController');
const { 
  createOrUpdateInvoice, 
  transferTable, 
  splitAndPayInvoice, 
  payInvoice, // Đã đưa payInvoice về đúng nhà!
  getRevenueReport,
  getActiveInvoices
} = require('./controllers/invoiceController');

// Khai báo API tách bill

const app = express();
app.use(cors());
app.use(express.json());

// Khởi tạo HTTP server và nhúng Socket.io vào
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*", // Cho phép kết nối từ mọi thiết bị
    methods: ["GET", "POST"]
  }
});

// --- LẮNG NGHE KẾT NỐI REAL-TIME ---
io.on('connection', (socket) => {
  console.log(`[+] Thiết bị mới kết nối: ${socket.id}`);

  socket.on('disconnect', () => {
    console.log(`[-] Thiết bị ngắt kết nối: ${socket.id}`);
  });
});

// --- API ENDPOINTS ---
app.post('/api/invoices', (req, res) => {
  console.log("\n=== 🔴 CÓ ĐƠN HÀNG TỪ ĐIỆN THOẠI (GỬI BẾP) ===");
  console.log("Dữ liệu nhận được:", req.body);
  
  // 1. Tìm đúng bàn trên RAM để đổi màu (so sánh ngầm, KHÔNG sửa dữ liệu gốc)
  const receivedId = req.body.tableId;
  const table = tables.find(t => t.id.toLowerCase() === receivedId.toLowerCase() || t.name === receivedId);
  
  if (table) {
    table.status = 'có khách';
    // io.emit('table_updated', table); // Bắn Socket báo máy tính đổi màu bàn
  }
  
  // 2. Chuyền nguyên vẹn dữ liệu gốc (chữ S hoa) xuống cho Database xử lý
  createOrUpdateInvoice(req, res, io);
});

// BỔ SUNG: Route API Chuyển bàn
app.post('/api/invoices/transfer', (req, res) => transferTable(req, res, io));
app.post('/api/invoices/split-pay', (req, res) => splitAndPayInvoice(req, res, io));
app.post('/api/invoices/pay', (req, res) => payInvoice(req, res, io));

app.post('/api/products', createProduct);
app.get('/api/products', getProducts); 
app.put('/api/products/:id', updateProduct);
app.delete('/api/products/:id', deleteProduct); // 🔥 BỔ SUNG: Route xóa món
// 🔥 THÊM ĐÚNG DÒNG NÀY VÀO TRONG DANH SÁCH API:
app.post('/api/invoices/active', getActiveInvoices);
app.get('/api/invoices', getInvoices);
app.get('/api/shift-summary', getShiftSummary);
app.get('/api/revenue-report', getRevenueReport); // 🔥 BỔ SUNG: Route báo cáo doanh thu

// =========================================================
// DATABASE NGƯỜI DÙNG & BÀN TẠM THỜI (LƯU TRÊN RAM SERVER)
// =========================================================
// --- DATABASE BÀN ĐẦY ĐỦ BAN ĐẦU ---
let tables = [
  ...Array.from({ length: 18 }, (_, i) => ({ id: `s${i + 1}`, name: `S${i + 1}`, status: 'trống' })),
  ...Array.from({ length: 4 }, (_, i) => ({ id: `v${i + 1}`, name: `V${i + 1}`, status: 'trống' })),
  ...Array.from({ length: 4 }, (_, i) => ({ id: `n${i + 1}`, name: `N${i + 1}`, status: 'trống' })),
];

const fs = require('fs');


// Đường dẫn tới file users.json
const usersFilePath = path.join(__dirname, 'user.json');

// Hàm hỗ trợ đọc dữ liệu từ file
const getUsersFromFile = () => {
  try {
    const data = fs.readFileSync(usersFilePath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    return [];
  }
};

// Hàm hỗ trợ ghi dữ liệu vào file
const saveUsersToFile = (users) => {
  fs.writeFileSync(usersFilePath, JSON.stringify(users, null, 2), 'utf8');
};

// =========================================================
// 1. API ĐĂNG NHẬP
// =========================================================
app.post('/api/login', (req, res) => {
  console.log("\n=== CÓ YÊU CẦU ĐĂNG NHẬP TỪ FLUTTER ===");
  console.log("1. Dữ liệu nhận được:", req.body);
  
  const { username, password } = req.body;
  const users = getUsersFromFile();
  
  console.log("2. Danh sách tài khoản đọc từ file JSON:", users);

  const user = users.find(u => u.username === username && u.password === password);
  
  if (user) {
    console.log("-> KẾT QUẢ: Đăng nhập THÀNH CÔNG!");
    res.status(200).json({ success: true, role: user.role });
  } else {
    console.log("-> KẾT QUẢ: Đăng nhập THẤT BẠI!");
    res.status(401).json({ success: false, message: 'Sai tài khoản hoặc mật khẩu' });
  }
});

// =========================================================
// 2. API ĐỔI MẬT KHẨU
// =========================================================
app.post('/api/change-password', (req, res) => {
  const { username, oldPassword, newPassword } = req.body;
  let users = getUsersFromFile();
  const userIndex = users.findIndex(u => u.username === username && u.password === oldPassword);

  if (userIndex !== -1) {
    // Cập nhật mật khẩu mới và ghi đè lại vào file
    users[userIndex].password = newPassword;
    saveUsersToFile(users);
    
    res.status(200).json({ success: true, message: 'Đổi mật khẩu thành công' });
  } else {
    res.status(401).json({ success: false, message: 'Sai thông tin hoặc mật khẩu cũ' });
  }
});

// =========================================================
// API QUẢN LÝ ĐỔI MẬT KHẨU NHÂN VIÊN (Dùng file JSON)
// =========================================================
app.post('/api/admin/reset-staff-password', (req, res) => {
  const { staffUsername, newPassword } = req.body;
  
  try {
    // Đọc danh sách user từ file
    let users = getUsersFromFile();
    const userIndex = users.findIndex(u => u.username === staffUsername);

    if (userIndex !== -1) {
      // Cập nhật mật khẩu mới và ghi đè lại vào file
      users[userIndex].password = newPassword;
      saveUsersToFile(users);
      
      res.status(200).json({ success: true, message: 'Đã cấp lại mật khẩu mới cho nhân viên!' });
    } else {
      res.status(404).json({ success: false, message: 'Không tìm thấy tài khoản nhân viên này' });
    }
  } catch (error) {
    console.error("Lỗi reset password:", error);
    res.status(500).json({ success: false, message: 'Lỗi server khi đổi mật khẩu' });
  }
});

// =========================================================
// API QUẢN LÝ ĐỔI MẬT KHẨU NHÂN VIÊN
// =========================================================
app.post('/api/admin/reset-staff-password', async (req, res) => {
  const { staffUsername, newPassword } = req.body;
  
  try {
    // Tìm nhân viên trong Database
    const staff = await prisma.user.findUnique({
      where: { username: staffUsername }
    });

    if (!staff) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy tài khoản nhân viên này' });
    }

    // Cập nhật mật khẩu mới
    await prisma.user.update({
      where: { username: staffUsername },
      data: { password: newPassword }
    });

    res.status(200).json({ success: true, message: 'Đã cấp lại mật khẩu mới cho nhân viên!' });
  } catch (error) {
    console.error("Lỗi reset password:", error);
    res.status(500).json({ success: false, message: 'Lỗi server khi đổi mật khẩu' });
  }
});

// =========================================================
// 3. API BÀN (TABLES)
// =========================================================
// API Lấy danh sách bàn
app.get('/api/tables', (req, res) => {
  res.status(200).json({ success: true, data: tables });
});

// API Thêm bàn mới
app.post('/api/tables', (req, res) => {
  const { name } = req.body;
  if (!name) return res.status(400).json({ success: false, message: 'Tên bàn không được trống' });

  const newId = 'table_' + Date.now();
  const newTable = { id: newId, name: name, status: 'trống' };
  tables.push(newTable);
  
  io.emit('new_table_added', newTable);
  res.status(200).json({ success: true, data: newTable });
});

// API Đổi tên bàn
app.put('/api/tables/:id', (req, res) => {
  const { id } = req.params;
  const { name } = req.body;
  
  const table = tables.find(t => t.id === id);
  if (table) {
    table.name = name;
    io.emit('table_renamed', table);
    res.status(200).json({ success: true, data: table });
  } else {
    res.status(404).json({ success: false, message: 'Không tìm thấy bàn' });
  }
});

// API Xóa bàn
app.delete('/api/tables/:id', (req, res) => {
  const { id } = req.params;
  
  // Tìm vị trí của bàn trong mảng
  const index = tables.findIndex(t => t.id === id);
  if (index !== -1) {
    const deletedTable = tables.splice(index, 1)[0];
    
    // Bắn sự kiện socket để các máy khác tự động cập nhật xóa bàn
    io.emit('table_deleted', deletedTable);
    
    res.status(200).json({ success: true, message: 'Đã xóa bàn thành công', data: deletedTable });
  } else {
    res.status(404).json({ success: false, message: 'Không tìm thấy bàn cần xóa' });
  }
});

// Phát file tĩnh
app.use(express.static(path.join(__dirname, '../public')));

// Bắt mọi đường link (trừ api) trả về file html
// Bắt mọi đường link (trừ api) trả về file html - KHÔNG DÙNG DẤU * NỮA
app.use((req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

// --- CHẠY SERVER ---
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Server Backend đang chạy tại port ${PORT}`);
  console.log(`📡 Socket.io sẵn sàng nhận kết nối...`);
});