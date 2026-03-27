import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'services/supabase_service.dart';
import 'store/app_store.dart';
import 'router/app_router.dart';
import 'utils/constants.dart';
import 'widgets/toast_overlay.dart';
import 'widgets/confirm_modal.dart';
import 'db/app_database.dart';
import 'sync/connectivity_service.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_worker.dart';

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

  // Init Drift database (may fail on web due to WASM)
  try {
    appDb = AppDatabase();
    debugPrint('[Drift] Database initialized OK');
  } catch (e) {
    debugPrint('[Drift] Database init failed (web WASM?): $e');
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
