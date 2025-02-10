class TreeFormValidator {
  static String _formatNumber(String text) {
    // Thay thế dấu phẩy bằng dấu chấm
    String formattedText = text.replaceAll(',', '.');
    // Đảm bảo chỉ có một dấu thập phân
    int decimalCount = '.'.allMatches(formattedText).length;
    if (decimalCount > 1) {
      // Giữ lại dấu thập phân đầu tiên, bỏ các dấu còn lại
      formattedText = formattedText.replaceAll(RegExp(r'\.(?=.*\.)'), '');
    }
    return formattedText;
  }

  static double? parseNumber(String text) {
    if (text.isEmpty) return null;
    String formattedText = _formatNumber(text);
    return double.tryParse(formattedText);
  }

  static bool validateCoordinate(String? value) {
    if (value == null || value.isEmpty) return true; // Cho phép để trống
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    // Kiểm tra số thập phân tối đa 6 chữ số
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 6;
  }

  static bool validateHeight(String? value) {
    if (value == null || value.isEmpty) return true; // Cho phép để trống
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    
    // Kiểm tra giới hạn: > 0 và <= 999.99
    if (number <= 0 || number > 999.99) return false;
    
    // Kiểm tra số thập phân tối đa 2 chữ số
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 2;
  }

  static bool validateDiameter(String? value) {
    if (value == null || value.isEmpty) return true;
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    
    // Kiểm tra giới hạn: > 0 và <= 9999.99
    if (number <= 0 || number > 9999.99) return false;
    
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 2;
  }

  static bool validateSeaLevel(String? value) {
    if (value == null || value.isEmpty) return true;
    String formattedValue = _formatNumber(value);
    double? number = double.tryParse(formattedValue);
    if (number == null) return false;
    
    // Kiểm tra giới hạn: -99999.99 đến 99999.99
    if (number < -99999.99 || number > 99999.99) return false;
    
    String decimalPart = formattedValue.contains('.') 
        ? formattedValue.split('.')[1] 
        : '';
    return decimalPart.length <= 2;
  }
}