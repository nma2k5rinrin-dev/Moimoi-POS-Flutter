String? validatePassword(String password) {
  if (password.isEmpty) return 'Mật khẩu không được để trống';
  if (password.length < 8 || password.length > 20) {
    return 'Mật khẩu phải từ 8 đến 20 ký tự';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Mật khẩu phải chứa ít nhất 1 chữ viết hoa';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Mật khẩu phải chứa ít nhất 1 chữ viết thường';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Mật khẩu phải chứa ít nhất 1 chữ số';
  }
  if (!RegExp(r'[!@#$^*]').hasMatch(password)) {
    return 'Mật khẩu phải chứa ít nhất 1 ký tự đặc biệt (!@#\$^*)';
  }
  return null;
}
