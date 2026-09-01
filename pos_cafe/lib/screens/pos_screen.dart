import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../api_service.dart';
import '../utils/responsive.dart'; 
import '../utils/print_service.dart'; 
import 'package:flutter/foundation.dart'; // Thêm dòng này để dùng kIsWeb và TargetPlatform
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class POSScreen extends StatefulWidget {
  
  // Cập nhật lại constructor
  const POSScreen({super.key}); // Trả lại như cũ

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> with AutomaticKeepAliveClientMixin<POSScreen> {
  @override
  bool get wantKeepAlive => true; // <--- Yêu cầu Flutter giữ lại dữ liệu khi chuyển tab

  final NumberFormat currencyFormat = NumberFormat('#,##0', 'en_US');
  
  List<Product> _products = [];
  bool _isLoadingProducts = true;

  List<dynamic> _tables = [];
  bool _isLoadingTables = true;
  String _selectedTable = '';
  final Map<String, List<CartItem>> _tableOrders = {};
  
  String _searchQuery = '';
  int _selectedCategory = 0; 

  final List<Map<String, dynamic>> _categories = [
    {"id": 0, "name": "Tất cả", "icon": Icons.menu_book},
    {"id": 1, "name": "Cà Phê & Đá Xay", "icon": Icons.coffee},
    {"id": 2, "name": "Trà & Lipton", "icon": Icons.emoji_food_beverage},
    {"id": 3, "name": "Sinh Tố & Sữa Chua", "icon": Icons.blender},
    {"id": 4, "name": "Soda & Giải Khát", "icon": Icons.local_drink},
    {"id": 5, "name": "Điểm Tâm", "icon": Icons.fastfood},
  ];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeApp(); // Gọi hàm gộp để đảm bảo thứ tự tải dữ liệu (Trị lỗi trắng bàn)

    // 🔥 CHÈN THÊM: ĐỒNG HỒ 5 GIÂY DỌN RÁC (Trị lỗi máy tính không mất Bill)
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) _syncActiveInvoices();
    });
    
    // GIỮ NGUYÊN 100% CODE SOCKET & MÁY IN CỦA BẠN
    try {
      ApiService.initSocket();
      
      // Đã đổi thành chữ thường để khớp với Backend
      ApiService.socket.on('table_updated', (data) {
        if (mounted) {
          setState(() {
            if (data != null) {
              // 1. CÔNG NGHỆ DÒ TÌM ID (Hỗ trợ cả Bàn vật lý lẫn Đơn tạm)
              String tId = data['tableId']?.toString() ?? '';
              var invoice = data['invoice'];
              
              if (invoice != null) {
                if (tId.isEmpty && invoice['tableId'] != null) {
                  tId = invoice['tableId'].toString();
                }
                if (tId.isEmpty && invoice['table'] != null) {
                  tId = invoice['table']['name']?.toString() ?? invoice['table']['id']?.toString() ?? '';
                }
              }

              // 2. NHẬN LỆNH VÀ ÉP CẬP NHẬT
              if (tId.isNotEmpty) {
                if (invoice != null && invoice['details'] != null) {
                  List<dynamic> details = invoice['details'];
                  List<CartItem> updatedCart = [];
                  
                  for (var d in details) {
                    String pId = d['productId'].toString();
                    Product product = _products.firstWhere(
                      (p) => p.id == pId, 
                      orElse: () => Product(id: pId, name: 'Món $pId', price: d['price'] ?? 0, categoryId: 1, icon: Icons.local_cafe, color: Colors.grey)
                    );
                    
                    updatedCart.add(CartItem(
                      product: product,
                      quantity: d['quantity'] ?? 1,
                      note: d['note'] ?? ''
                    ));
                  }
                  
                  // Xuyên thủng mọi lá chắn: Socket là lệnh tức thời -> Ép cập nhật ngay!
                  _tableOrders[tId] = updatedCart; 
                } 
                else if (data['status'] == 'PAID' || (invoice != null && invoice['status'] == 'PAID')) {
                  // Xóa sạch giỏ khi thanh toán toàn bộ
                  _tableOrders[tId] = []; 
                }
              }
            }
          });
        }
      });

      // ======================================================
      // LẮNG NGHE LỆNH IN TỪ SERVER (CHỈ DÀNH CHO WINDOWS)
      // ======================================================
      ApiService.socket.on('print_kitchen_command', (data) async {
        // Rất quan trọng: Chỉ cho phép PC Windows nhận lệnh in, chặn điện thoại (Web)
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
          if (data != null && data['items'] != null) {
            String tId = data['tableId'].toString();
            List<dynamic> itemsToPrint = data['items'];

            List<Map<String, dynamic>> printItems = [];
            for (var d in itemsToPrint) {
              String pId = d['productId'].toString();
              
              Product product = _products.firstWhere(
                (p) => p.id == pId,
                orElse: () => Product(id: pId, name: 'Món $pId', price: 0, categoryId: 1, icon: Icons.local_cafe, color: Colors.grey)
              );

              printItems.add({
                "name": product.name,
                "quantity": d['quantity'],
                "note": d['note'] ?? ""
              });
            }

            // Kích hoạt máy in thực tế trên Windows
            await PrintService.printKitchenTicket(tId, printItems);
          }
        }
      });
      // ======================================================

      ApiService.socket.on('new_table_added', (data) {
        if (mounted) _loadTablesFromAPI();
      });
      ApiService.socket.on('table_renamed', (data) {
        if (mounted) _loadTablesFromAPI();
      });
      ApiService.socket.on('table_deleted', (data) {
        if (mounted) _loadTablesFromAPI();
      });
      // Nếu Backend dùng chữ thường cho transfer thì bạn cũng đổi lại ở đây luôn nhé
      ApiService.socket.on('table_transferred', (data) {
        if (mounted) _loadTablesFromAPI();
      });
    } catch (e) {}
  }

  // 🔥 CHÈN THÊM: HỦY ĐỒNG HỒ KHI THOÁT
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // 🔥 ĐÃ SỬA LẠI THỨ TỰ TẢI CHUẨN XÁC
  void _initializeApp() async {
    await _loadProductsFromAPI(); // Bắt buộc tải Menu xong trước
    await _loadTablesFromAPI();   // Tải danh sách các ô vuông (Bàn)
    await _syncActiveInvoices();  // Bắt đầu đắp món ăn vào các bàn
  }

  // Sửa lại: Thêm Future<void> để có thể dùng lệnh await
  Future<void> _loadProductsFromAPI() async {
    try {
      final response = await ApiService.getProducts();
      final List<dynamic> data = response is List ? response : [];

      setState(() {
        _products = data.map((item) {
          final mapItem = item as Map<String, dynamic>;
          return Product(
            id: mapItem['id']?.toString() ?? '',
            name: mapItem['name']?.toString() ?? '',
            price: mapItem['price'] is int ? mapItem['price'] : int.tryParse(mapItem['price'].toString()) ?? 0,
            categoryId: mapItem['categoryId'] is int ? mapItem['categoryId'] : int.tryParse(mapItem['categoryId'].toString()) ?? 1,
            icon: Icons.local_cafe,
            color: Colors.brown,
          );
        }).toList();
        _isLoadingProducts = false;
      });
    } catch (e) {
      setState(() => _isLoadingProducts = false);
    }
  }

  // Sửa lại: Lấy danh sách bàn VÀ lấy món đắp vào
  Future<void> _loadTablesFromAPI() async {
    try {
      final tablesData = await ApiService.getTables();
      setState(() {
        _tables = tablesData;
        for (var table in _tables) {
          final tableName = table['name'].toString();
          // CHỈ TẠO giỏ hàng rỗng nếu bàn này chưa từng xuất hiện.
          // TUYỆT ĐỐI KHÔNG dùng lệnh clear() ở đây để tránh quét nhầm món ăn Socket vừa gửi.
          if (!_tableOrders.containsKey(tableName)) {
            _tableOrders[tableName] = [];
          }
        }
        if (_selectedTable.isEmpty && _tables.isNotEmpty) {
          _selectedTable = _tables.first['name'].toString();
        }
        _isLoadingTables = false;
      });
    } catch (e) {
      setState(() => _isLoadingTables = false);
    }
  }

  Future<void> _syncActiveInvoices() async {
    try {
      final activeInvoices = await ApiService.getActiveInvoices();
      if (!mounted) return;

      setState(() {
        List<String> serverActiveKeys = [];
        
        // 1. DỊCH NGÔN NGỮ CHÌA KHÓA BÀN ĐANG XEM (Chống lỗi Map vs String)
        String currentKey = '';
        if (_selectedTable != null) {
          if (_selectedTable is Map) {
            // Ép kiểu dứt khoát sang Map để trình biên dịch Dart hết "la làng"
            final tableMap = _selectedTable as Map;
            currentKey = tableMap['name']?.toString() ?? tableMap['id']?.toString() ?? '';
          } else {
            // Nếu là Đơn tạm (ảo), lấy trực tiếp tên chuỗi
            currentKey = _selectedTable.toString();
          }
        }

        // 2. NHẬN MỌI ĐƠN TỪ SERVER (Bao trọn gói Bàn vật lý & Đơn tạm)
        for (var invoice in activeInvoices) {
          String tId = '';
          String tName = '';
          
          if (invoice['table'] != null) {
            tId = invoice['table']['id']?.toString() ?? '';
            tName = invoice['table']['name']?.toString() ?? '';
          } else if (invoice['tableId'] != null) {
            tId = invoice['tableId'].toString();
          }
          
          // Bỏ qua rào cản, cứ có ID hoặc Tên là duyệt tất!
          if (tId.isEmpty && tName.isEmpty) continue;

          // Tạo chìa khóa: Ưu tiên dùng Tên bàn, nếu không có Tên thì dùng ID (cho Đơn tạm)
          String invoiceKey = tName.isNotEmpty ? tName : tId;
          
          // Đánh dấu bàn này đang có khách trên Server
          serverActiveKeys.add(invoiceKey);
          if (tId.isNotEmpty) serverActiveKeys.add(tId); // Dự phòng thêm ID

          List<dynamic> details = invoice['details'] ?? [];
          List<CartItem> cartItems = [];
          for (var d in details) {
            String pId = d['productId']?.toString() ?? '';
            int safePrice = d['price'] != null ? (int.tryParse(d['price'].toString()) ?? 0) : 0;
            int safeQty = d['quantity'] != null ? (int.tryParse(d['quantity'].toString()) ?? 1) : 1;

            Product product = _products.firstWhere(
              (p) => p.id == pId, 
              orElse: () => Product(id: pId.isEmpty ? 'UNKNOWN' : pId, name: 'Món $pId', price: safePrice, categoryId: 1, icon: Icons.local_cafe, color: Colors.grey)
            );
            cartItems.add(CartItem(product: product, quantity: safeQty, note: d['note']?.toString() ?? ''));
          }
          
          // 3. ĐẮP DỮ LIỆU VÀO GIỎ HÀNG ĐỒNG BỘ 2 MÁY
          if (currentKey != invoiceKey && currentKey != tId) {
            // Nếu máy ĐANG KHÔNG thao tác ở bàn này -> Tự động cập nhật số liệu mới nhất
            _tableOrders[invoiceKey] = List.from(cartItems);
          } else {
            // LÁ CHẮN: Nếu máy ĐANG XEM bàn này -> Chỉ đắp dữ liệu nếu giỏ đang trống 
            // (Chống làm mất món mà thu ngân vừa chọn chưa kịp gửi bếp)
            if (_tableOrders[invoiceKey] == null || _tableOrders[invoiceKey]!.isEmpty) {
              _tableOrders[invoiceKey] = List.from(cartItems);
            }
          }
        }

        // 4. DỌN DẸP RÁC
        _tableOrders.removeWhere((key, items) {
           // Xóa sạch giỏ hàng nếu Server báo đã thanh toán VÀ thu ngân không đứng ở bàn đó
           return !serverActiveKeys.contains(key.toString()) && key.toString() != currentKey;
        });

        // 5. CHỐNG VĂNG APP
        if (currentKey.isNotEmpty) {
          _tableOrders[currentKey] ??= [];
        }
      });
    } catch (e) {
      print("Lỗi tải món: $e");
    }
  }

  List<CartItem> get currentCart => _tableOrders[_selectedTable] ?? [];

  void _addToCart(Product product) {
    setState(() {
      int index = currentCart.indexWhere((item) => item.product.id == product.id && item.note.isEmpty);
      if (index != -1) {
        currentCart[index].quantity++;
      } else {
        currentCart.add(CartItem(product: product));
      }
    });
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      currentCart[index].quantity += delta;
      if (currentCart[index].quantity <= 0) currentCart.removeAt(index);
    });
  }

  void _removeItem(int index) => setState(() => currentCart.removeAt(index));
  void _clearCart() => setState(() => currentCart.clear());

  int get _subtotal => currentCart.fold(0, (sum, item) => sum + item.totalPrice);

  void _showNoteDialog(int cartIndex) {
    final noteController = TextEditingController(text: currentCart[cartIndex].note);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Ghi chú cho món ${currentCart[cartIndex].product.name}", style: const TextStyle(fontSize: 16)),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(hintText: "VD: Ít đá, nhiều sữa...", border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () {
              setState(() => currentCart[cartIndex].note = noteController.text);
              Navigator.pop(ctx);
            },
            child: const Text("Lưu ghi chú"),
          )
        ],
      )
    );
  }

  // ==========================================
  // HỘP THOẠI ĐỔI MẬT KHẨU NHÂN VIÊN (QUẢN LÝ)
  // ==========================================
  void _showResetStaffPasswordDialog(BuildContext context) {
    final usernameController = TextEditingController(text: 'nhanvien');
    final newPasswordController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Cấp lại mật khẩu nhân viên", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Tính năng này giúp quản lý đổi mật khẩu của nhân viên sau khi họ nghỉ việc để bảo mật hệ thống.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 16),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: "Tên đăng nhập nhân viên",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Mật khẩu mới",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
              ],
            ),
            actions: [
              if (!isUpdating)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                onPressed: isUpdating
                    ? null
                    : () async {
                        final staffUser = usernameController.text.trim();
                        final newPass = newPasswordController.text.trim();

                        if (staffUser.isEmpty || newPass.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin!"), backgroundColor: Colors.orange));
                          return;
                        }

                        setStateDialog(() => isUpdating = true);

                        try {
                          await ApiService.resetStaffPassword(staffUser, newPass);
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✅ Đã đổi mật khẩu nhân viên thành công!"), backgroundColor: Colors.green),
                          );
                        } catch (e) {
                          setStateDialog(() => isUpdating = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString().replaceAll("Exception: ", "")), backgroundColor: Colors.red),
                          );
                        }
                      },
                child: isUpdating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Đổi mật khẩu"),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // HỘP THOẠI CHUYỂN BÀN MỚI
  // ==========================================
  // ==========================================
  // HỘP THOẠI CHUYỂN BÀN MỚI (Đã Fix lỗi mất món)
  // ==========================================
  void _showTransferTableDialog(String currentTableId) {
    List<dynamic> emptyTables = _tables.where((table) {
      final tName = table['name'].toString();
      final hasOrder = (_tableOrders[tName] ?? []).isNotEmpty;
      return !hasOrder && tName != currentTableId; 
    }).toList();
    
    String? selectedNewTableId;
    bool isTransferring = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text("Chuyển từ bàn '$currentTableId' đến:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: emptyTables.isEmpty
                ? const Text("Hiện tại không có bàn trống nào!")
                : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Chọn bàn trống"),
                    value: selectedNewTableId,
                    items: emptyTables.map((table) {
                      return DropdownMenuItem<String>(
                        value: table['name'].toString(),
                        child: Text("Chuyển đến: ${table['name']}"),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() => selectedNewTableId = value);
                    },
                  ),
            actions: [
              if (!isTransferring)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
              if (emptyTables.isNotEmpty)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BAC), foregroundColor: Colors.white),
                  onPressed: (selectedNewTableId == null || isTransferring)
                      ? null
                      : () async {
                          setStateDialog(() => isTransferring = true);
                          try {
                            // BÍ KÍP Ở ĐÂY: Lưu lại giỏ hàng TRƯỚC KHI chuyển bàn
                            List<CartItem> savedCart = List.from(currentCart);

                            List<Map<String, dynamic>> apiItems = savedCart.map((item) => {
                              "productId": item.product.id, 
                              "quantity": item.quantity, 
                              "price": item.product.price,
                              "note": item.note
                            }).toList();
                            
                            if (apiItems.isNotEmpty) {
                              await ApiService.updateInvoice(currentTableId, apiItems);
                            }

                            bool success = await ApiService.transferTable(currentTableId, selectedNewTableId!);
                            
                            if (success) {
                              if (!context.mounted) return;
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Chuyển bàn thành công!"), backgroundColor: Colors.green));
                              
                              setState(() {
                                // Lấy giỏ hàng đã chụp lại đắp vào bàn mới
                                _tableOrders[selectedNewTableId!] = savedCart;
                                _tableOrders[currentTableId] = [];
                                _selectedTable = selectedNewTableId!; 
                              });
                              _loadTablesFromAPI();
                            } else {
                              setStateDialog(() => isTransferring = false);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi: Không thể chuyển bàn!"), backgroundColor: Colors.red));
                            }
                          } catch (e) {
                            setStateDialog(() => isTransferring = false);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối máy chủ!"), backgroundColor: Colors.red));
                          }
                        },
                  child: isTransferring
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Xác nhận chuyển"),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTableDialog() {
    final nameController = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Thêm bàn mới", style: TextStyle(fontWeight: FontWeight.bold)),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Tên bàn (VD: Bàn VIP 1, S19...)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.table_restaurant),
              ),
              autofocus: true,
            ),
            actions: [
              if (!isAdding)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
                ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BAC), foregroundColor: Colors.white),
                onPressed: isAdding
                    ? null
                    : () async {
                        final tableName = nameController.text.trim();
                        if (tableName.isEmpty) return;

                        setStateDialog(() => isAdding = true);

                        try {
                          await ApiService.createTable(tableName);
                          if (!context.mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("✅ Thêm bàn thành công!"), backgroundColor: Colors.green),
                          );
                          _loadTablesFromAPI();
                        } catch (e) {
                          setStateDialog(() => isAdding = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Lỗi: Không thể thêm bàn!"), backgroundColor: Colors.red),
                          );
                        }
                      },
                child: isAdding
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Thêm bàn"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditTableDialog(Map<String, dynamic> tableItem) {
    final tableId = tableItem['id'].toString();
    final oldName = tableItem['name'].toString();
    final controller = TextEditingController(text: oldName);
    
    final hasOrder = (_tableOrders[oldName] ?? []).isNotEmpty;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tùy chỉnh bàn", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: "Nhập tên bàn mới",
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween, 
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            icon: const Icon(Icons.delete, size: 18),
            label: const Text("Xóa bàn"),
            onPressed: () async {
              if (hasOrder) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Không thể xóa! Bàn này đang có order."), backgroundColor: Colors.red)
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ApiService.deleteTable(tableId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Đã xóa bàn $oldName"), backgroundColor: Colors.green)
                );
                _loadTablesFromAPI(); 
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Lỗi xóa bàn!"), backgroundColor: Colors.red)
                );
              }
            },
          ),
          
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005BAC), foregroundColor: Colors.white),
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) return;

                  try {
                    await ApiService.renameTable(tableId, newName);
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Đã đổi tên thành $newName!"), backgroundColor: Colors.green)
                    );
                    _loadTablesFromAPI();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Lỗi đổi tên bàn!"), backgroundColor: Colors.red)
                    );
                  }
                },
                child: const Text("Lưu"),
              ),
            ],
          )
        ],
      )
    );
  }

  void _saveTemporaryBill() async {
    if (currentCart.isEmpty) return;
    
    String timeStamp = DateFormat('HHmm').format(DateTime.now());
    String tempTableName = "Tam_$_selectedTable\_$timeStamp";
    String oldTable = _selectedTable;

    // BÍ KÍP Ở ĐÂY: Lưu lại giỏ hàng TRƯỚC KHI gọi API chuyển bàn
    List<CartItem> savedCart = List.from(currentCart);

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      List<Map<String, dynamic>> apiItems = savedCart.map((item) => {
        "productId": item.product.id, 
        "quantity": item.quantity, 
        "price": item.product.price,
        "note": item.note 
      }).toList();
      
      await ApiService.updateInvoice(oldTable, apiItems);
      await ApiService.createTable(tempTableName); 
      
      bool success = await ApiService.transferTable(oldTable, tempTableName);
      
      if (!mounted) return;
      Navigator.pop(context); 

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Đã lưu đơn vào bàn: $tempTableName"), backgroundColor: Colors.green)
        );
        setState(() {
          // Lấy giỏ hàng đã chụp lại ở trên đắp vào bàn tạm
          _tableOrders[tempTableName] = savedCart;
          _tableOrders[oldTable] = []; 
          _selectedTable = tempTableName; 
        });
        _loadTablesFromAPI(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi lưu đơn tạm!"), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi kết nối hoặc đồng bộ máy chủ!"), backgroundColor: Colors.red));
    }
  }

  void _processOrder() async {
    if (currentCart.isEmpty) return;
    
    // HIỆN VÒNG XOAY LOADING
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator())
    );

    List<Map<String, dynamic>> apiItems = currentCart.map((item) => {
      "productId": item.product.id, 
      "quantity": item.quantity, 
      "price": item.product.price,
      "note": item.note 
    }).toList();

    try {
      await ApiService.updateInvoice(_selectedTable, apiItems);
      
      // Tắt vòng xoay
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Đã gửi order và lệnh in bếp cho bàn $_selectedTable!"), 
        backgroundColor: Colors.orange.shade800,
      ));
      if (Responsive.isMobile(context)) Navigator.pop(context);
    } catch (e) {
      // Tắt vòng xoay nếu lỗi
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi đồng bộ Server!"), backgroundColor: Colors.red));
    }
  }

  void _processCheckout() {
    if (currentCart.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Thanh toán - Bàn $_selectedTable", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Tổng tiền: ${currencyFormat.format(_subtotal)} đ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  List<Map<String, dynamic>> printItems = currentCart.map((item) => {
                    "name": item.product.name, "quantity": item.quantity, "price": item.product.price,
                  }).toList();
                  
                  // KIỂM TRA MÁY TÍNH MỚI CHO IN
                  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
                    await PrintService.printCustomerReceipt(_selectedTable, _subtotal, printItems);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã in phiếu tạm tính!"), backgroundColor: Colors.blue));
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tính năng in chỉ hỗ trợ trên máy tính thu ngân!"), backgroundColor: Colors.orange));
                    }
                  }
                },
                icon: const Icon(Icons.print),
                label: const Text("IN TẠM TÍNH (Cho khách xem)"),
              ),
            ),
            const Divider(height: 30),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () { Navigator.pop(ctx); _executePayment('cash'); },
                    icon: const Icon(Icons.money),
                    label: const Text("Tiền mặt"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () { Navigator.pop(ctx); _executePayment('transfer'); },
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text("Chuyển khoản"),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showSplitPaymentDialog() {
    if (currentCart.isEmpty) return;
    
    List<int> payQuantities = List.filled(currentCart.length, 0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          int splitTotal = 0;
          for (int i = 0; i < currentCart.length; i++) {
            splitTotal += payQuantities[i] * currentCart[i].product.price;
          }

          return AlertDialog(
            title: const Text("Tách món thanh toán"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currentCart.length,
                      itemBuilder: (context, index) {
                        final item = currentCart[index];
                        return ListTile(
                          title: Text(item.product.name),
                          subtitle: Text("${currencyFormat.format(item.product.price)} đ / món"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () {
                                  if (payQuantities[index] > 0) setStateDialog(() => payQuantities[index]--);
                                },
                              ),
                              Text("${payQuantities[index]} / ${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () {
                                  if (payQuantities[index] < item.quantity) setStateDialog(() => payQuantities[index]++);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Text("Tổng tiền tách: ${currencyFormat.format(splitTotal)} đ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: splitTotal == 0 ? null : () async {
                  Navigator.pop(ctx);
                  
                  List<Map<String, dynamic>> itemsToPay = [];
                  for (int i = 0; i < currentCart.length; i++) {
                    if (payQuantities[i] > 0) {
                      itemsToPay.add({
                        "productId": currentCart[i].product.id,
                        "name": currentCart[i].product.name, 
                        "quantity": payQuantities[i],
                        "price": currentCart[i].product.price,
                      });
                    }
                  }
                  _executeSplitPayment(itemsToPay, splitTotal);
                },
                child: const Text("Thanh toán phần này"),
              )
            ],
          );
        },
      ),
    );
  }

  void _executeSplitPayment(List<Map<String, dynamic>> itemsToPay, int splitTotal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Phương thức thanh toán"),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              await _finishSplitPay(itemsToPay, splitTotal, 'cash');
            },
            child: const Text("Tiền mặt", style: TextStyle(color: Colors.white)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () async {
              Navigator.pop(ctx);
              await _finishSplitPay(itemsToPay, splitTotal, 'transfer');
            },
            child: const Text("Chuyển khoản", style: TextStyle(color: Colors.white)),
          ),
        ]
      )
    );
  }

  Future<void> _finishSplitPay(List<Map<String, dynamic>> itemsToPay, int splitTotal, String method) async {
    // 1. Khóa màn hình chống bấm đúp
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator())
    );

    try {
      // 2. CHỈ GỌI LỆNH TÁCH MÓN 1 LẦN DUY NHẤT 
      // (Đã xóa các dòng bị copy trùng lặp và dòng updateInvoice sai logic)
      await ApiService.splitAndPay(_selectedTable, method, itemsToPay);
      
      // Tắt vòng xoay Loading
      if (!mounted) return;
      Navigator.pop(context); 

      // 3. IN HÓA ĐƠN TÁCH TRÊN MÁY TÍNH WINDOWS
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        try {
          await PrintService.printCustomerReceipt(_selectedTable, splitTotal, itemsToPay);
        } catch (e) {
          print("Lỗi máy in: $e");
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thanh toán tách món thành công!"), backgroundColor: Colors.green));
      
      // Đóng bảng chọn tách món
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      // 4. Trừ trực tiếp món trên giao diện để hiển thị lại phần dư
      setState(() {
        for (var paidItem in itemsToPay) {
          int index = currentCart.indexWhere((c) => c.product.id == paidItem['productId']);
          if (index != -1) {
             currentCart[index].quantity -= paidItem['quantity'] as int;
             if (currentCart[index].quantity <= 0) {
               currentCart.removeAt(index); 
             }
          }
        }
      });
      
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tắt loading nếu có lỗi
      print("===== CHI TIẾT LỖI TÁCH MÓN =====");
      print(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: ${e.toString()}"), backgroundColor: Colors.red)
      );
    }
  }

  void _executePayment(String paymentMethod) async {
    // 1. HIỆN VÒNG XOAY LOADING KHÓA MÀN HÌNH NGAY LẬP TỨC
    showDialog(
      context: context,
      barrierDismissible: false, // Cấm bấm ra ngoài
      builder: (ctx) => const Center(child: CircularProgressIndicator())
    );

    List<Map<String, dynamic>> apiItems = currentCart.map((item) => {
      "productId": item.product.id, "quantity": item.quantity, "price": item.product.price,
    }).toList();

    List<Map<String, dynamic>> printItems = currentCart.map((item) => {
      "name": item.product.name, "quantity": item.quantity, "price": item.product.price,
    }).toList();

    try {
      await ApiService.updateInvoice(_selectedTable, apiItems);
      await ApiService.payInvoice(_selectedTable, paymentMethod); 
      
      // 2. Tắt vòng xoay Loading khi Server đã chốt xong
      if (mounted) Navigator.pop(context);

      // In hóa đơn trên Windows
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        try {
          await PrintService.printCustomerReceipt(_selectedTable, _subtotal, printItems);
        } catch (e) {
          print("Lỗi máy in: $e");
        }
      }
      
      if (!mounted) return;
      String methodName = (paymentMethod == 'cash') ? 'Tiền mặt' : 'Chuyển khoản';

      // 3. DỌN SẠCH GIỎ HÀNG TRÊN MÀN HÌNH NGAY LẬP TỨC
      _clearCart(); 

      showDialog(
        context: context,
        barrierDismissible: false, // Bắt buộc phải ấn Hoàn tất
        builder: (ctx) => AlertDialog(
          title: Text("Thanh toán thành công - $_selectedTable", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          content: Text("Hình thức: $methodName\nTổng số tiền thu: ${currencyFormat.format(_subtotal)} đ\n\n(✅ Đã in Bill và chốt doanh thu)"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); 
                if (Responsive.isMobile(context)) Navigator.pop(context); 
              },
              child: const Text("Hoàn tất"),
            )
          ],
        )
      );
    } catch (e) {
      // Tắt vòng xoay Loading nếu có lỗi
      if (mounted) Navigator.pop(context);
      
      print("===== CHI TIẾT LỖI THANH TOÁN =====");
      print(e.toString());
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi: ${e.toString()}"), backgroundColor: Colors.red)
      );
    } 
  }

  Widget _buildTableSection(bool isMobile) {
    if (_isLoadingTables) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isMobile) {
      return Container(
        height: 70,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
        child: Row(
          children: [
            IconButton(
              onPressed: _showAddTableDialog,
              icon: const Icon(Icons.add_circle, color: Color(0xFF005BAC), size: 30),
              tooltip: "Thêm bàn",
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                itemCount: _tables.length,
                itemBuilder: (context, index) {
                  final tableItem = _tables[index];
                  final tableName = tableItem['name'].toString();
                  final hasOrder = (_tableOrders[tableName] ?? []).isNotEmpty;
                  final isSelected = _selectedTable == tableName;
                  
                  Color bgColor = isSelected ? const Color(0xFF005BAC) : (hasOrder ? Colors.orange.shade100 : Colors.white);
                  Color borderColor = isSelected ? const Color(0xFF005BAC) : (hasOrder ? Colors.orange.shade400 : Colors.grey.shade300);
                  Color textColor = isSelected ? Colors.white : (hasOrder ? Colors.orange.shade900 : Colors.black87);

                  return InkWell(
                    onTap: () => setState(() => _selectedTable = tableName),
                    onLongPress: () => _showEditTableDialog(tableItem),
                    child: Container(
                      width: 80,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor, width: 1.5)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(hasOrder ? Icons.coffee : Icons.table_restaurant, color: textColor.withOpacity(0.7), size: 20),
                          const SizedBox(height: 2),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0),
                            child: Text(tableName, style: TextStyle(fontWeight: isSelected || hasOrder ? FontWeight.bold : FontWeight.normal, fontSize: 11, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0), 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Sơ đồ bàn", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005BAC),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(0, 32),
                  ),
                  onPressed: _showAddTableDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Thêm bàn", style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 90, childAspectRatio: 1.0, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _tables.length,
              itemBuilder: (context, index) {
                final tableItem = _tables[index];
                final tableName = tableItem['name'].toString();
                final hasOrder = (_tableOrders[tableName] ?? []).isNotEmpty;
                final isSelected = _selectedTable == tableName;
                
                Color bgColor = isSelected ? const Color(0xFF005BAC) : (hasOrder ? Colors.orange.shade100 : Colors.white);
                Color borderColor = isSelected ? const Color(0xFF005BAC) : (hasOrder ? Colors.orange.shade400 : Colors.grey.shade300);
                Color textColor = isSelected ? Colors.white : (hasOrder ? Colors.orange.shade900 : Colors.black87);

                return InkWell(
                  onTap: () => setState(() => _selectedTable = tableName),
                  onLongPress: () => _showEditTableDialog(tableItem), 
                  child: Container(
                    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: borderColor, width: 1.5)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(hasOrder ? Icons.coffee : Icons.table_restaurant, color: textColor.withOpacity(0.7), size: 24),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Text(tableName, style: TextStyle(fontWeight: isSelected || hasOrder ? FontWeight.bold : FontWeight.normal, fontSize: 11, color: textColor), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection(List<Product> filteredProducts) {
    return Column(
      children: [
        SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat["id"];
              return ChoiceChip(
                label: Row(
                  children: [
                    Icon(cat["icon"], size: 16, color: isSelected ? Colors.white : Colors.blueGrey),
                    const SizedBox(width: 6),
                    Text(cat["name"], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  ],
                ),
                selected: isSelected,
                selectedColor: const Color(0xFF005BAC),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? const Color(0xFF005BAC) : Colors.grey.shade300)),
                onSelected: (selected) {
                  if (selected) setState(() => _selectedCategory = cat["id"]);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: _isLoadingProducts 
            ? const Center(child: CircularProgressIndicator()) 
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180, 
                  childAspectRatio: 1.1, 
                  crossAxisSpacing: 12, 
                  mainAxisSpacing: 12
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade200)),
                    color: Colors.white,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _addToCart(product),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(radius: 28, backgroundColor: product.color.withOpacity(0.15), child: Icon(product.icon, size: 28, color: product.color)),
                          const SizedBox(height: 8),
                          Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text("${currencyFormat.format(product.price)} đ", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                },
              ),
        )
      ],
    );
  }

  Widget _buildCartSection() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200)), color: const Color(0xFF005BAC).withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Bàn $_selectedTable", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF005BAC)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text("Đơn hàng: ${currentCart.length} món", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                
                if (currentCart.isNotEmpty) 
                  Row(
                    children: [
                      IconButton(
                        onPressed: _saveTemporaryBill,
                        icon: const Icon(Icons.pause_circle_filled, color: Colors.orange, size: 26),
                        tooltip: "Lưu bill tạm",
                      ),
                      IconButton(
                        onPressed: () => _showTransferTableDialog(_selectedTable),
                        icon: const Icon(Icons.swap_horiz, color: Colors.blue, size: 26),
                        tooltip: "Chuyển bàn",
                      ),
                      IconButton(
                        onPressed: _clearCart, 
                        icon: const Icon(Icons.delete_sweep, color: Colors.red, size: 26),
                        tooltip: "Hủy đơn",
                      )
                    ],
                  )
              ],
            ),
          ),
          
          Expanded(
            child: currentCart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_shopping_cart, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text("Bàn trống", style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: currentCart.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                    itemBuilder: (context, index) {
                      final item = currentCart[index];
                      return Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(onTap: () => _removeItem(index), child: const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.cancel, color: Colors.redAccent, size: 20))),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                  const SizedBox(height: 2),
                                  Text("${currencyFormat.format(item.product.price)} đ", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _showNoteDialog(index),
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_note, size: 14, color: item.note.isEmpty ? Colors.blue : Colors.orange),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            item.note.isEmpty ? "Thêm ghi chú" : item.note,
                                            style: TextStyle(color: item.note.isEmpty ? Colors.blue : Colors.orange.shade800, fontSize: 12, fontStyle: FontStyle.italic),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                _buildQtyButton(Icons.remove, () => _updateQuantity(index, -1)),
                                Container(width: 28, alignment: Alignment.center, child: Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold))),
                                _buildQtyButton(Icons.add, () => _updateQuantity(index, 1)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200)), color: Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Khách cần trả", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text("${currencyFormat.format(_subtotal)} đ", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: currentCart.isEmpty ? null : _processOrder,
                          child: const Text("GỬI BẾP", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: currentCart.isEmpty ? null : _showSplitPaymentDialog,
                          child: const Text("TÁCH MÓN", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3, 
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          onPressed: currentCart.isEmpty ? null : _processCheckout,
                          child: const Text("THANH TOÁN", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }

  void _showMobileCartBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: _buildCartSection(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // <--- BẮT BUỘC PHẢI THÊM DÒNG NÀY

    bool isMobile = Responsive.isMobile(context);

    final filteredProducts = _products.where((p) {
      bool matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      bool matchesCategory = (_selectedCategory == 0) || (p.categoryId == _selectedCategory);
      return matchesSearch && matchesCategory;
    }).toList();
    
    return Scaffold(
      backgroundColor: Colors.transparent, 
      
      floatingActionButton: isMobile
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF4CAF50),
              onPressed: _showMobileCartBottomSheet,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text("Bàn $_selectedTable (${currentCart.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
          
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 60,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)]),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: const InputDecoration(hintText: "Tìm kiếm...", border: InputBorder.none),
                    ),
                  ),
                  // 🔥 BỔ SUNG NÚT ĐỒNG BỘ Ở ĐÂY:
                  IconButton(
                    icon: const Icon(Icons.sync, color: Colors.green, size: 28),
                    tooltip: "Tải lại đơn đang treo",
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Đang đồng bộ dữ liệu từ máy chủ..."), duration: Duration(seconds: 1))
                      );
                      _syncActiveInvoices(); // Gọi lại hàm tải món ăn
                    },
                  ),
                  if (!isMobile) 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(16)),
                      child: Text("Đang chọn: $_selectedTable", style: const TextStyle(color: Color(0xFF005BAC), fontWeight: FontWeight.bold)),
                    ),
                  
                if (ApiService.currentUserRole == 'manager') ...[
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8)
                    ),
                    child: IconButton(
                      icon: Icon(Icons.admin_panel_settings, color: Colors.red.shade700),
                      tooltip: "Quản lý nhân viên (Đổi mật khẩu)",
                      onPressed: () => _showResetStaffPasswordDialog(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
            const SizedBox(height: 16),
            
            Expanded(
              child: isMobile 
                ? Column(
                    children: [
                      _buildTableSection(true), 
                      const SizedBox(height: 12),
                      Expanded(child: _buildMenuSection(filteredProducts)), 
                    ],
                  )
                : Row( 
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildTableSection(false)),
                      const SizedBox(width: 16),
                      Expanded(flex: 4, child: _buildMenuSection(filteredProducts)), 
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _buildCartSection()), 
                    ],
                  ),
            )
          ],
        ),
      ),
    );
  }
}