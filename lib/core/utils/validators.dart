String? validatePassword(String password) {
  if (password.isEmpty) return 'Mật khẩu không được để trống';
  if (password.length < 8 || password.length > 20) {
    return 'Mật khẩu phải từ 8 đến 20 ký tự, ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt (!@#\$^*)';
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return 'Mật khẩu phải từ 8 đến 20 ký tự, ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt (!@#\$^*)';
  }
  if (!RegExp(r'[a-z]').hasMatch(password)) {
    return 'Mật khẩu phải từ 8 đến 20 ký tự, ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt (!@#\$^*)';
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return 'Mật khẩu phải từ 8 đến 20 ký tự, ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt (!@#\$^*)';
  }
  if (!RegExp(r'[!@#$^*]').hasMatch(password)) {
    return 'Mật khẩu phải từ 8 đến 20 ký tự, ít nhất 1 chữ hoa, 1 chữ thường, 1 số và 1 ký tự đặc biệt (!@#\$^*)';
  }
  return null;
}
