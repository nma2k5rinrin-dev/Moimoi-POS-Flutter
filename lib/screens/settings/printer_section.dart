import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../services/printer_service.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';

class PrinterSection extends StatefulWidget {
  const PrinterSection({super.key});

  @override
  State<PrinterSection> createState() => _PrinterSectionState();
}

class _PrinterSectionState extends State<PrinterSection> {
  final _printer = PrinterService();
  bool _isTestPrinting = false;

  @override
  void initState() {
    super.initState();
    _printer.init();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _printer,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),

                      // ── Status Card ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 72, height: 72,
                              decoration: BoxDecoration(
                                color: _printer.isConnected ? AppColors.emerald50 : AppColors.slate100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _printer.isConnected ? Icons.print_rounded : Icons.print_disabled_rounded,
                                size: 36,
                                color: _printer.isConnected ? AppColors.emerald500 : AppColors.slate400,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _printer.isConnected ? 'Đã kết nối' : 'Chưa kết nối',
                              style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700,
                                color: _printer.isConnected ? AppColors.emerald600 : AppColors.slate800,
                              ),
                            ),
                            if (_printer.savedName != null) ...[
                              const SizedBox(height: 4),
                              Text(_printer.savedName!,
                                  style: const TextStyle(fontSize: 14, color: AppColors.slate500, fontWeight: FontWeight.w600)),
                            ],
                            const SizedBox(height: 16),
                            if (_printer.isConnected) ...[
                              // Connected actions
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.receipt_long_rounded,
                                      label: 'In thử',
                                      color: AppColors.emerald500,
                                      isLoading: _isTestPrinting,
                                      onTap: () async {
                                        setState(() => _isTestPrinting = true);
                                        final ok = await _printer.printTest();
                                        setState(() => _isTestPrinting = false);
                                        if (context.mounted) {
                                          final store = context.read<AppStore>();
                                          store.showToast(
                                            ok ? 'Đã gửi lệnh in thử' : 'In thử thất bại',
                                            ok ? 'success' : 'error',
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildActionButton(
                                      icon: Icons.link_off_rounded,
                                      label: 'Ngắt kết nối',
                                      color: AppColors.red500,
                                      onTap: () => _printer.disconnect(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: _buildActionButton(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Quên máy in này',
                                  color: AppColors.slate500,
                                  outlined: true,
                                  onTap: () => _printer.forgetPrinter(),
                                ),
                              ),
                            ] else ...[
                              // Not connected — scan button
                              SizedBox(
                                width: double.infinity,
                                child: _buildActionButton(
                                  icon: Icons.bluetooth_searching_rounded,
                                  label: _printer.isScanning ? 'Đang tìm...' : 'Tìm máy in',
                                  color: AppColors.blue500,
                                  isLoading: _printer.isScanning,
                                  onTap: _printer.isScanning ? null : () => _printer.scanDevices(),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Device List ──
                      if (_printer.devices.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 4, bottom: 8),
                          child: Text('Thiết bị Bluetooth',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.slate200),
                          ),
                          child: Column(
                            children: _printer.devices.asMap().entries.map((entry) {
                              final i = entry.key;
                              final device = entry.value;
                              final isCurrentPrinter = device.macAdress == _printer.savedAddress;
                              return Column(
                                children: [
                                  if (i > 0) Divider(height: 1, color: AppColors.slate100),
                                  _buildDeviceTile(device, isCurrentPrinter),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDeviceTile(BluetoothInfo device, bool isCurrentPrinter) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: isCurrentPrinter ? AppColors.emerald50 : AppColors.blue50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.print_rounded, size: 22,
            color: isCurrentPrinter ? AppColors.emerald500 : AppColors.blue500),
      ),
      title: Text(device.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
      subtitle: Text(device.macAdress,
          style: const TextStyle(fontSize: 11, color: AppColors.slate400)),
      trailing: isCurrentPrinter && _printer.isConnected
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: AppColors.emerald50, borderRadius: BorderRadius.circular(8)),
              child: const Text('Đã kết nối',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.emerald600)),
            )
          : GestureDetector(
              onTap: () async {
                final store = context.read<AppStore>();
                store.showToast('Đang kết nối ${device.name}...', 'info');
                final ok = await _printer.connect(device.macAdress, name: device.name);
                if (context.mounted) {
                  store.showToast(
                    ok ? 'Kết nối thành công!' : 'Kết nối thất bại',
                    ok ? 'success' : 'error',
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.blue500,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Kết nối',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
    bool outlined = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: color.withValues(alpha: 0.4)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2,
                    color: outlined ? color : Colors.white),
              )
            else
              Icon(icon, size: 20, color: outlined ? color : Colors.white),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: outlined ? color : Colors.white)),
          ],
        ),
      ),
    );
  }
}
