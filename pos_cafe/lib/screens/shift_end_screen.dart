import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';

// Import PrintService 
import '../utils/print_service.dart'; 

// Nhúng file trang đăng nhập
import 'login_screen.dart'; 

class ShiftEndScreen extends StatefulWidget {
  const ShiftEndScreen({super.key});

  @override
  State<ShiftEndScreen> createState() => _ShiftEndScreenState();
}

class _ShiftEndScreenState extends State<ShiftEndScreen> {
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
  
  final TextEditingController _startingCashController = TextEditingController();
  final TextEditingController _actualCashController = TextEditingController();
  
  bool _isLoading = true;
  List<dynamic> _allInvoices = [];
  
  int _totalRevenue = 0;
  int _invoiceCount = 0;
  
  // BIẾN MỚI: Tách riêng tiền mặt và chuyển khoản
  int _totalCash = 0;
  int _totalTransfer = 0;

  int _yesterdayRevenue = 0;
  int _dayBeforeRevenue = 0;
  
  int _startingCash = 0; 
  int _actualCash = 0;

  DateTime _currentTime = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchData();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _startingCashController.dispose();
    _actualCashController.dispose();
    super.dispose();
  }

  void _fetchData() async {
    try {
      final invoices = await ApiService.getInvoices();
      
      DateTime now = DateTime.now();
      DateTime yesterday = now.subtract(const Duration(days: 1));
      DateTime dayBeforeYesterday = now.subtract(const Duration(days: 2));

      int todayRev = 0;
      int todayCount = 0;
      int todayCash = 0;       // Tiền mặt hôm nay
      int todayTransfer = 0;   // Chuyển khoản hôm nay
      int yestRev = 0;
      int beforeRev = 0;

      for (var inv in invoices) {
        if (inv['createdAt'] == null) continue;
        DateTime date = DateTime.parse(inv['createdAt']).toLocal();
        int total = (inv['totalAmount'] ?? inv['total'] ?? 0).toInt();
        
        // Lấy phương thức thanh toán từ Server trả về (mặc định là cash nếu không có)
        String paymentMethod = inv['paymentMethod']?.toString() ?? 'cash';

        if (date.year == now.year && date.month == now.month && date.day == now.day) {
          todayRev += total;
          todayCount++;
          
          // PHÂN LOẠI TIỀN THEO PHƯƠNG THỨC THANH TOÁN
          if (paymentMethod == 'transfer') {
            todayTransfer += total;
          } else {
            todayCash += total;
          }
        } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
          yestRev += total;
        } else if (date.year == dayBeforeYesterday.year && date.month == dayBeforeYesterday.month && date.day == dayBeforeYesterday.day) {
          beforeRev += total;
        }
      }

      setState(() {
        _allInvoices = invoices;
        _totalRevenue = todayRev;
        _invoiceCount = todayCount;
        
        _totalCash = todayCash;           // Cập nhật state Tiền mặt
        _totalTransfer = todayTransfer;   // Cập nhật state Chuyển khoản
        
        _yesterdayRevenue = yestRev;
        _dayBeforeRevenue = beforeRev;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  // CÔNG THỨC MỚI: Két chỉ chứa Tiền mặt đầu ca + Tiền mặt bán được
  int get _expectedCash => _startingCash + _totalCash; 
  int get _difference => _actualCash - _expectedCash;

  @override
  Widget build(BuildContext context) {
    DateTime yesterday = _currentTime.subtract(const Duration(days: 1));
    DateTime dayBeforeYesterday = _currentTime.subtract(const Duration(days: 2));
    
    double screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 850;

    return SingleChildScrollView( 
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
            const Text("Kết ca / Bàn giao", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              "Thời điểm: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(_currentTime)}",
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.blueAccent, fontWeight: FontWeight.bold),
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Kết ca / Bàn giao", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text(
                  "Thời điểm chốt ca: ${DateFormat('HH:mm:ss - dd/MM/yyyy').format(_currentTime)}",
                  style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          
          if (isMobile) ...[
            _buildRevenueCard("Doanh thu Hôm nay", _totalRevenue, Colors.blue.shade700, true),
            const SizedBox(height: 12),
            _buildRevenueCard("Hôm qua (${DateFormat('dd/MM').format(yesterday)})", _yesterdayRevenue, Colors.grey.shade700, false),
            const SizedBox(height: 12),
            _buildRevenueCard("Hôm kia (${DateFormat('dd/MM').format(dayBeforeYesterday)})", _dayBeforeRevenue, Colors.grey.shade700, false),
          ] else ...[
            Row(
              children: [
                Expanded(child: _buildRevenueCard("Doanh thu Hôm nay", _totalRevenue, Colors.blue.shade700, true)),
                const SizedBox(width: 16),
                Expanded(child: _buildRevenueCard("Hôm qua (${DateFormat('dd/MM').format(yesterday)})", _yesterdayRevenue, Colors.grey.shade700, false)),
                const SizedBox(width: 16),
                Expanded(child: _buildRevenueCard("Hôm kia (${DateFormat('dd/MM').format(dayBeforeYesterday)})", _dayBeforeRevenue, Colors.grey.shade700, false)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40), 
              child: Center(child: CircularProgressIndicator())
            )
          else if (isMobile) ...[
            _buildSystemDataPanel(isMobile),
            const SizedBox(height: 16),
            _buildActualCountPanel(isMobile, context),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 1, child: _buildSystemDataPanel(isMobile)),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildActualCountPanel(isMobile, context)),
              ],
            ),
          ]
        ],
      ),
    );
  }

  // ========================================================
  // GIAO DIỆN SỐ LIỆU CA ĐƯỢC CẬP NHẬT CÓ CHUYỂN KHOẢN/TIỀN MẶT
  // ========================================================
  Widget _buildSystemDataPanel(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Số liệu ca hiện tại", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF005BAC))),
          const Divider(height: 32),
          
          _buildSummaryRow("Tổng số hóa đơn (Hôm nay):", "$_invoiceCount đơn", isBold: false),
          const SizedBox(height: 16),
          _buildSummaryRow("Tổng tiền bán được:", "${currencyFormat.format(_totalRevenue)} đ", isBold: true, color: Colors.green),
          const SizedBox(height: 12),
          
          // KHỐI HIỂN THỊ CHI TIẾT TIỀN MẶT / CHUYỂN KHOẢN
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
            child: Column(
              children: [
                _buildSummaryRow(" • Thu bằng Tiền mặt:", "${currencyFormat.format(_totalCash)} đ", isBold: true, color: Colors.blue, size: 13, labelColor: Colors.black54),
                const SizedBox(height: 8),
                _buildSummaryRow(" • Thu bằng Chuyển khoản:", "${currencyFormat.format(_totalTransfer)} đ", isBold: true, color: Colors.orange, size: 13, labelColor: Colors.black54),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text("Nhập tiền mặt đầu ca:", style: TextStyle(fontSize: isMobile ? 14 : 15, color: Colors.grey.shade700))),
              const SizedBox(width: 8),
              SizedBox(
                width: isMobile ? 120 : 140, 
                child: TextField(
                  controller: _startingCashController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(),
                    suffixText: "đ",
                  ),
                  onChanged: (value) {
                    setState(() {
                      _startingCash = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const Divider(height: 32),
          _buildSummaryRow("Tiền mặt cần có trong két:", "${currencyFormat.format(_expectedCash)} đ", isBold: true, color: Colors.red, size: 18),
        ],
      ),
    );
  }

  Widget _buildActualCountPanel(bool isMobile, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Kiểm đếm thực tế", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
          const Divider(height: 32),
          TextField(
            controller: _actualCashController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              labelText: "Nhập số tiền đếm được (VNĐ)",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.attach_money),
            ),
            onChanged: (value) {
              setState(() {
                _actualCash = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              });
            },
          ),
          const SizedBox(height: 32),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _difference == 0 ? Colors.green.shade50 : (_difference > 0 ? Colors.blue.shade50 : Colors.red.shade50),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _difference == 0 ? Colors.green : (_difference > 0 ? Colors.blue : Colors.red))
            ),
            child: Column(
              children: [
                const Text("Mức độ chênh lệch", style: TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text(
                  "${_difference > 0 ? '+' : ''}${currencyFormat.format(_difference)} đ",
                  style: TextStyle(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold, 
                    color: _difference == 0 ? Colors.green : (_difference > 0 ? Colors.blue : Colors.red)
                  )
                ),
                const SizedBox(height: 4),
                Text(
                  _difference == 0 ? "Khớp hoàn toàn, tuyệt vời!" : (_difference > 0 ? "Tiền đếm được dư so với hệ thống" : "Đang bị thiếu tiền, cần kiểm tra lại"),
                  style: TextStyle(color: _difference == 0 ? Colors.green : (_difference > 0 ? Colors.blue : Colors.red)),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BAC), foregroundColor: Colors.white),
              onPressed: () async {
                // TÍCH HỢP IN BÁO CÁO KẾT CA
                try {
                  await PrintService.printShiftReport(
                    _invoiceCount,
                    _totalRevenue,
                    _startingCash,
                    _actualCash,
                    _difference,
                  );
                } catch (e) {
                  print("Lỗi in ấn: $e");
                }

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã lưu báo cáo và in kết ca thành công!")));
                
                Future.delayed(const Duration(milliseconds: 1500), () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(), 
                    ),
                    (Route<dynamic> route) => false, 
                  );
                });
              },
              child: const Text("XÁC NHẬN & IN KẾT CA", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRevenueCard(String title, int amount, Color color, bool isHighlight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlight ? color.withOpacity(0.1) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isHighlight ? 0.5 : 0.2)),
        boxShadow: [
          if (isHighlight)
            BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            "${currencyFormat.format(amount)} đ",
            style: TextStyle(color: isHighlight ? color : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // ĐÃ CẬP NHẬT: Thêm tham số labelColor để tùy chỉnh màu cho các nhãn phụ
  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color color = Colors.black87, double size = 15, Color labelColor = Colors.black87}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: size, color: labelColor))),
        Text(value, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    ); 
  }
}