import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ApiService {
  static String currentUserRole = 'staff';
  static const String baseUrl = "https://api.samcafe.id.vn"; 
  static late IO.Socket socket;

  static void initSocket() {
    socket = IO.io(baseUrl, IO.OptionBuilder()
      .setTransports(['websocket']).disableAutoConnect().build());
    socket.connect();
  }

  static Future<String> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      currentUserRole = data['role']; 
      return data['role']; 
    } else {
      throw Exception('Sai tài khoản hoặc mật khẩu');
    }
  }

  static Future<void> changePassword(String username, String oldPassword, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/change-password'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
      body: jsonEncode({'username': username, 'oldPassword': oldPassword, 'newPassword': newPassword}),
    );
    if (response.statusCode != 200) throw Exception('Đổi mật khẩu thất bại!');
  }

  static Future<List<dynamic>> getProducts() async {
    // Tạo dấu thời gian để đánh lừa bộ nhớ đệm
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final response = await http.get(
      Uri.parse('$baseUrl/api/products?t=$timestamp'), // Gắn thời gian vào đuôi link
      headers: {
        'Content-Type': 'application/json', 
        'ngrok-skip-browser-warning': 'true',
        // Bùa cấm trình duyệt lưu cache
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );
    if (response.statusCode == 200) return jsonDecode(response.body) as List<dynamic>;
    throw Exception('Failed to load products');
  }

  static Future<void> createProduct(String id, String name, int price, int categoryId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/products'),
      headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
      body: jsonEncode({"id": id, "name": name, "price": price, "categoryId": categoryId}),
    );
    if (response.statusCode != 200) throw Exception("Không thể thêm món");
  }

  static Future<void> editProduct(String id, String name, int price) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/products/$id'),
      headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
      body: jsonEncode({"name": name, "price": price}),
    );
    if (response.statusCode != 200) throw Exception("Không thể cập nhật món");
  }

  static Future<void> deleteProduct(String id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/products/$id'),
      headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
    );
    if (response.statusCode != 200) throw Exception("Không thể xóa món");
  }

  static Future<List<dynamic>> getInvoices() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/invoices'),
      headers: {"ngrok-skip-browser-warning": "true"}
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    throw Exception("Lỗi lấy danh sách hóa đơn");
  }

  static Future<Map<String, dynamic>> getShiftSummary() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/shift-summary'),
      headers: {"ngrok-skip-browser-warning": "true"}
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    throw Exception("Lỗi lấy báo cáo kết ca");
  }

  static Future<void> payInvoice(String tableId, String paymentMethod) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/invoices/pay'),
      headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
      body: jsonEncode({"tableId": tableId, "paymentMethod": paymentMethod}),
    );
    if (response.statusCode != 200) throw Exception("Lỗi khi chốt bill");

    // 🚨 Đợi Database cập nhật xong (500ms) rồi mới hét lên cho Quản lý biết
    if (socket.connected) {
      Future.delayed(const Duration(milliseconds: 500), () {
        socket.emit('trigger_global_sync');
      });
    }
  }

  static Future<List<dynamic>> getTables() async {
    // Tạo dấu thời gian để đánh lừa bộ nhớ đệm
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    final response = await http.get(
      Uri.parse('$baseUrl/api/tables?t=$timestamp'), // Gắn thời gian vào đuôi link
      headers: {
        'Content-Type': 'application/json', 
        'ngrok-skip-browser-warning': 'true',
        // Bùa cấm trình duyệt lưu cache
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    throw Exception('Lỗi tải danh sách bàn');
  }

  static Future<void> createTable(String tableName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/tables'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
      body: jsonEncode({'name': tableName}),
    );
    if (response.statusCode != 200) throw Exception('Không thể thêm bàn mới');
  }

  static Future<void> renameTable(String tableId, String newName) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/tables/$tableId'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
      body: jsonEncode({'name': newName}),
    );
    if (response.statusCode != 200) throw Exception('Không thể đổi tên bàn');
  }

  static Future<bool> transferTable(String oldTableId, String newTableId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/invoices/transfer'),
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: jsonEncode({'oldTableId': oldTableId, 'newTableId': newTableId}),
      );
      if (response.statusCode == 200) {
        // 🚨 Đợi Database cập nhật xong (500ms)
        if (socket.connected) {
          Future.delayed(const Duration(milliseconds: 500), () {
            socket.emit('trigger_global_sync');
          });
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> deleteTable(String tableId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/tables/$tableId'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
    );
    if (response.statusCode != 200) throw Exception('Không thể xóa bàn');
  }

  static Future<void> splitAndPay(String tableId, String paymentMethod, List<Map<String, dynamic>> itemsToPay) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/invoices/split-pay'),
      headers: {"Content-Type": "application/json", "ngrok-skip-browser-warning": "true"},
      body: jsonEncode({"tableId": tableId, "paymentMethod": paymentMethod, "itemsToPay": itemsToPay}),
    );
    if (response.statusCode != 200) throw Exception("Lỗi khi thanh toán tách món");

    // 🚨 Đợi Database cập nhật xong (500ms)
    if (socket.connected) {
      Future.delayed(const Duration(milliseconds: 500), () {
        socket.emit('trigger_global_sync');
      });
    }
  }

  static Future<Map<String, dynamic>> getRevenueReport(String filter) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/revenue-report?filter=$filter'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) return data['data'];
    }
    throw Exception('Lỗi tải báo cáo doanh thu');
  }

  static Future<void> resetStaffPassword(String staffUsername, String newPassword) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/reset-staff-password'),
      headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
      body: jsonEncode({'staffUsername': staffUsername, 'newPassword': newPassword}),
    );
    if (response.statusCode != 200) throw Exception('Lỗi khi đổi mật khẩu nhân viên');
  }

  // 🔥 GỬI BẾP ĐÃ ĐƯỢC BỌC THÉP TƯỜNG LỬA CHỐNG LỪA 100%
  static Future<void> updateInvoice(String tableId, List<Map<String, dynamic>> items) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/invoices'),
      headers: {
        "Content-Type": "application/json",
        "ngrok-skip-browser-warning": "true", // Thẻ thông hành
      },
      body: jsonEncode({"tableId": tableId, "items": items}),
    );
    
    if (response.statusCode != 200) throw Exception("Lỗi kết nối Server");

    // Ép xác nhận JSON để không bị Tường lửa lừa gửi file HTML
    try {
      final data = jsonDecode(response.body);
      if (data['success'] != true) throw Exception();
    } catch (e) {
      throw Exception("Tường lửa chặn kết nối! Lệnh gửi bếp thất bại.");
    }
  }

  static Future<List<dynamic>> getActiveInvoices() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // BẮT BUỘC DÙNG http.post NHƯ CODE GỐC CỦA BẠN
      final response = await http.post(
        Uri.parse('$baseUrl/api/invoices/active?t=$timestamp'),
        headers: {
          'Content-Type': 'application/json', 
          'ngrok-skip-browser-warning': 'true',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
        body: jsonEncode({}), 
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) return data['data']; 
      }
      return [];
    } catch (e) {
      print("Lỗi getActiveInvoices: $e");
      return [];
    }
  }
}