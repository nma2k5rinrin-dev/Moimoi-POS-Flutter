import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:moimoi_pos/services/api/supabase_service.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/router/app_router.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/toast_overlay.dart';
import 'package:moimoi_pos/core/widgets/confirm_modal.dart';
import 'package:moimoi_pos/core/database/app_database.dart';
import 'package:moimoi_pos/services/connectivity/connectivity_service.dart';
import 'package:moimoi_pos/core/sync/sync_engine.dart';
import 'package:moimoi_pos/core/sync/sync_worker.dart';
import 'package:moimoi_pos/core/utils/security_utils.dart';

// Global instances for offline-first
AppDatabase? appDb;
ConnectivityService? connectivityService;
SyncEngine? syncEngine;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('[Supabase Init Error] $e');
  }

  // Init Drift database
  try {
    final encryptionKey = await SecurityUtils.getDatabaseKey();
    appDb = AppDatabase.connect(encryptionKey);
    debugPrint('[Drift] Encrypted database initialized OK');
  } catch (e) {
    debugPrint('[Drift] Database init failed: $e');
    appDb = null;
  }

  // Init connectivity
  connectivityService = ConnectivityService();
  connectivityService!.init();

  // Init sync engine (only if DB available)
  if (appDb != null) {
    syncEngine = SyncEngine(
      db: appDb!,
      connectivity: connectivityService!,
    );
    syncEngine!.init();
  } else {
    debugPrint('[SyncEngine] Skipped — no local DB');
  }

  // Init Workmanager background sync
  await SyncWorker.init();

  runApp(const MoiMoiPOS());
}

class MoiMoiPOS extends StatefulWidget {
  const MoiMoiPOS({super.key});

  @override
  State<MoiMoiPOS> createState() => _MoiMoiPOSState();
}

class _MoiMoiPOSState extends State<MoiMoiPOS> {
  final AppStore _store = AppStore();
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Inject Drift DB and SyncEngine into AppStore
    _store.initOfflineFirst(appDb, syncEngine);
    _router = createRouter(_store);
  }

  @override
  void dispose() {
    syncEngine?.dispose();
    connectivityService?.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _store,
      child: MaterialApp.router(
        title: 'MoiMoi POS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.light(
            primary: AppColors.emerald500,
            secondary: AppColors.emerald600,
            surface: AppColors.slate50,
            error: AppColors.red500,
          ),
          fontFamily: GoogleFonts.inter().fontFamily,
          fontFamilyFallback: const ['NotoSans', 'Inter', 'sans-serif'],
          textTheme: GoogleFonts.interTextTheme(),
          scaffoldBackgroundColor: AppColors.slate50,
          useMaterial3: true,
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
        routerConfig: _router,
        builder: (context, child) {
          _store.rootContext = context;
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Stack(
              children: [
                child ?? const SizedBox.shrink(),
                // Overlay: only rebuilds when toast/confirm state changes
                Consumer<AppStore>(
                  builder: (context, store, _) {
                    final hasToast = store.toastMessage != null;
                    final hasConfirm = store.confirmDialog != null;

                    // Nothing to show — return invisible widget that doesn't block touches
                    if (!hasToast && !hasConfirm) {
                      return const SizedBox.shrink();
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
      ),
    );
  }
}
