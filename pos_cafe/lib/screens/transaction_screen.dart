import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../utils/responsive.dart'; // Nhúng công cụ responsive vào đây

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
  List<dynamic> _invoices = [];
  bool _isLoading = true;

  // Biến lưu ngày được chọn (mặc định là ngày hôm nay)
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  void _fetchInvoices() async {
    try {
      final data = await ApiService.getInvoices();
      setState(() {
        _invoices = data;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  // Hàm hiển thị popup cuốn lịch để chọn ngày
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF005BAC), // Đồng bộ màu chủ đạo của app
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isMobile = Responsive.isMobile(context);

    // Lọc danh sách hóa đơn dựa trên _selectedDate
    final filteredInvoices = _invoices.where((inv) {
      if (inv['createdAt'] == null) return false;
      DateTime invoiceDate = DateTime.parse(inv['createdAt']).toLocal();
      
      return invoiceDate.year == _selectedDate.year &&
             invoiceDate.month == _selectedDate.month &&
             invoiceDate.day == _selectedDate.day;
    }).toList();

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề & Nút bấm co giãn linh hoạt theo thiết bị
          isMobile 
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Lịch sử giao dịch", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_month),
                          label: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF005BAC),
                            side: const BorderSide(color: Color(0xFF005BAC)),
                          ),
                          onPressed: () => _selectDate(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005BAC), 
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchInvoices();
                        },
                        child: const Icon(Icons.refresh),
                      )
                    ],
                  )
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Giao dịch / Lịch sử hóa đơn", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF005BAC),
                          side: const BorderSide(color: Color(0xFF005BAC)),
                        ),
                        onPressed: () => _selectDate(context),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BAC), foregroundColor: Colors.white),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Làm mới"),
                        onPressed: () {
                          setState(() => _isLoading = true);
                          _fetchInvoices();
                        },
                      )
                    ],
                  ),
                ],
              ),

          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]
                    ),
                    child: filteredInvoices.isEmpty 
                      ? Center(
                          child: Text(
                            "Không có giao dịch nào trong ngày ${DateFormat('dd/MM/yyyy').format(_selectedDate)}",
                            style: const TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          )
                        )
                      // SỬ DỤNG LAYOUTBUILDER ĐỂ ĐO KÍCH THƯỚC KHUNG BÊN NGOÀI
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal, 
                                // ÉP BẢNG PHẢI RỘNG ÍT NHẤT BẰNG 100% CHIỀU RỘNG MÀN HÌNH
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                                    // Tăng khoảng cách giữa các cột ra một chút cho thoáng
                                    columnSpacing: 32.0, 
                                    columns: const [
                                      DataColumn(label: Text("Mã hóa đơn", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Vị trí bàn", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Thời gian", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Tổng tiền thu", style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text("Trạng thái", style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: filteredInvoices.map((inv) {
                                      DateTime parsedDate = DateTime.parse(inv["createdAt"]).toLocal();
                                      String formattedTime = DateFormat('HH:mm:ss').format(parsedDate);
                                      
                                      return DataRow(cells: [
                                        DataCell(Text("#${inv["id"].toString().substring(0, 8)}...", style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blueGrey))),
                                        DataCell(Text("Bàn ${inv["tableId"]}", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005BAC)))),
                                        DataCell(Text(formattedTime)),
                                        DataCell(Text("${currencyFormat.format(inv["totalAmount"])} đ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                                        const DataCell(
                                          Chip(
                                            label: Text("Hoàn thành", style: TextStyle(color: Colors.white, fontSize: 12)), 
                                            backgroundColor: Colors.green,
                                            padding: EdgeInsets.zero,
                                          )
                                        ),
                                      ]);
                                    }).toList(),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                  ),
          )
        ],
      ),
    );
  }
}