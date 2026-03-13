import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  bool isLogin = true;
  bool isLoading = false;

  // Login
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;

  // Register
  final _regFullnameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regStoreNameController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPassController = TextEditingController();
  bool _showRegPassword = false;
  bool _showRegConfirmPass = false;

  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _regFullnameController.dispose();
    _regPhoneController.dispose();
    _regStoreNameController.dispose();
    _regUsernameController.dispose();
    _regPasswordController.dispose();
    _regConfirmPassController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final store = context.read<AppStore>();
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ thông tin');
      return;
    }
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    final result = await store.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );
    setState(() => isLoading = false);
    if (result == 'success' && mounted) {
      context.go('/');
    } else {
      setState(() => _errorMessage = 'Tên đăng nhập hoặc mật khẩu không đúng');
    }
  }

  Future<void> _handleRegister() async {
    final store = context.read<AppStore>();
    if (_regUsernameController.text.isEmpty ||
        _regPasswordController.text.isEmpty ||
        _regFullnameController.text.isEmpty) {
      setState(() => _errorMessage = 'Vui lòng nhập đầy đủ thông tin');
      return;
    }
    final passError = validatePassword(_regPasswordController.text);
    if (passError != null) {
      setState(() => _errorMessage = passError);
      return;
    }
    if (_regPasswordController.text != _regConfirmPassController.text) {
      setState(() => _errorMessage = 'Mật khẩu xác nhận không khớp');
      return;
    }
    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    final result = await store.register(
      fullname: _regFullnameController.text.trim(),
      phone: _regPhoneController.text.trim(),
      storeName: _regStoreNameController.text.trim(),
      username:
          _regUsernameController.text.trim().toLowerCase().replaceAll(' ', ''),
      password: _regPasswordController.text,
    );
    setState(() => isLoading = false);
    if (result == 'success' && mounted) {
      context.go('/');
    } else if (result == 'exists') {
      setState(() => _errorMessage = 'Tên đăng nhập đã tồn tại');
    } else {
      setState(() => _errorMessage = 'Đăng ký thất bại, vui lòng thử lại');
    }
  }

  void _switchMode() {
    _animController.reset();
    setState(() {
      isLogin = !isLogin;
      _errorMessage = null;
    });
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0FDF4), // emerald-50
              Color(0xFFECFDF5),
              Color(0xFFE0F2FE), // sky-100
              Color(0xFFF0F9FF), // sky-50
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    children: [
                      // Brand header
                      _buildBrandHeader(),
                      const SizedBox(height: 28),

                      // Main card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.07),
                              blurRadius: 60,
                              offset: const Offset(0, 20),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title
                            Text(
                              isLogin
                                  ? 'Chào mừng trở lại'
                                  : 'Tạo tài khoản mới',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.slate800,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isLogin
                                  ? 'Đăng nhập để quản lý cửa hàng của bạn'
                                  : 'Bắt đầu miễn phí, nâng cấp bất cứ lúc nào',
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.slate500,
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),

                            // Error
                            if (_errorMessage != null)
                              _buildErrorBanner(_errorMessage!),

                            if (isLogin)
                              _buildLoginForm()
                            else
                              _buildRegisterForm(),

                            const SizedBox(height: 24),

                            // Divider
                            Row(
                              children: [
                                const Expanded(
                                    child: Divider(color: AppColors.slate200)),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    isLogin
                                        ? 'Chưa có tài khoản?'
                                        : 'Đã có tài khoản?',
                                    style: const TextStyle(
                                      color: AppColors.slate400,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const Expanded(
                                    child: Divider(color: AppColors.slate200)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Switch
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _switchMode,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppColors.slate200, width: 1.5),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  isLogin
                                      ? 'Đăng ký tài khoản mới'
                                      : 'Đăng nhập tài khoản',
                                  style: const TextStyle(
                                    color: AppColors.slate700,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                      // Footer
                      Text(
                        '© 2024 MoiMoi POS · Phần mềm quản lý bán hàng',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.slate400.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.point_of_sale, color: Colors.white, size: 28),
              SizedBox(height: 2),
              Text(
                'POS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'MoiMoi POS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.slate800,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red200, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.red500, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: AppColors.red600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildField(
          controller: _usernameController,
          label: 'Tên đăng nhập',
          icon: Icons.person_outline_rounded,
          hint: 'Nhập tên đăng nhập',
        ),
        const SizedBox(height: 14),
        _buildField(
          controller: _passwordController,
          label: 'Mật khẩu',
          icon: Icons.lock_outline_rounded,
          hint: 'Nhập mật khẩu',
          isPassword: true,
          showPassword: _showPassword,
          onToggle: () => setState(() => _showPassword = !_showPassword),
        ),
        const SizedBox(height: 22),
        _buildPrimaryButton(
          label: isLoading ? null : 'Đăng nhập',
          isLoading: isLoading,
          onPressed: isLoading ? null : _handleLogin,
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        _buildField(
          controller: _regFullnameController,
          label: 'Họ và Tên',
          icon: Icons.badge_outlined,
          hint: 'Nguyễn Văn A',
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _regPhoneController,
          label: 'Số Điện Thoại',
          icon: Icons.phone_outlined,
          hint: '0987654321',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _regStoreNameController,
          label: 'Tên Cửa Hàng',
          icon: Icons.storefront_outlined,
          hint: 'Quán Ăn ABC',
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _regUsernameController,
          label: 'Tên Đăng Nhập',
          icon: Icons.alternate_email_rounded,
          hint: 'Viết thường, không dấu',
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _regPasswordController,
          label: 'Mật Khẩu',
          icon: Icons.lock_outline_rounded,
          hint: 'Tối thiểu 8 ký tự, gồm chữ/số/đặc biệt',
          isPassword: true,
          showPassword: _showRegPassword,
          onToggle: () =>
              setState(() => _showRegPassword = !_showRegPassword),
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _regConfirmPassController,
          label: 'Xác Nhận Mật Khẩu',
          icon: Icons.lock_outline_rounded,
          hint: 'Nhập lại mật khẩu',
          isPassword: true,
          showPassword: _showRegConfirmPass,
          onToggle: () =>
              setState(() => _showRegConfirmPass = !_showRegConfirmPass),
        ),
        const SizedBox(height: 22),
        _buildPrimaryButton(
          label: isLoading ? null : 'Tạo tài khoản',
          isLoading: isLoading,
          onPressed: isLoading ? null : _handleRegister,
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onToggle,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.slate600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && !showPassword,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.slate800,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, color: AppColors.slate400, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.slate400,
                      size: 20,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.slate400.withValues(alpha: 0.7),
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: AppColors.slate50,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: AppColors.slate200.withValues(alpha: 0.7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.emerald500, width: 1.5),
            ),
          ),
          onSubmitted: (_) {
            if (isLogin) _handleLogin();
          },
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    String? label,
    bool isLoading = false,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.emerald500,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.emerald400,
          disabledForegroundColor: Colors.white70,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label ?? '',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 18),
                ],
              ),
      ),
    );
  }
}
