import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/utils/validators.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final _regEmailController = TextEditingController();
  final _regFullnameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regStoreNameController = TextEditingController();
  final _regAddressController = TextEditingController();
  final _regUsernameController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPassController = TextEditingController();

  final _regEmailFocus = FocusNode();
  final _regFullnameFocus = FocusNode();
  final _regPhoneFocus = FocusNode();
  final _regStoreNameFocus = FocusNode();
  final _regUsernameFocus = FocusNode();
  final _regPasswordFocus = FocusNode();
  final _regConfirmPassFocus = FocusNode();
  bool _showRegPassword = false;
  bool _showRegConfirmPass = false;

  String? _errorMessage;

  final LocalAuthentication _localAuth = LocalAuthentication();
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  IconData get _biometricIcon {
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint;
    } else if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face;
    }
    return Icons.lock_open_rounded;
  }

  String get _biometricLabel {
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Vân tay';
    } else if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Khuôn mặt';
    }
    return 'Sinh trắc học';
  }

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
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (canCheck && isSupported) {
        final available = await _localAuth.getAvailableBiometrics();
        if (!mounted) return;
        setState(() {
          _biometricAvailable = available.isNotEmpty;
          _availableBiometrics = available;
        });
        // Auto-trigger biometric if user has saved credentials
        if (_biometricAvailable) {
          final store = context.read<AuthStore>();
          final hasCreds = await store.hasSavedCredentials();
          if (hasCreds && mounted) {
            _handleBiometric();
          }
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _regEmailController.dispose();
    _regFullnameController.dispose();
    _regPhoneController.dispose();
    _regStoreNameController.dispose();
    _regAddressController.dispose();
    _regUsernameController.dispose();
    _regPasswordController.dispose();
    _regConfirmPassController.dispose();
    _regEmailFocus.dispose();
    _regFullnameFocus.dispose();
    _regPhoneFocus.dispose();
    _regStoreNameFocus.dispose();
    _regUsernameFocus.dispose();
    _regPasswordFocus.dispose();
    _regConfirmPassFocus.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final store = context.read<AuthStore>();
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
    if (!mounted) return;

    // Ngăn chặn UI flicker khi load quá nhanh
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => isLoading = false);
    if (result == 'success' && mounted) {
      context.go('/');
    } else if (result == 'already_online') {
      _showAlreadyOnlineDialog();
    } else {
      setState(() => _errorMessage = result);
    }
  }

  void _clearRegisterForm() {
    _regEmailController.clear();
    _regFullnameController.clear();
    _regPhoneController.clear();
    _regStoreNameController.clear();
    _regAddressController.clear();
    _regUsernameController.clear();
    _regPasswordController.clear();
    _regConfirmPassController.clear();
  }

  Future<void> _handleRegister() async {
    final store = context.read<AuthStore>();
    
    if (_regEmailController.text.isEmpty) {
      _regEmailFocus.requestFocus();
      setState(() => _errorMessage = 'Vui lòng nhập Email');
      return;
    }
    if (_regFullnameController.text.isEmpty) {
      _regFullnameFocus.requestFocus();
      setState(() => _errorMessage = 'Vui lòng nhập Họ và Tên');
      return;
    }
    if (_regPhoneController.text.isEmpty) {
      _regPhoneFocus.requestFocus();
      setState(() => _errorMessage = 'Vui lòng nhập Số Điện Thoại');
      return;
    }
    if (_regUsernameController.text.isEmpty) {
      _regUsernameFocus.requestFocus();
      setState(() => _errorMessage = 'Vui lòng nhập Tên Đăng Nhập');
      return;
    }
    if (_regPasswordController.text.isEmpty) {
      _regPasswordFocus.requestFocus();
      setState(() => _errorMessage = 'Vui lòng nhập Mật Khẩu');
      return;
    }

    // Validation Email
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_regEmailController.text.trim())) {
      _regEmailFocus.requestFocus();
      setState(() => _errorMessage = 'Email không hợp lệ');
      return;
    }

    // Validation SĐT
    final phoneRegex = RegExp(r'^(03|05|07|08|09)\d{8}$');
    if (!phoneRegex.hasMatch(_regPhoneController.text.trim())) {
      _regPhoneFocus.requestFocus();
      setState(
        () => _errorMessage =
            'Số điện thoại phải đủ 10 số (Bắt đầu bằng 03/05/07/08/09)',
      );
      return;
    }

    // Validation Fullname
    final nameRegex = RegExp(r'^[\w\sA-Za-zĂăÂâĐđÊêÔôƠơƯưÀ-ỹ]+$');
    final nameTrimmed = _regFullnameController.text.trim();
    if (nameTrimmed.split(' ').length < 2 || !nameRegex.hasMatch(nameTrimmed)) {
      _regFullnameFocus.requestFocus();
      setState(
        () => _errorMessage =
            'Họ và tên phải đầy đủ (gồm 2 từ) và không chứa số hay ký tự đặc biệt',
      );
      return;
    }

    final passError = validatePassword(_regPasswordController.text);
    if (passError != null) {
      _regPasswordFocus.requestFocus();
      setState(() => _errorMessage = passError);
      return;
    }
    if (_regPasswordController.text != _regConfirmPassController.text) {
      _regConfirmPassFocus.requestFocus();
      setState(() => _errorMessage = 'Mật khẩu xác nhận không khớp');
      return;
    }

    setState(() {
      isLoading = true;
      _errorMessage = null;
    });
    final result = await store.register(
      email: _regEmailController.text.trim(),
      fullname: _regFullnameController.text.trim(),
      phone: _regPhoneController.text.trim(),
      storeName: _regStoreNameController.text.trim(),
      address: _regAddressController.text.trim(),
      username: _regUsernameController.text.trim().toLowerCase().replaceAll(
        ' ',
        '',
      ),
      password: _regPasswordController.text,
    );
    if (!mounted) return;

    // Ngăn chặn UI flicker khi load quá nhanh
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    setState(() => isLoading = false);
    if (result == 'success' && mounted) {
      _clearRegisterForm();
      context.go('/');
    } else if (result == 'confirm_email') {
      _clearRegisterForm();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Đăng ký thành công',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Text(
            'Vui lòng kiểm tra hộp thư email của bạn (bao gồm cả thư rác) và click vào đường link xác nhận để kích hoạt tài khoản trước khi đăng nhập.',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF10B981),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _switchMode(); // Trở về Login
              },
              child: Text(
                'Đã hiểu',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    } else if (result == 'exists') {
      _regEmailFocus.requestFocus();
      setState(() => _errorMessage = 'Email này đã tồn tại trên hệ thống');
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

  // ── Biometric Authentication ──
  Future<void> _handleBiometric() async {
    try {
      final store = context.read<AuthStore>();

      // 1. Check if device supports biometrics
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) {
        if (!mounted) return;
        setState(
          () => _errorMessage = 'Thiết bị không hỗ trợ xác thực sinh trắc học',
        );
        return;
      }

      // 2. Check if user has previously logged in (credentials cached)
      final hasCreds = await store.hasSavedCredentials();
      if (!hasCreds) {
        if (!mounted) return;
        setState(
          () => _errorMessage =
              'Chưa có thông tin đăng nhập. Hãy đăng nhập bằng mật khẩu trước',
        );
        return;
      }

      // 3. Perform biometric verification
      setState(() {
        isLoading = true;
        _errorMessage = null;
      });

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Xác thực để đăng nhập MoiMoi POS',
      );

      if (!didAuthenticate) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          _errorMessage = 'Xác thực sinh trắc học thất bại';
        });
        return;
      }

      // 4. Use cached credentials to login via Supabase
      final result = await store.loginWithBiometric();
      if (!mounted) return;
      setState(() => isLoading = false);

      if (result == 'success') {
        context.go('/');
      } else if (result == 'already_online') {
        _showAlreadyOnlineDialog();
      } else if (result == 'no_credentials') {
        setState(
          () => _errorMessage =
              'Thông tin đăng nhập đã hết hạn. Hãy đăng nhập lại bằng mật khẩu',
        );
      } else {
        setState(
          () => _errorMessage =
              'Đăng nhập thất bại. Hãy thử đăng nhập bằng mật khẩu',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _errorMessage = 'Lỗi xác thực sinh trắc học';
      });
    }
  }

  void _showAlreadyOnlineDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.red100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.devices_rounded,
                  size: 32,
                  color: Color(0xFFEF4444),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Thiết bị khác đang đăng nhập',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              Text(
                'Tài khoản này đang được sử dụng trên một thiết bị khác. Vui lòng đăng xuất trên thiết bị đó trước khi đăng nhập tại đây.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.slate500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Xác nhận',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.scaffoldBg,
              AppColors.emerald50,
              AppColors.scaffoldBg,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - bottomInset,
                    maxWidth: double.infinity,
                  ),
                  child: Center(
                    child: SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Brand header
                              _buildBrandHeader(),
                              SizedBox(height: 28),

                              // Main card
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBg,
                                  borderRadius: BorderRadius.circular(28),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF10B981,
                                      ).withValues(alpha: 0.07),
                                      blurRadius: 60,
                                      offset: const Offset(0, 20),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _buildPasswordCard(),
                              ),

                              SizedBox(height: 20),
                              // Footer
                              Text(
                                '© 2025 MoiMoi POS · Phần mềm quản lý bán hàng',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.slate400.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => launchUrl(
                                  Uri.parse(
                                    'https://docs.google.com/document/d/1A0i6Gq__4pY6Z8FqweItaelxnvEYGeQNRgQIabx9kks/edit?usp=sharing',
                                  ),
                                ),
                                child: Text(
                                  'Chính sách bảo mật & Điều khoản sử dụng',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.emerald500,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.emerald500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Password mode card content ──
  Widget _buildPasswordCard() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          isLogin ? 'Chào mừng trở lại' : 'Đăng ký tài khoản',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.slate800,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 6),
        Text(
          isLogin
              ? 'Đăng nhập để quản lý cửa hàng của bạn'
              : 'Tạo tài khoản mới để bắt đầu',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.slate500,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 24),

        // Error
        if (_errorMessage != null) _buildErrorBanner(_errorMessage!),

        if (isLogin) _buildLoginForm() else _buildRegisterForm(),

        SizedBox(height: 20),

        // ── "hoặc đăng nhập bằng" divider + biometric button ──
        if (isLogin && _biometricAvailable) ...[
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.slate200)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'hoặc đăng nhập bằng',
                  style: TextStyle(
                    color: AppColors.slate400,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColors.slate200)),
            ],
          ),
          SizedBox(height: 16),

          // Single biometric button
          _buildAuthMethodButton(
            icon: _biometricIcon,
            label: _biometricLabel,
            color: const Color(0xFF10B981),
            onTap: _handleBiometric,
          ),
          SizedBox(height: 20),
        ],

        // ── Register / Login switch ──
        Row(
          children: [
            Expanded(child: Divider(color: AppColors.slate200)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isLogin ? 'Chưa có tài khoản?' : 'Đã có tài khoản?',
                style: TextStyle(
                  color: AppColors.slate400,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(child: Divider(color: AppColors.slate200)),
          ],
        ),
        SizedBox(height: 16),

        // Switch button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _switchMode,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.slate200, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              isLogin ? 'Đăng ký tài khoản mới' : 'Đăng nhập',
              style: TextStyle(
                color: AppColors.slate700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandHeader() {
    return Column(
      children: [
        // Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/app_logo_1024x1024.png',
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Quản lý cửa hàng - POS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.slate800,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Hệ thống POS chuyên nghiệp, tối ưu vận hành, quản lý báo cáo chính xác 24/7 ngay trên điện thoại.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.slate500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(String msg) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.red50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.red200, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.red500, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: TextStyle(
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
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildField(
          controller: _usernameController,
          label: 'Email / Tên đăng nhập',
          icon: Icons.person_outline_rounded,
          hint: 'Email / Tên đăng nhập',
        ),
        SizedBox(height: 14),
        _buildField(
          controller: _passwordController,
          label: 'Mật khẩu',
          icon: Icons.lock_outline_rounded,
          hint: 'Nhập mật khẩu',
          isPassword: true,
          showPassword: _showPassword,
          onToggle: () => setState(() => _showPassword = !_showPassword),
        ),
        TextButton(
          onPressed: _showForgotPasswordDialog,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Quên mật khẩu?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF10B981),
            ),
          ),
        ),
        SizedBox(height: 18),
        _buildPrimaryButton(
          label: isLoading ? null : 'Đăng nhập',
          isLoading: isLoading,
          onPressed: isLoading ? null : _handleLogin,
        ),
      ],
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    bool isSending = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Khôi phục mật khẩu',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nhập email bạn đã dùng để đăng ký tài khoản. Chúng tôi sẽ gửi một liên kết để bạn đặt lại mật khẩu mới.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate600,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Nhập email...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.slate400,
                      ),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: AppColors.slate400,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.slate50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actionsPadding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: 24,
                top: 8,
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: AppColors.slate200,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Hủy',
                              style: TextStyle(
                                color: AppColors.slate700,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildPrimaryButton(
                          label: 'Xác nhận',
                          isLoading: isSending,
                          onPressed: isSending
                              ? null
                              : () async {
                                  if (emailController.text.trim().isEmpty ||
                                      !emailController.text.contains('@')) {
                                    setDialogState(
                                      () => error = 'Email không hợp lệ',
                                    );
                                    return;
                                  }
                                  setDialogState(() {
                                    error = null;
                                    isSending = true;
                                  });
                                  final store = context.read<AuthStore>();
                                  final res = await store.forgotPassword(
                                    emailController.text,
                                  );
                                  if (!context.mounted) return;
                                  if (res == 'success') {
                                    Navigator.pop(ctx);
                                    store.showToast(
                                      'Đã gửi link khôi phục đến email của bạn!',
                                    );
                                  } else {
                                    setDialogState(() {
                                      error = res;
                                      isSending = false;
                                    });
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      children: [
        _buildField(
          controller: _regEmailController,
          focusNode: _regEmailFocus,
          label: 'Email',
          icon: Icons.email_outlined,
          hint: 'moimoipos@gmail.com',
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: 12),
        _buildField(
          controller: _regFullnameController,
          focusNode: _regFullnameFocus,
          label: 'Họ và Tên',
          icon: Icons.badge_outlined,
          hint: 'Nguyễn Văn A',
        ),
        SizedBox(height: 12),
        _buildField(
          controller: _regPhoneController,
          focusNode: _regPhoneFocus,
          label: 'Số Điện Thoại',
          icon: Icons.phone_outlined,
          hint: '0987654321',
          keyboardType: TextInputType.phone,
        ),
        SizedBox(height: 12),
        _buildField(
          controller: _regStoreNameController,
          focusNode: _regStoreNameFocus,
          label: 'Tên Cửa Hàng',
          icon: Icons.storefront_outlined,
          hint: 'Quán Ăn ABC / Cửa Hàng ABC',
        ),
        SizedBox(height: 12),
        _buildField(
          controller: _regUsernameController,
          focusNode: _regUsernameFocus,
          label: 'Tên Đăng Nhập',
          icon: Icons.alternate_email_rounded,
          hint: 'Viết thường, không dấu',
        ),
        SizedBox(height: 12),
        _buildField(
          controller: _regPasswordController,
          focusNode: _regPasswordFocus,
          label: 'Mật Khẩu',
          icon: Icons.lock_outline_rounded,
          hint: 'Nhập mật khẩu',
          isPassword: true,
          showPassword: _showRegPassword,
          onToggle: () => setState(() => _showRegPassword = !_showRegPassword),
        ),
        SizedBox(height: 12),
        _buildField(
          controller: _regConfirmPassController,
          focusNode: _regConfirmPassFocus,
          label: 'Xác Nhận Mật Khẩu',
          icon: Icons.lock_outline_rounded,
          hint: 'Nhập lại mật khẩu',
          isPassword: true,
          showPassword: _showRegConfirmPass,
          onToggle: () =>
              setState(() => _showRegConfirmPass = !_showRegConfirmPass),
        ),
        SizedBox(height: 22),
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
    FocusNode? focusNode,
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.slate600,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          focusNode: focusNode,
          obscureText: isPassword && !showPassword,
          keyboardType: keyboardType,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.slate800,
            fontSize: 15,
          ),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: EdgeInsets.only(left: 14, right: 10),
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
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.slate200.withValues(alpha: 0.7),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.emerald500, width: 1.5),
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
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Container(
            alignment: Alignment.center,
            height: 52,
            child: isLoading
                ? SizedBox(
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.3,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Biometric / PIN method button matching the design
  Widget _buildAuthMethodButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
