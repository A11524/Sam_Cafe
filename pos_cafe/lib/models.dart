import 'package:flutter/material.dart';

class Product {
  final String id;
  final String name;
  final int price;
  final IconData icon;
  final Color color;
  final int stock; // Bổ sung tồn kho cho màn hình Hàng Hóa
  final int categoryId; // THÊM MỚI: ID danh mục

  Product({
    required this.id, 
    required this.name, 
    required this.price, 
    required this.icon, 
    required this.color,
    this.stock = 100,
    this.categoryId = 1, // Mặc định là 1 (Cà phê)
  });
}

class CartItem {
  final Product product;
  int quantity;
  String note; // THÊM MỚI: Ghi chú cho từng món

  CartItem({required this.product, this.quantity = 1, this.note = "",});
  
  int get totalPrice => product.price * quantity;
}