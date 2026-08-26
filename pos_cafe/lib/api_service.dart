import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ApiService {
  static String currentUserRole = 'staff';
  // Thay thế bằng địa chỉ IP máy tính đang chạy Backend
  // (Nếu dùng máy ảo Android, hãy để là '10.0.2.2')
  // static const String baseUrl = "http://192.168.100.241:3000"; 
  // static const String baseUrl = "[https://api.samcafe.id.vn](https://api.samcafe.id.vn)";
  static const String baseUrl = "https://api.samcafe.id.vn"; 
  static late IO.Socket socket;

  // Khởi tạo Socket
  static void initSocket() {
    socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build());
    socket.connect();
  }

  // ===============================================
  // THÊM MỚI: HÀM GỌI API ĐĂNG NHẬP
  // ===============================================
  static Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true', 
      },
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // 2. LƯU LẠI QUYỀN VÀO BIẾN TOÀN CỤC SAU KHI ĐĂNG NHẬP THÀNH CÔNG
      currentUserRole = data['role']; 
      
      return data['role']; 
    } else {
      throw Exception('Sai tài khoản hoặc mật khẩu');
    }
  }

  // ===============================================
  // THÊM MỚI: HÀM GỌI API ĐỔI MẬT KHẨU
  // ===============================================
  static Future<void> changePassword(String username, String oldPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/change-password'), // Chú ý: Đường dẫn API đổi mật khẩu
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'username': username,
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Đổi mật khẩu thất bại, sai mật khẩu cũ!');
    }
  }

  // Bổ sung hàm này vào bên trong class ApiService
  // Sửa List<dynamic> thay vì Map<String, dynamic>
  static Future<List<dynamic>> getProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/products'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true', // <-- THÊM DÒNG NÀY ĐỂ VƯỢT RÀO NGROK
      },
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>; 
    } else {
      throw Exception('Failed to load products');
    }
  }

  // Thêm món mới
  static Future<void> createProduct(String id, String name, int price, int categoryId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/products'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"id": id, "name": name, "price": price, "categoryId": categoryId}),
    );
    if (response.statusCode != 200) throw Exception("Không thể thêm món");
  }

  // Sửa món
  static Future<void> editProduct(String id, String name, int price) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/products/$id'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name, "price": price}),
    );
    if (response.statusCode != 200) throw Exception("Không thể cập nhật món");
  }

  // ===============================================
  // THÊM MỚI: HÀM GỌI API XÓA MÓN
  // ===============================================
  static Future<void> deleteProduct(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/products/$id'),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true", // Giữ nguyên header này để vượt rào Ngrok giống các hàm khác
      },
    );
    
    if (response.statusCode != 200) {
      throw Exception("Không thể xóa món");
    }
  }

  // Lấy lịch sử giao dịch
  static Future<List<dynamic>> getInvoices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/invoices'),
      headers: {
        "ngrok-skip-browser-warning": "true" // Vượt rào Ngrok
      }
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    throw Exception("Lỗi lấy danh sách hóa đơn");
  }

  // Lấy báo cáo kết ca hôm nay
  static Future<Map<String, dynamic>> getShiftSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/shift-summary'),
      headers: {
        "ngrok-skip-browser-warning": "true" // Vượt rào Ngrok
      }
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    throw Exception("Lỗi lấy báo cáo kết ca");
  }

  // Chốt bill - Thanh toán
  // Chốt bill - Thanh toán có chọn phương thức
  static Future<void> payInvoice(String tableId, String paymentMethod) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/invoices/pay'),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({
        "tableId": tableId, 
        "paymentMethod": paymentMethod, // 'cash' hoặc 'transfer'
      }),
    );
    if (response.statusCode != 200) {
      throw Exception("Lỗi khi chốt bill");
    }
  }

  // ===============================================
  // LẤY DANH SÁCH BÀN
  // ===============================================
  static Future<List<dynamic>> getTables() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/tables'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data']; // Trả về danh sách bàn
      }
    }
    throw Exception('Lỗi tải danh sách bàn');
  }

  // ===============================================
  // THÊM BÀN MỚI
  // ===============================================
  static Future<void> createTable(String tableName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tables'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'name': tableName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Không thể thêm bàn mới');
    }
  }

  // Đổi tên bàn
  static Future<void> renameTable(String tableId, String newName) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/tables/$tableId'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({'name': newName}),
    );

    if (response.statusCode != 200) {
      throw Exception('Không thể đổi tên bàn');
    }
  }

  // Gọi API Chuyển bàn
  static Future<bool> transferTable(String oldTableId, String newTableId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/invoices/transfer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'oldTableId': oldTableId,
          'newTableId': newTableId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print("Lỗi chuyển bàn: $e");
      return false;
    }
  }

  // ===============================================
  // XÓA BÀN
  // ===============================================
  static Future<void> deleteTable(String tableId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/tables/$tableId'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Không thể xóa bàn');
    }
  }

  // ===============================================
  // TÁCH MÓN VÀ THANH TOÁN
  // ===============================================
  static Future<void> splitAndPay(String tableId, String paymentMethod, List<Map<String, dynamic>> itemsToPay) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/invoices/split-pay'),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true",
      },
      body: jsonEncode({
        "tableId": tableId,
        "paymentMethod": paymentMethod,
        "itemsToPay": itemsToPay,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception("Lỗi khi thanh toán tách món");
    }
  }

  static Future<Map<String, dynamic>> getRevenueReport(String filter) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/revenue-report?filter=$filter'), // Đã khớp với route vừa tạo
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['data'];
      }
    }
    throw Exception('Lỗi tải báo cáo doanh thu');
  }

  // ===============================================
  // QUẢN LÝ ĐỔI MẬT KHẨU NHÂN VIÊN
  // ===============================================
  static Future<void> resetStaffPassword(String staffUsername, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/reset-staff-password'),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode({
        'staffUsername': staffUsername,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Lỗi khi đổi mật khẩu nhân viên');
    }
  }

  // Gọi API tạo/cập nhật hóa đơn (BỌC THÉP CHỐNG LỪA)
  // Tìm hàm updateInvoice và dán đè:
  static Future<void> updateInvoice(String tableId, List<Map<String, dynamic>> items) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/invoices'),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true", // Khóa an toàn tường lửa
      },
      body: jsonEncode({"tableId": tableId, "items": items}),
    );
    if (response.statusCode != 200) throw Exception("Lỗi kết nối Server");
  }

  // Tìm hàm getActiveInvoices và dán đè:
  static Future<List<dynamic>> getActiveInvoices() async {
    try {
      final response = await http.post( // Dùng POST để lấy dữ liệu mới nhất
        Uri.parse('$baseUrl/api/invoices/active'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['data']; 
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}