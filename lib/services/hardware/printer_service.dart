import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:moimoi_pos/features/pos_order/models/order_model.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';

class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._();
  factory PrinterService() => _instance;
  PrinterService._();

  // ── State ──────────────────────────────────────────────
  bool _isConnected = false;
  bool _isScanning = false;
  String? _savedAddress;
  String? _savedName;
  List<BluetoothInfo> _devices = [];

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String? get savedAddress => _savedAddress;
  String? get savedName => _savedName;
  List<BluetoothInfo> get devices => _devices;

  // ── Init ───────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _savedAddress = prefs.getString('printer_address');
    _savedName = prefs.getString('printer_name');
    _isConnected = await PrintBluetoothThermal.connectionStatus;
    notifyListeners();

    // Auto-reconnect if saved printer
    if (_savedAddress != null && !_isConnected) {
      await connect(_savedAddress!, name: _savedName);
    }
  }

  // ── Scan ───────────────────────────────────────────────
  Future<void> scanDevices() async {
    _isScanning = true;
    _devices = [];
    notifyListeners();

    try {
      final result = await PrintBluetoothThermal.pairedBluetooths;
      _devices = result;
    } catch (e) {
      debugPrint('[PrinterService] scan error: $e');
    }

    _isScanning = false;
    notifyListeners();
  }

  // ── Connect ────────────────────────────────────────────
  Future<bool> connect(String macAddress, {String? name}) async {
    try {
      final result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      _isConnected = result;
      if (result) {
        _savedAddress = macAddress;
        _savedName = name;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('printer_address', macAddress);
        if (name != null) await prefs.setString('printer_name', name);
      }
      notifyListeners();
      return result;
    } catch (e) {
      debugPrint('[PrinterService] connect error: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // ── Disconnect ─────────────────────────────────────────
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    _isConnected = false;
    notifyListeners();
  }

  // ── Forget Printer ─────────────────────────────────────
  Future<void> forgetPrinter() async {
    await disconnect();
    _savedAddress = null;
    _savedName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('printer_address');
    await prefs.remove('printer_name');
    notifyListeners();
  }

  // ── Check Connection ──────────────────────────────────
  Future<void> refreshConnection() async {
    _isConnected = await PrintBluetoothThermal.connectionStatus;
    notifyListeners();
  }

  // ── Print Receipt ──────────────────────────────────────
  Future<bool> printReceipt(OrderModel order, StoreInfoModel storeInfo) async {
    await refreshConnection();
    if (!_isConnected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.text(
        storeInfo.name,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text('');

      if (storeInfo.address.isNotEmpty) {
        bytes += generator.text(
          storeInfo.address,
          styles: const PosStyles(align: PosAlign.center),
        );
      }
      if (storeInfo.phone.isNotEmpty) {
        bytes += generator.text(
          'SĐT: ${storeInfo.phone}',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.hr(ch: '=');

      // Table & Date
      bytes += generator.text(
        'Ban: ${order.table}',
        styles: const PosStyles(bold: true),
      );
      bytes += generator.text(
        'Ngay: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(order.time) ?? DateTime.now())}',
      );
      bytes += generator.text(
        'Ma don: ${order.id}',
        styles: const PosStyles(fontType: PosFontType.fontB),
      );

      bytes += generator.hr(ch: '-');

      // Column headers
      bytes += generator.row([
        PosColumn(text: 'Mon', width: 6, styles: const PosStyles(bold: true)),
        PosColumn(
          text: 'SL',
          width: 2,
          styles: const PosStyles(bold: true, align: PosAlign.center),
        ),
        PosColumn(
          text: 'Gia',
          width: 4,
          styles: const PosStyles(bold: true, align: PosAlign.right),
        ),
      ]);
      bytes += generator.hr(ch: '-');

      // Items
      final formatter = NumberFormat('#,###', 'vi_VN');
      for (final item in order.items) {
        bytes += generator.row([
          PosColumn(text: item.name, width: 6),
          PosColumn(
            text: '${item.quantity}',
            width: 2,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(
            text: formatter.format(item.price * item.quantity),
            width: 4,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]);
        if (item.note.isNotEmpty) {
          bytes += generator.text(
            '  * ${item.note}',
            styles: const PosStyles(fontType: PosFontType.fontB),
          );
        }
      }

      bytes += generator.hr(ch: '-');

      // Total
      bytes += generator.row([
        PosColumn(
          text: 'TONG:',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: '${formatter.format(order.totalAmount)}d',
          width: 6,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
            height: PosTextSize.size2,
          ),
        ),
      ]);

      bytes += generator.hr(ch: '=');
      bytes += generator.text(
        'Cam on quy khach!',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text('');
      bytes += generator.cut();

      // Send to printer
      final result = await PrintBluetoothThermal.writeBytes(
        Uint8List.fromList(bytes),
      );
      return result;
    } catch (e) {
      debugPrint('[PrinterService] print error: $e');
      return false;
    }
  }

  // ── Print Test ─────────────────────────────────────────
  Future<bool> printTest() async {
    await refreshConnection();
    if (!_isConnected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm80, profile);
      List<int> bytes = [];

      bytes += generator.text(
        '=== IN THU ===',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.text('');
      bytes += generator.text(
        'Moimoi POS',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'May in hoat dong tot!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now()),
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.hr();
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      debugPrint('[PrinterService] testPrint error: $e');
      return false;
    }
  }
}
