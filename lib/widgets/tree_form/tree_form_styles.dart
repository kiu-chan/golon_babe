import 'package:flutter/material.dart';

class TreeFormStyles {
  static final mainColor = Colors.lightGreen[200];
  static final accentColor = Colors.lightGreen[600];

  static InputDecoration textFieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mainColor!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mainColor!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mainColor!, width: 2),
      ),
      labelStyle: TextStyle(color: accentColor),
    );
  }

  static InputDecoration searchFieldDecoration() {
    return InputDecoration(
      labelText: 'Tìm kiếm theo ID',
      hintText: 'Nhập ID cây cần tìm',
      prefixIcon: Icon(Icons.search, color: mainColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mainColor!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mainColor!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: mainColor!, width: 2),
      ),
    );
  }

  static ButtonStyle elevatedButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: mainColor,
      foregroundColor: Colors.black87,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  static ButtonStyle submitButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: mainColor,
      foregroundColor: Colors.black87,
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      elevation: 3,
    );
  }

  static TextStyle titleStyle() {
    return TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: accentColor,
    );
  }

  static BoxDecoration cardDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          spreadRadius: 1,
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }
}