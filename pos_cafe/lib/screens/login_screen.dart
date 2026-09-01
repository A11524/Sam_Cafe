import 'package:flutter/material.dart';
import '../api_service.dart'; // Nối với file API của bạn
import 'main_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _obscurePassword = true;
  bool _isLoading = false; 

  // BIẾN MỚI: Theo dõi xem người dùng đang chọn tab Quản lý hay Nhân viên (Mặc định là Nhân viên)
  bool _isManagerTab = false; 

  // ==========================================
  // HÀM ĐĂNG NHẬP (GỌI API)
  // ==========================================
  void _handleLogin() async {
    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập tài khoản và mật khẩu!');
      return;
    }

    setState(() {
      _errorMessage = '';
      _isLoading = true; 
    });

    try {
      String role = await ApiService.login(username, password);
      
      if (_isManagerTab && role != 'manager') {
        setState(() => _errorMessage = 'Tài khoản này không có quyền Quản lý!');
        return;
      }

      // 🔥 CẤT TRẠNG THÁI VÀO KÉT SẮT
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', role);

      if (!mounted) return;
      _navigateToMain(role);
      
    } catch (e) {
      setState(() {
        _errorMessage = 'Sai tài khoản hoặc mật khẩu!';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false); 
    }
  }

  void _navigateToMain(String role) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
    builder: (context) => MainScreen(userRole: role), // <-- Chuyển vào MainScreen thay vì POSScreen
  ),
    );
  }

  // ==========================================
  // HỘP THOẠI ĐỔI MẬT KHẨU (GỌI API)
  // ==========================================
  void _showChangePasswordDialog(BuildContext context) {
    final usernameController = TextEditingController(text: _usernameController.text); 
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isDialogLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Đổi mật khẩu", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Vui lòng nhập mật khẩu hiện tại để xác thực quyền đổi mật khẩu mới.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: "Tên đăng nhập",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: oldPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Mật khẩu CŨ",
                      prefixIcon: Icon(Icons.lock_clock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Mật khẩu MỚI",
                      prefixIcon: Icon(Icons.lock_reset),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              if (!isDialogLoading)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005BAC),
                  foregroundColor: Colors.white,
                ),
                onPressed: isDialogLoading
                    ? null
                    : () async {
                        final username = usernameController.text.trim();
                        final oldPass = oldPasswordController.text.trim();
                        final newPass = newPasswordController.text.trim();

                        if (username.isEmpty || oldPass.isEmpty || newPass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng điền đầy đủ thông tin!"), backgroundColor: Colors.red));
                          return;
                        }

                        if (oldPass == newPass) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mật khẩu mới phải khác mật khẩu cũ!"), backgroundColor: Colors.orange));
                          return;
                        }

                        setStateDialog(() => isDialogLoading = true);

                        try {
                          await ApiService.changePassword(username, oldPass, newPass);

                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Đổi mật khẩu thành công! Hãy đăng nhập bằng mật khẩu mới."), backgroundColor: Colors.green));
                          
                          _passwordController.clear(); 
                          setState(() { _errorMessage = ''; }); 
                        } catch (e) {
                          setStateDialog(() => isDialogLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sai tài khoản hoặc mật khẩu cũ!"), backgroundColor: Colors.red));
                        }
                      },
                child: isDialogLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Xác nhận đổi"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store, size: 64, color: Color(0xFF005BAC)),
              const SizedBox(height: 16),
              const Text("Đăng nhập hệ thống", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              // ==========================================
              // THANH CHỌN VAI TRÒ (NHÂN VIÊN / QUẢN LÝ)
              // ==========================================
              Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isManagerTab = false;
                            _errorMessage = '';
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: !_isManagerTab ? const Color(0xFF005BAC) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Nhân viên", 
                            style: TextStyle(
                              color: !_isManagerTab ? Colors.white : Colors.grey.shade700, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isManagerTab = true;
                            _errorMessage = '';
                          });
                        },
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _isManagerTab ? const Color(0xFF005BAC) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "Quản lý", 
                            style: TextStyle(
                              color: _isManagerTab ? Colors.white : Colors.grey.shade700, 
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Tên đăng nhập",
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Mật khẩu",
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                onSubmitted: (_) => _handleLogin(), 
              ),
              
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_errorMessage, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BAC), foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("ĐĂNG NHẬP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              // ==========================================
              // CHỈ HIỆN ĐỔI MẬT KHẨU KHI Ở TAB "QUẢN LÝ"
              // ==========================================
              if (_isManagerTab) ...[
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _showChangePasswordDialog(context),
                  child: const Text(
                    "Đổi mật khẩu?",
                    style: TextStyle(
                      color: Color(0xFF005BAC), 
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ] else ...[
                // Thêm SizedBox trống để giữ form không bị giật lên khi chuyển đổi tab
                const SizedBox(height: 64),
              ]
            ],
          ),
        ),
      ),
    );
  }
}