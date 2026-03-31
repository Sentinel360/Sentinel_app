import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/device_service.dart';
import '../services/ble_service.dart';
import '../models/device_model.dart';
import 'dart:math' as math;

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen>
    with TickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _deviceIdController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _glowController;
  bool _isPairing = false;
  bool _bleActionBusy = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _deviceIdController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _pairDevice() async {
    if (_deviceIdController.text.trim().isEmpty ||
        _deviceNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill in all fields',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _isPairing = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _deviceService.registerDevice(
        deviceId: _deviceIdController.text.trim(),
        userId: uid,
        name: _deviceNameController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Device paired successfully!',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to pair device: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  void _showPairingDialog() {
    _deviceIdController.clear();
    _deviceNameController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Pair New Device',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFF1F5F9),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the Device ID printed on your Sentinel IoT device',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),

              // Device ID field
              Text(
                'Device ID',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _deviceIdController,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF1F5F9),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. SEN360-001234',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF475569),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.qr_code,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Device name field
              Text(
                'Device Name',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _deviceNameController,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF1F5F9),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. My Sentinel Device',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF475569),
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.label_outline,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isPairing ? null : _pairDevice,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isPairing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          'Pair Device',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _unpairDevice(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unpair Device',
          style: GoogleFonts.inter(
            color: const Color(0xFFF1F5F9),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Are you sure you want to unpair this device?',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF64748B)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Unpair',
              style: GoogleFonts.inter(
                color: const Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await BLEService().disconnect();
      await _deviceService.setDeviceActive(deviceId: deviceId, isActive: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Device unpaired',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF64748B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF050A14) : const Color(0xFFF1F5F9);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Stack(
        children: [
          AnimatedBackground(isDark: isDark),
          SafeArea(
            child: StreamBuilder<DeviceModel?>(
              stream: _deviceService.streamDeviceByUserId(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                  );
                }
                final device = snapshot.data;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Text(
                            'Device',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const Spacer(),
                          if (device == null)
                            GestureDetector(
                              onTap: _showPairingDialog,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      color: Color(0xFF8B5CF6),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Register hub',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF8B5CF6),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: StreamBuilder<BLEConnectionState>(
                        stream: BLEService().stateStream,
                        initialData: BLEService().state,
                        builder: (context, bleSnap) {
                          final ble = bleSnap.data ?? BLEConnectionState.disconnected;
                          final bleOn =
                              ble == BLEConnectionState.connected ||
                              ble == BLEConnectionState.mockConnected;
                          if (device != null) {
                            return _buildDeviceInfo(context, device, isDark);
                          }
                          if (bleOn) {
                            return _buildWearableLinkedState(context, isDark);
                          }
                          return _buildEmptyState(context, isDark);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textMuted = const Color(0xFF64748B);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  const Color(0xFF7C3AED).withValues(alpha: 0.1),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.bluetooth_searching,
              size: 56,
              color: Color(0xFF8B5CF6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Link your wearable',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use Bluetooth below to connect your Sentinel360 wearable.\n'
            'Optional: register a hub device ID in the cloud with “Register hub”.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _buildBleWearableCard(context, isDark),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _showPairingDialog,
            icon: const Icon(Icons.cloud_outlined, color: Color(0xFF8B5CF6), size: 20),
            label: Text(
              'Register hub device (optional)',
              style: GoogleFonts.inter(
                color: const Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWearableLinkedState(BuildContext context, bool isDark) {
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textMuted = const Color(0xFF64748B);
    final name = BLEService().connectedPeripheralName ?? 'Sentinel360';
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.18),
                  const Color(0xFF059669).withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.bluetooth_connected,
                        color: Color(0xFF10B981),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wearable connected',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _statusRow(
                  icon: Icons.link,
                  label: 'Connection',
                  value: 'Bluetooth LE • Active',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                _statusRow(
                  icon: Icons.battery_std,
                  label: 'Battery',
                  value: 'Not reported by device yet',
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                Text(
                  'Long-press SOS on the wearable sends the same emergency alert as the app. Status is saved to your account.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildBleWearableCard(context, isDark),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: _showPairingDialog,
              icon: Icon(
                Icons.cloud_outlined,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                size: 20,
              ),
              label: Text(
                'Also register a hub device (optional)',
                style: GoogleFonts.inter(
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.inter(fontSize: 13, color: textSecondary, height: 1.35),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _connectWearableBle() async {
    setState(() => _bleActionBusy = true);
    try {
      final ok = await BLEService().connect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Wearable connected. IoT SOS works while Bluetooth is on.'
                : 'No Sentinel360 device found. Power the wearable and try again.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _bleActionBusy = false);
    }
  }

  Future<void> _disconnectWearableBle() async {
    setState(() => _bleActionBusy = true);
    try {
      await BLEService().disconnect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Wearable disconnected',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      if (mounted) setState(() => _bleActionBusy = false);
    }
  }

  String _bleStatusLabel(BLEConnectionState s) {
    switch (s) {
      case BLEConnectionState.connected:
      case BLEConnectionState.mockConnected:
        return 'Connected';
      case BLEConnectionState.scanning:
        return 'Scanning…';
      case BLEConnectionState.connecting:
        return 'Connecting…';
      case BLEConnectionState.disconnected:
        return 'Not connected';
    }
  }

  Widget _buildBleWearableCard(BuildContext context, bool isDark) {
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final cardTop = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBottom = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    return StreamBuilder<BLEConnectionState>(
      stream: BLEService().stateStream,
      initialData: BLEService().state,
      builder: (context, snapshot) {
        final ble = snapshot.data ?? BLEConnectionState.disconnected;
        final connected =
            ble == BLEConnectionState.connected ||
            ble == BLEConnectionState.mockConnected;
        final busy = ble == BLEConnectionState.scanning ||
            ble == BLEConnectionState.connecting ||
            _bleActionBusy;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                cardTop.withValues(alpha: isDark ? 0.95 : 1),
                cardBottom.withValues(alpha: isDark ? 0.85 : 1),
              ],
            ),
            border: Border.all(
              color: (connected ? const Color(0xFF10B981) : const Color(0xFF64748B))
                  .withValues(alpha: 0.45),
              width: 1,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bluetooth_connected,
                    color: connected
                        ? const Color(0xFF10B981)
                        : const Color(0xFF94A3B8),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Wearable (Bluetooth)',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (connected
                              ? const Color(0xFF10B981)
                              : const Color(0xFF475569))
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _bleStatusLabel(ble),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: connected
                            ? const Color(0xFF10B981)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Connect your Sentinel360 wearable here. When linked, a long-press SOS on the device triggers the same emergency alerts as the app (no trip required).',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.45,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: busy ? null : _connectWearableBle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.link, size: 18),
                      label: Text(
                        'Connect',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: (!connected || busy) ? null : _disconnectWearableBle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textPrimary,
                        side: BorderSide(
                          color: const Color(0xFF475569).withValues(alpha: 0.65),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.link_off, size: 18),
                      label: Text(
                        'Disconnect',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceInfo(BuildContext context, DeviceModel device, bool isDark) {
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final isOnline = device.isActive;
    final statusColor = isOnline
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final batteryColor = device.batteryLevel > 20
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main device card
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color: statusColor.withOpacity(
                              0.2 + _glowController.value * 0.15,
                            ),
                            blurRadius: 20 + _glowController.value * 10,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E293B).withOpacity(0.8),
                        const Color(0xFF0F172A).withOpacity(0.6),
                      ],
                    ),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Device header row
                      Row(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  statusColor.withOpacity(0.2),
                                  statusColor.withOpacity(0.1),
                                ],
                              ),
                            ),
                            child: Icon(
                              Icons.router,
                              color: statusColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseController,
                                      builder: (context, child) => Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                          boxShadow: isOnline
                                              ? [
                                                  BoxShadow(
                                                    color: statusColor
                                                        .withOpacity(
                                                          0.5 +
                                                              _pulseController
                                                                      .value *
                                                                  0.3,
                                                        ),
                                                    blurRadius: 8,
                                                    spreadRadius: 1,
                                                  ),
                                                ]
                                              : [],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isOnline ? 'Online' : 'Offline',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: device.isActive,
                            activeColor: const Color(0xFF10B981),
                            onChanged: (value) async {
                              await _deviceService.setDeviceActive(
                                deviceId: device.deviceId,
                                isActive: value,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              const Color(0xFF334155).withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Battery
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: batteryColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.battery_charging_full,
                                  color: batteryColor,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Battery',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${device.batteryLevel}%',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: batteryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: device.batteryLevel / 100,
                          minHeight: 10,
                          backgroundColor: const Color(
                            0xFF1E293B,
                          ).withOpacity(0.6),
                          valueColor: AlwaysStoppedAnimation(batteryColor),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Info cards
                      Row(
                        children: [
                          Expanded(
                            child: _infoCard(
                              icon: Icons.memory,
                              label: 'Firmware',
                              value: 'v${device.firmwareVersion}',
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _infoCard(
                              icon: Icons.access_time,
                              label: 'Last Seen',
                              value: _formatLastSeen(device.lastSeen),
                              color: const Color(0xFF8B5CF6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          _buildBleWearableCard(context, isDark),
          const SizedBox(height: 24),

          Text(
            'Device Actions',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.sync,
            label: 'Sync Device',
            color: const Color(0xFF3B82F6),
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _actionButton(
            icon: Icons.link_off,
            label: 'Unpair Device',
            color: const Color(0xFFEF4444),
            onTap: () => _unpairDevice(device.deviceId),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          ),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF1F5F9),
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: color.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildNavBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF1E293B).withOpacity(0.5)
                : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: 'Home',
                isActive: false,
                isDark: isDark,
                onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              _navItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Map',
                isActive: false,
                isDark: isDark,
                onTap: () => Navigator.pushReplacementNamed(context, '/map'),
              ),
              _navItem(
                icon: Icons.router_outlined,
                activeIcon: Icons.router,
                label: 'Device',
                isActive: true,
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
                onTap: () {},
              ),
              _navItem(
                icon: Icons.emergency_outlined,
                activeIcon: Icons.emergency,
                label: 'SOS',
                isActive: false,
                color: const Color(0xFFEF4444),
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/emergency'),
              ),
              _navItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: false,
                isDark: isDark,
                onTap: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required bool isDark,
    Color? color,
    required VoidCallback onTap,
  }) {
    final itemColor =
        color ??
        (isActive
            ? const Color(0xFF3B82F6)
            : isDark
            ? const Color(0xFF64748B)
            : const Color(0xFF94A3B8));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? itemColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: itemColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Animated Background
class AnimatedBackground extends StatefulWidget {
  final bool isDark;
  const AnimatedBackground({super.key, required this.isDark});
  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => CustomPaint(
        size: Size.infinite,
        painter: BackgroundPainter(_controller.value, widget.isDark),
      ),
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;
  BackgroundPainter(this.animationValue, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF050A14), Color(0xFF0A1628), Color(0xFF050A14)]
              : const [Color(0xFFF8FAFC), Color(0xFFF5F3FF), Color(0xFFF8FAFC)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    final orbs = [
      {
        'x': size.width * 0.2,
        'y': size.height * 0.15 + math.sin(animationValue * 2 * math.pi) * 30,
        'radius': 100.0,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'x': size.width * 0.8,
        'y': size.height * 0.7 + math.cos(animationValue * 2 * math.pi) * 40,
        'radius': 120.0,
        'color': const Color(0xFF7C3AED),
      },
    ];
    for (var orb in orbs) {
      paint.shader =
          RadialGradient(
            colors: [
              (orb['color'] as Color).withOpacity(0.15),
              (orb['color'] as Color).withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(orb['x'] as double, orb['y'] as double),
              radius: orb['radius'] as double,
            ),
          );
      canvas.drawCircle(
        Offset(orb['x'] as double, orb['y'] as double),
        orb['radius'] as double,
        paint,
      );
    }
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1))
          .withOpacity(isDark ? 0.3 : 0.4)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(BackgroundPainter old) =>
      animationValue != old.animationValue;
}
