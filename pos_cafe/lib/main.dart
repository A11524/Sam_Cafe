import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'api_service.dart';

void main() async {
  // Bắt buộc gọi dòng này để khởi tạo bộ nhớ
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mở Két sắt kiểm tra trạng thái
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String? userRole = prefs.getString('userRole');

  // Nạp lại quyền cho ApiService
  if (isLoggedIn && userRole != null) {
    ApiService.currentUserRole = userRole;
  }

  runApp(MyApp(isLoggedIn: isLoggedIn, userRole: userRole));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String? userRole;

  const MyApp({super.key, required this.isLoggedIn, this.userRole});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Cafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF005BAC)),
        useMaterial3: true,
      ),
      // Bắn thẳng vào MainScreen nếu đã đăng nhập từ trước
      home: (isLoggedIn && userRole != null)
          ? MainScreen(userRole: userRole!)
          : const LoginScreen(), 
    );
  }
}