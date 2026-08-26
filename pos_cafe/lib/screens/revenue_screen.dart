import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import '../api_service.dart'; // Đảm bảo đường dẫn này trỏ đúng tới file api_service.dart của bạn

// Sử dụng các thư viện đa nền tảng (Loại bỏ hoàn toàn dart:html)
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:file_saver/file_saver.dart'; 

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
  final DateFormat dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  
  String _selectedFilter = 'day'; 
  bool _isLoading = true;
  
  int _totalRevenue = 0;
  int _totalCash = 0;
  int _totalTransfer = 0;
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _fetchRevenue();
  }

  void _fetchRevenue() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getRevenueReport(_selectedFilter);
      setState(() {
        _totalRevenue = data['totalRevenue'] ?? 0;
        _totalCash = data['totalCash'] ?? 0;
        _totalTransfer = data['totalTransfer'] ?? 0;
        _invoices = data['invoices'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lỗi tải dữ liệu doanh thu"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (_invoices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Không có dữ liệu để xuất!"))
      );
      return;
    }

    try {
      List<List<dynamic>> csvData = [
        ["Mã Hóa Đơn", "Bàn", "Thời Gian", "Phương Thức", "Tổng Tiền (VNĐ)"]
      ];

      for (var inv in _invoices) {
        // Tránh lỗi null cho thời gian
        String timeStr = "";
        if (inv['createdAt'] != null) {
          DateTime date = DateTime.parse(inv['createdAt']).toLocal();
          timeStr = dateFormat.format(date);
        }

        String method = inv['paymentMethod'] == 'cash' ? 'Tiền mặt' : 'Chuyển khoản';
        csvData.add([inv['id'], inv['tableId'], timeStr, method, inv['totalAmount']]);
      }

      // 1. Chuyển mảng thành chuỗi CSV 
      String csv = const ListToCsvConverter().convert(csvData);

      // 2. Chèn thẳng BOM (\uFEFF) vào đầu chuỗi văn bản để chống lỗi font tiếng Việt
      final bomCsv = '\uFEFF$csv';

      // 3. Chuyển đổi dữ liệu String thành Byte Array (Uint8List)
      Uint8List bytes = Uint8List.fromList(utf8.encode(bomCsv));
      
      // 4. Đặt tên file (Không cần ghi đuôi .csv ở đây vì FileSaver sẽ tự thêm)
      final fileName = "DoanhThu_${_selectedFilter}_${DateTime.now().millisecondsSinceEpoch}";

      // 5. Gọi API của file_saver để lưu file đa nền tảng
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        fileExtension: 'csv', // <-- Đổi 'ext' thành 'fileExtension'
        mimeType: MimeType.csv,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Đã xuất và lưu file CSV thành công!"), 
            backgroundColor: Colors.green
          ),
        );
      }
    } catch (e) {
      print("Chi tiết lỗi xuất file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lỗi xuất file CSV!"), backgroundColor: Colors.red)
      );
    }
  }

  Widget _buildSummaryCard(String title, int amount, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text("${currencyFormat.format(amount)} đ", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Báo Cáo Doanh Thu", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: _isLoading ? null : _exportToCSV,
            icon: const Icon(Icons.download),
            label: const Text("Xuất CSV"),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  isExpanded: true,
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.bold),
                  items: const [
                    DropdownMenuItem(value: 'day', child: Text("📅 Hôm nay")),
                    DropdownMenuItem(value: 'week', child: Text("📅 Tuần này")),
                    DropdownMenuItem(value: 'month', child: Text("📅 Tháng này")),
                    DropdownMenuItem(value: 'lastMonth', child: Text("📅 Tháng trước")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedFilter = value);
                      _fetchRevenue();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _isLoading 
              ? const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
              : Row(
                  children: [
                    _buildSummaryCard("TỔNG DOANH THU", _totalRevenue, Colors.blue.shade700, Icons.account_balance_wallet),
                    const SizedBox(width: 12),
                    _buildSummaryCard("TIỀN MẶT", _totalCash, Colors.green, Icons.money),
                    const SizedBox(width: 12),
                    _buildSummaryCard("CHUYỂN KHOẢN", _totalTransfer, Colors.purple, Icons.qr_code_2),
                  ],
                ),
            const SizedBox(height: 20),
            const Text("Chi tiết hóa đơn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const SizedBox()
                  : _invoices.isEmpty
                      ? const Center(child: Text("Không có giao dịch nào trong thời gian này."))
                      : Container(
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: ListView.separated(
                            itemCount: _invoices.length,
                            separatorBuilder: (ctx, index) => Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (ctx, index) {
                              final inv = _invoices[index];
                              
                              // Tránh lỗi null khi hiển thị
                              DateTime? date;
                              if (inv['createdAt'] != null) {
                                date = DateTime.parse(inv['createdAt']).toLocal();
                              }
                              
                              bool isCash = inv['paymentMethod'] == 'cash';

                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isCash ? Colors.green.shade100 : Colors.purple.shade100,
                                  child: Icon(isCash ? Icons.money : Icons.qr_code, color: isCash ? Colors.green : Colors.purple),
                                ),
                                title: Text("Hóa đơn: ${inv['id']} - Bàn ${inv['tableId']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(date != null ? dateFormat.format(date) : "Không rõ thời gian"),
                                trailing: Text(
                                  "+ ${currencyFormat.format(inv['totalAmount'])} đ",
                                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              );
                            },
                          ),
                        ),
            )
          ],
        ),
      ),
    );
  }
}