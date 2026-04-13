import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moimoi_pos/services/api/supabase_service.dart';
import 'package:moimoi_pos/features/auth/logic/auth_store_standalone.dart' as standalone_auth;
import 'package:moimoi_pos/core/state/ui_store.dart' as standalone;
import 'package:moimoi_pos/core/state/audio_store_standalone.dart' as standalone_audio;
import 'package:moimoi_pos/features/inventory/logic/inventory_store_standalone.dart' as standalone_inv;
import 'package:moimoi_pos/features/pos_order/logic/cart_store_standalone.dart' as standalone_cart;
import 'package:moimoi_pos/features/pos_order/logic/order_store_standalone.dart' as standalone_order;
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart' as standalone_mgmt;
import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart' as standalone_cash;
import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart' as standalone_prem;
import 'package:moimoi_pos/core/state/quota_store.dart';
import 'package:moimoi_pos/core/state/order_filter_store.dart';
import 'package:moimoi_pos/core/router/app_router.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/toast_overlay.dart';
import 'package:moimoi_pos/features/auth/models/user_model.dart';
import 'package:moimoi_pos/core/widgets/confirm_modal.dart';
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/core/utils/notification_helper.dart';
import 'package:moimoi_pos/core/services/background_service.dart';
import 'package:moimoi_pos/services/connectivity/connectivity_service.dart';
import 'package:moimoi_pos/core/sync/sync_engine.dart';
import 'package:moimoi_pos/core/sync/sync_worker.dart';
import 'package:moimoi_pos/core/utils/security_utils.dart';
import 'package:moimoi_pos/core/utils/security_rasp.dart';
import 'package:moimoi_pos/core/utils/env_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;

// Global instances for offline-first
AppDatabase? appDb;
ConnectivityService? connectivityService;
SyncEngine? syncEngine;

void main() async {
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsFlutterBinding.ensureInitialized();
  try {
    debugPrint('[ENV] SUPABASE_URL="${EnvConfig.supabaseUrl}"');
    debugPrint(
      '[ENV] SUPABASE_ANON_KEY="${EnvConfig.supabaseAnonKey.substring(0, 20)}..."',
    );
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('[Supabase Init Error] $e');
  }

  // Chạy cấu hình chống Root/Jailbreak
  await SecurityRasp.init();

  // Init Drift database (skip on Web — WASM not supported)
  if (!kIsWeb) {
    try {
      final encryptionKey = await SecurityUtils.getDatabaseKey();
      appDb = AppDatabase.connect(encryptionKey);
      debugPrint('[Drift] Encrypted database initialized OK');
    } catch (e) {
      debugPrint('[Drift] Database init failed: $e');
      appDb = null;
    }
  } else {
    debugPrint('[Drift] Skipped on Web — WASM not supported');
  }

  // Init connectivity
  connectivityService = ConnectivityService();
  connectivityService!.init();

  // Init sync engine (only if DB available)
  if (appDb != null) {
    syncEngine = SyncEngine(db: appDb!, connectivity: connectivityService!);
    syncEngine!.init();
  } else {
    debugPrint('[SyncEngine] Skipped — no local DB');
  }

  // Init Workmanager background sync
  await SyncWorker.init();

  // Init Notifications & Background Service
  if (!kIsWeb) {
    try {
      await NotificationHelper.init();
      await BackgroundServiceHelper.initialize();
    } catch (e) {
      debugPrint('[Notification] init error: $e');
    }
  }

  // Pre-load theme BEFORE first frame to avoid flash of light mode
  bool preloadedDarkMode = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    preloadedDarkMode = prefs.getBool('isDarkMode') ?? false;
    AppColors.switchTheme(preloadedDarkMode);
  } catch (e) {
    debugPrint('[Theme] Preload error: $e');
  }

  runApp(MoiMoiPOS(initialDarkMode: preloadedDarkMode));
}

class MoiMoiPOS extends StatefulWidget {
  final bool initialDarkMode;
  const MoiMoiPOS({super.key, this.initialDarkMode = false});

  @override
  State<MoiMoiPOS> createState() => _MoiMoiPOSState();
}

class _MoiMoiPOSState extends State<MoiMoiPOS> with WidgetsBindingObserver {
  final standalone.UIStore _uiStore = standalone.UIStore();
  final standalone_audio.AudioStore _audioStore = standalone_audio.AudioStore();
  final standalone_auth.AuthStore _authStore = standalone_auth.AuthStore();
  late final standalone_inv.InventoryStore _invStore;
  final standalone_cart.CartStore _cartStore = standalone_cart.CartStore();
  late final standalone_order.OrderStore _orderStore;
  late final standalone_mgmt.ManagementStore _mgmtStore;
  late final standalone_cash.CashflowStore _cashflowStore;
  final QuotaStore _quotaStore = QuotaStore();
  late final OrderFilterStore _orderFilterStore;
  late final standalone_prem.PremiumStore _premiumStore;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((p) => p.setBool('app_in_foreground', true));
    
    _invStore = standalone_inv.InventoryStore(_quotaStore);
    _orderStore = standalone_order.OrderStore(
      quotaProvider: _quotaStore,
      cartStore: _cartStore,
      getCurrentUser: () => _authStore.currentUser,
      onPlayNewOrderSound: () => _audioStore.playNewOrderSound(),
    );
    _mgmtStore = standalone_mgmt.ManagementStore(
      authStore: _authStore,
      quotaProvider: _quotaStore,
    );
    _cashflowStore = standalone_cash.CashflowStore(
      quotaProvider: _quotaStore,
      getCurrentUser: () => _authStore.currentUser,
    );
    _premiumStore = standalone_prem.PremiumStore(
      authStore: _authStore,
      managementStore: _mgmtStore,
      quotaProvider: _quotaStore,
      onLoadInitialData: _loadData,
      onShowToast: _uiStore.showToast,
    )..initIAP();
    
    // Assign data loader to AuthStore so it triggers after login
    _authStore.onLoadInitialData = _loadData;
    
    // Wire up QuotaStore (aggregates from individual stores)
    _quotaStore.init(
      auth: _authStore,
      inv: _invStore,
      order: _orderStore,
      mgmt: _mgmtStore,
    );
    
    // Create OrderFilterStore (computed order views + badges)
    _orderFilterStore = OrderFilterStore(
      auth: _authStore,
      order: _orderStore,
    );
    
    // Wait! I actually WANT to delete them. There's no replacement code needed except empty.

    // Apply preloaded theme immediately (no async delay)
    _uiStore.isDarkMode = widget.initialDarkMode;
    AppColors.switchTheme(widget.initialDarkMode);
    _audioStore.initAudio();
    _router = createRouter(_authStore);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    syncEngine?.dispose();
    connectivityService?.dispose();
    _router.dispose();
    _uiStore.dispose();
    _audioStore.dispose();
    _authStore.dispose();
    _invStore.dispose();
    _cartStore.dispose();
    _orderStore.dispose();
    _mgmtStore.dispose();
    _cashflowStore.dispose();
    _premiumStore.dispose();
    _orderFilterStore.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Đánh dấu app foreground/background để background service biết
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('app_in_foreground', state == AppLifecycleState.resumed);
    });

    if (state == AppLifecycleState.resumed) {
      debugPrint('[Lifecycle] App resumed. Triggering immediate sync...');
      if (_authStore.currentUser != null) {
        _loadData(_authStore.currentUser!);
      }
      syncEngine?.tryImmediateSync();
    }
  }

  Future<void> _loadData(UserModel user) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sid = _quotaStore.getStoreId();

    try {
      if (user.role == 'sadmin' && sid == 'sadmin') {
        await _mgmtStore.initManagementStore(null, user);
        return;
      }

      await Future.wait([
        _mgmtStore.initManagementStore(sid, user),
        _invStore.initInventoryStore(sid),
        _orderStore.initOrderStore(sid, todayStart),
      ]);
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<standalone.UIStore>.value(value: _uiStore),
        ChangeNotifierProvider<standalone_audio.AudioStore>.value(value: _audioStore),
        ChangeNotifierProvider<standalone_auth.AuthStore>.value(value: _authStore),
        ChangeNotifierProvider<standalone_inv.InventoryStore>.value(value: _invStore),
        ChangeNotifierProvider<standalone_cart.CartStore>.value(value: _cartStore),
        ChangeNotifierProvider<standalone_order.OrderStore>.value(value: _orderStore),
        ChangeNotifierProvider<standalone_mgmt.ManagementStore>.value(value: _mgmtStore),
        ChangeNotifierProvider<standalone_cash.CashflowStore>.value(value: _cashflowStore),
        ChangeNotifierProvider<standalone_prem.PremiumStore>.value(value: _premiumStore),
        ChangeNotifierProvider<OrderFilterStore>.value(value: _orderFilterStore),
        Provider<QuotaStore>.value(value: _quotaStore),
      ],
      child: Consumer<standalone.UIStore>(
        builder: (context, store, _) {
          final isDark = store.isDarkMode;
          return MaterialApp.router(
            title: 'MoiMoi POS',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: isDark ? Brightness.dark : Brightness.light,
              colorScheme: isDark
                  ? ColorScheme.dark(
                      primary: AppColors.emerald500,
                      secondary: AppColors.emerald600,
                      surface: AppColors.cardBg,
                      error: AppColors.red500,
                    )
                  : ColorScheme.light(
                      primary: AppColors.emerald500,
                      secondary: AppColors.emerald600,
                      surface: AppColors.slate50,
                      error: AppColors.red500,
                    ),
              fontFamily: GoogleFonts.inter().fontFamily,
              fontFamilyFallback: const ['NotoSans', 'Inter', 'sans-serif'],
              textTheme: GoogleFonts.interTextTheme(),
              scaffoldBackgroundColor: AppColors.scaffoldBg,
              dialogBackgroundColor: AppColors.dialogBg,
              cardColor: AppColors.cardBg,
              dividerColor: AppColors.dividerColor,
              useMaterial3: true,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
                },
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  textStyle: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            routerConfig: _router,
            builder: (context, child) {
              _uiStore.rootContext = context;
              _authStore.rootContext = context;
              _invStore.rootContext = context;
              _orderStore.rootContext = context;
              _mgmtStore.rootContext = context;
              _cashflowStore.rootContext = context;
              _premiumStore.rootContext = context;
              return GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Stack(
                  children: [
                    child ?? SizedBox.shrink(),
                    // Overlay: only rebuilds when toast/confirm state changes
                    Consumer<standalone.UIStore>(
                      builder: (context, store, _) {
                        final hasToast = store.toastMessage != null;
                        final hasConfirm = store.confirmDialog != null;

                        // Nothing to show — return invisible widget that doesn't block touches
                        if (!hasToast && !hasConfirm) {
                          return SizedBox.shrink();
                        }

                        return Stack(
                          children: [
                            if (hasToast)
                              ToastOverlay(
                                message: store.toastMessage!,
                                type: store.toastType,
                              ),
                            if (hasConfirm)
                              ConfirmModal(
                                data: store.confirmDialog!,
                                onCancel: () => store.closeConfirm(),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
