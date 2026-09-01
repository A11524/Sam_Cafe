import 'package:flutter/material.dart';
import '../utils/responsive.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'transaction_screen.dart';
import 'shift_end_screen.dart';
import 'revenue_screen.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Thư viện Két sắt

class MainScreen extends StatefulWidget {
  final String userRole; 
  const MainScreen({super.key, required this.userRole});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  bool get isManager => widget.userRole == 'manager';

  final GlobalKey _stackKey = GlobalKey();

  final List<Widget> _screens = const [
    POSScreen(),
    ProductsScreen(),
    TransactionsScreen(),
    ShiftEndScreen(),
    RevenueScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    bool isMobile = Responsive.isMobile(context);
    
    final Widget contentStack = IndexedStack(
      key: _stackKey,
      index: _selectedIndex,
      children: _screens,
    );

    return Scaffold(
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                if (!isManager && index != 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chỉ quản lý mới được xem!"), backgroundColor: Colors.red));
                  return;
                }
                setState(() => _selectedIndex = index);
              },
              selectedItemColor: const Color(0xFF005BAC),
              unselectedItemColor: Colors.grey,
              type: BottomNavigationBarType.fixed,
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.point_of_sale), label: 'Bán hàng'),
                BottomNavigationBarItem(icon: Icon(Icons.inventory, color: isManager ? null : Colors.grey), label: 'Hàng hóa'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long, color: isManager ? null : Colors.grey), label: 'Giao dịch'),
                BottomNavigationBarItem(icon: Icon(Icons.lock_clock, color: isManager ? null : Colors.grey), label: 'Kết ca'),
                BottomNavigationBarItem(icon: Icon(Icons.bar_chart, color: isManager ? null : Colors.grey), label: 'Doanh thu'),
              ],
            )
          : null,
      
      body: SafeArea(
        child: isMobile
          ? contentStack
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (int index) {
                    if (!isManager && index != 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Chỉ quản lý mới được xem!"), backgroundColor: Colors.red));
                      return;
                    }
                    setState(() => _selectedIndex = index);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    const NavigationRailDestination(icon: Icon(Icons.point_of_sale), label: Text('Bán hàng')),
                    NavigationRailDestination(icon: Icon(Icons.inventory, color: isManager ? null : Colors.grey), label: Text('Hàng hóa', style: TextStyle(color: isManager ? null : Colors.grey))),
                    NavigationRailDestination(icon: Icon(Icons.receipt_long, color: isManager ? null : Colors.grey), label: Text('Giao dịch', style: TextStyle(color: isManager ? null : Colors.grey))),
                    NavigationRailDestination(icon: Icon(Icons.lock_clock, color: isManager ? null : Colors.grey), label: Text('Kết ca', style: TextStyle(color: isManager ? null : Colors.grey))),
                    NavigationRailDestination(icon: Icon(Icons.bar_chart, color: isManager ? null : Colors.grey), label: Text('Doanh thu', style: TextStyle(color: isManager ? null : Colors.grey))),
                  ],
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: IconButton(
                          icon: const Icon(Icons.logout, color: Colors.red),
                          onPressed: () async { // 🔥 Đổi thành async để gọi Két sắt
                            // 1. Xóa sạch chìa khóa trong Két sắt
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();

                            if (!context.mounted) return;
                            
                            // 2. Xóa lịch sử trang và văng ra màn Login
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: Container(
                    color: Colors.grey.shade50,
                    child: contentStack,
                  ),
                ),
              ],
            ),
      ),
    );
  }
}