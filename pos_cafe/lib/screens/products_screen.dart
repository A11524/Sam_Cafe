import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_service.dart';
import '../utils/responsive.dart'; // Nhúng công cụ responsive vào đây

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
  List<dynamic> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  void _fetchProducts() async {
    try {
      final data = await ApiService.getProducts();
      setState(() {
        _products = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showProductDialog({Map<String, dynamic>? product}) {
    final isEdit = product != null;
    final idController = TextEditingController(text: isEdit ? product['id'] : '');
    final nameController = TextEditingController(text: isEdit ? product['name'] : '');
    final priceController = TextEditingController(text: isEdit ? product['price'].toString() : '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? "Sửa thông tin món" : "Thêm hàng hóa mới", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              enabled: !isEdit,
              decoration: const InputDecoration(labelText: "Mã món (VD: CF009)"),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Tên món thức uống"),
            ),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Giá bán (VNĐ)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BAC), foregroundColor: Colors.white),
            onPressed: () async {
              try {
                if (isEdit) {
                  await ApiService.editProduct(product['id'], nameController.text, int.parse(priceController.text));
                } else {
                  await ApiService.createProduct(idController.text, nameController.text, int.parse(priceController.text), 1);
                }
                Navigator.pop(ctx);
                setState(() => _isLoading = true);
                _fetchProducts(); 
              } catch (e) {
                print(e);
              }
            },
            child: const Text("Lưu lại"),
          )
        ],
      ),
    );
  }

  // --- BỔ SUNG: HÀM HIỂN THỊ HỘP THOẠI XÁC NHẬN XÓA MÓN ---
  void _confirmDeleteProduct(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa món "$name" không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // Đóng hộp thoại
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx); // Đóng hộp thoại trước khi xử lý
              try {
                setState(() => _isLoading = true);
                // Gọi API xóa từ ApiService
                await ApiService.deleteProduct(id); 
                
                // Cập nhật lại danh sách sau khi xóa thành công
                _fetchProducts(); 
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Đã xóa món thành công!"), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                print(e);
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lỗi khi xóa món!"), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nhận diện thiết bị
    bool isMobile = Responsive.isMobile(context);

    return Padding(
      // Chỉnh lại lề: Điện thoại lề nhỏ hơn để tiết kiệm không gian
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tiêu đề và nút thêm mới
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Hàng hóa / Thực đơn", style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50), 
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: 12) // Thu nhỏ padding nút trên mobile
                ),
                icon: const Icon(Icons.add, size: 20),
                label: isMobile ? const Text("Thêm") : const Text("Thêm món mới"), // Điện thoại chữ ngắn gọn lại
                onPressed: () => _showProductDialog(),
              )
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
                    // SỬ DỤNG LAYOUTBUILDER ĐỂ BẢNG TỰ CO GIÃN ĐÚNG CHUẨN
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.vertical, // Cho phép cuộn dọc
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal, // TẠO THANH CUỘN NGANG KHI DÙNG TRÊN ĐIỆN THOẠI
                            child: ConstrainedBox(
                              // Ép bảng phải trải dài tối thiểu bằng 100% màn hình
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: DataTable(
                                headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
                                columnSpacing: isMobile ? 24.0 : 48.0, // Tự động dãn cột cho đẹp
                                columns: const [
                                  DataColumn(label: Text("Mã món", style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text("Tên thức uống", style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text("Giá bán", style: TextStyle(fontWeight: FontWeight.bold))),
                                  DataColumn(label: Text("Thao tác", style: TextStyle(fontWeight: FontWeight.bold))),
                                ],
                                rows: _products.map((p) => DataRow(cells: [
                                      DataCell(Text(p["id"])),
                                      DataCell(Text(p["name"], style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF005BAC)))),
                                      DataCell(Text("${currencyFormat.format(p["price"])} đ")),
                                      DataCell(
                                        // --- BỔ SUNG: Gom 2 nút Sửa và Xóa vào một Row ---
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Colors.blue),
                                              tooltip: 'Sửa',
                                              onPressed: () => _showProductDialog(product: p),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              tooltip: 'Xóa',
                                              onPressed: () => _confirmDeleteProduct(p["id"], p["name"]),
                                            ),
                                          ],
                                        )
                                      ),
                                    ])).toList(),
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