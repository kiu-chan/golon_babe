import 'package:flutter/material.dart';

class TreeFormStyles {
  static final mainColor = Colors.lightGreen[400]; // Đậm hơn một chút để tương phản tốt với chữ trắng
  static final accentColor = Colors.lightGreen[600];
  static final backgroundColor = Colors.lightGreen[50];

  static InputDecoration textFieldDecoration(String label, {Widget? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      labelStyle: TextStyle(color: accentColor),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  static InputDecoration searchFieldDecoration() {
    return textFieldDecoration(
      'Tìm kiếm theo ID',
      prefixIcon: Icon(Icons.search, color: accentColor),
    ).copyWith(
      hintText: 'Nhập ID cây cần tìm',
    );
  }

  static ButtonStyle elevatedButtonStyle({bool isOutlined = false}) {
    return ElevatedButton.styleFrom(
      backgroundColor: isOutlined ? Colors.white : mainColor,
      foregroundColor: isOutlined ? accentColor : Colors.white, // Thay đổi màu chữ thành trắng
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      elevation: isOutlined ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isOutlined ? BorderSide(color: accentColor!) : BorderSide.none,
      ),
    );
  }

  static ButtonStyle submitButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: accentColor,
      foregroundColor: Colors.white, // Thay đổi màu chữ thành trắng
      padding: const EdgeInsets.symmetric(vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      shadowColor: accentColor?.withOpacity(0.5),
    );
  }

  static TextStyle titleStyle() {
    return TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: accentColor,
      letterSpacing: 0.5,
    );
  }

  static TextStyle subtitleStyle() {
    return TextStyle(
      fontSize: 16,
      color: Colors.grey[600],
      height: 1.5,
    );
  }

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration sectionDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.withOpacity(0.2)),
    );
  }
}