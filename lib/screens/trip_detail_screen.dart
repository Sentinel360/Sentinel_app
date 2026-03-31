import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/trip_model.dart';
import '../services/trip_service.dart';

/// Trip details / report.
///
/// Important: this screen deliberately does NOT use `GoogleMap` or external map
/// URLs. It only shows trip data, safety analysis, an event timeline, and
/// feedback.
class TripDetailScreen extends StatefulWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final TripService _tripService = TripService();

  TripModel? _trip;
  List<Map<String, dynamic>> _sensorEvents = [];
  List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic> _riskSummary = {};
  bool _isLoading = true;
  String? _errorMessage;

  // Feedback state
  bool _feedbackSubmitted = false;
  bool? _existingFeedback;

  bool _themeIsDark = true;

  bool _miniMapReady = false;

  bool get _isDark => _themeIsDark;

  Color get _bg => _isDark ? const Color(0xFF050A14) : const Color(0xFFF8FAFC);
  Color get _surface => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _border =>
      _isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _textMuted =>
      _isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _loadTripData();
  }

  Future<void> _loadTripData() async {
    setState(() => _isLoading = true);

    try {
      final trip = await _tripService.getTripById(widget.tripId);
      if (!mounted) return;

      if (trip == null) {
        setState(() {
          _trip = null;
          _errorMessage = 'Trip not found';
          _isLoading = false;
        });
        return;
      }

      // Load additional data, but never let one query failure crash the page.
      List<Map<String, dynamic>> sensorEvents = [];
      try {
        final sensorSnap = await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .collection('sensor_data')
            .orderBy('timestamp', descending: false)
            .get();

        sensorEvents = sensorSnap.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      } catch (e) {
        debugPrint('trip_detail: sensor_data load failed: $e');
      }

      List<Map<String, dynamic>> alerts = [];
      try {
        final alertsSnap = await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .collection('alerts')
            .orderBy('timestamp', descending: false)
            .get();

        alerts = alertsSnap.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
      } catch (e) {
        debugPrint('trip_detail: alerts load failed: $e');
      }

      Map<String, dynamic> riskSummary = {};
      try {
        final riskDoc = await FirebaseFirestore.instance
            .collection('trips')
            .doc(widget.tripId)
            .collection('current_state')
            .doc('latest')
            .get();
        riskSummary = riskDoc.data() ?? {};
      } catch (e) {
        debugPrint('trip_detail: risk summary load failed: $e');
      }

      bool? existingFeedback;
      bool feedbackSubmitted = false;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final feedbackSnap = await FirebaseFirestore.instance
              .collection('trip_feedback')
              .where('tripId', isEqualTo: widget.tripId)
              .where('userId', isEqualTo: uid)
              .limit(1)
              .get();

          if (feedbackSnap.docs.isNotEmpty) {
            final raw = feedbackSnap.docs.first.data()['feltSafe'];
            existingFeedback = raw is bool ? raw : null;
            feedbackSubmitted = true;
          }
        } catch (e) {
          debugPrint('trip_detail: trip_feedback query failed: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _trip = trip;
        _sensorEvents = sensorEvents;
        _alerts = alerts;
        _riskSummary = riskSummary;
        _existingFeedback = existingFeedback;
        _feedbackSubmitted = feedbackSubmitted;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading trip: $e';
        _isLoading = false;
      });
    }
  }

  static String _formatGeo(GeoPoint p) =>
      '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';

  bool _validLatLng(double lat, double lng) {
    if (lat.isNaN || lng.isNaN) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  LatLng? _toLatLng(GeoPoint? p) {
    if (p == null) return null;
    final lat = p.latitude;
    final lng = p.longitude;
    if (!_validLatLng(lat, lng)) return null;
    return LatLng(lat, lng);
  }

  LatLng _routeCenter(LatLng a, LatLng? b) {
    if (b == null) return a;
    return LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
  }

  int _alertsWithGpsCount() {
    var n = 0;
    for (final a in _alerts) {
      final gps = a['gps'] as Map<String, dynamic>?;
      if (gps == null) continue;
      final lat = (gps['lat'] as num?)?.toDouble();
      final lon = (gps['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) n++;
    }
    return n;
  }

  void _copyCoords(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordinates copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getEventLabel(String eventType) {
    const labels = {
      'rapid_acceleration': 'Rapid Acceleration',
      'harsh_braking': 'Harsh Braking',
      'route_deviation': 'Route Deviation',
      'SOS_MANUAL': 'SOS Triggered',
      'high_risk': 'High Risk Detected',
      'speed_violation': 'Speed Violation',
    };
    return labels[eventType] ?? eventType;
  }

  String _getEventMeaning(String eventType) {
    const meanings = {
      'rapid_acceleration':
          'Sudden acceleration detected — may indicate aggressive driving',
      'harsh_braking':
          'Hard braking event — potential emergency stop or aggressive driving',
      'route_deviation':
          'Vehicle deviated from expected route — may indicate an unplanned detour',
      'SOS_MANUAL': 'Manual SOS triggered by passenger',
      'high_risk': 'ML model detected high-risk driving pattern',
      'speed_violation': 'Vehicle exceeded the speed limit for this road type',
    };
    return meanings[eventType] ?? eventType;
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
      case 'warning':
        return const Color(0xFFF59E0B);
      case 'low':
      default:
        return const Color(0xFF10B981);
    }
  }

  String _formatTime(dynamic timestamp) {
    final DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '--:--';
    }

    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Future<void> _submitFeedback(bool feltSafe) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('trip_feedback').add({
        'tripId': widget.tripId,
        'userId': uid,
        'feltSafe': feltSafe,
        'submittedAt': FieldValue.serverTimestamp(),
        'mlOverallRisk': _riskSummary['overallRiskLevel'] ?? 'unknown',
        'mlOverallUnsafe': _riskSummary['overallUnsafe'] ?? false,
        'mlRiskScore': _riskSummary['riskScore'] ?? 0.0,
      });

      if (!mounted) return;
      setState(() {
        _feedbackSubmitted = true;
        _existingFeedback = feltSafe;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you for your feedback!',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Feedback submit error: $e');
    }
  }

  Widget _buildHeader() {
    if (_trip == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(color: _border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip!.displayName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _trip!.dateFormatted,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _summaryItem(
                  icon: Icons.schedule,
                  label: 'Duration',
                  value: _trip!.durationFormatted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _summaryItem(
                  icon: Icons.location_on,
                  label: 'Distance',
                  value: '${_trip!.distance.toStringAsFixed(1)} km',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final statusLower = _trip!.status.toLowerCase();
    final isCompleted = statusLower == 'completed';
    final isEmergency = statusLower == 'emergency';

    final Color bgColor;
    final Color textColor;
    final String label;

    if (isCompleted) {
      bgColor = const Color(0xFF10B981).withValues(alpha: 0.15);
      textColor = const Color(0xFF10B981);
      label = 'Completed';
    } else if (isEmergency) {
      bgColor = const Color(0xFFEF4444).withValues(alpha: 0.15);
      textColor = const Color(0xFFEF4444);
      label = 'Emergency';
    } else {
      bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.15);
      textColor = const Color(0xFF3B82F6);
      label = 'Active';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor, width: 1),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  Widget _summaryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            _isDark ? const Color(0xFF0F172A).withValues(alpha: 0.7) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: _textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: _textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteOverview() {
    if (_trip == null) return const SizedBox.shrink();

    final t = _trip!;
    final points = t.routePolyline.length;
    final gpsEvents = _alertsWithGpsCount();
    final start = _toLatLng(t.startLocation);
    final end = _toLatLng(t.endLocation);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 22, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 8),
              Text(
                'Locations',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Latitude and longitude for this trip (tap copy to paste elsewhere).',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: _textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          _routeRow(
            icon: Icons.flag,
            iconColor: const Color(0xFF10B981),
            title: 'Start',
            subtitle: _formatGeo(t.startLocation),
          ),
          if (t.endLocation != null) ...[
            const SizedBox(height: 10),
            _routeRow(
              icon: Icons.flag_circle,
              iconColor: const Color(0xFFEF4444),
              title: 'End',
              subtitle: _formatGeo(t.endLocation!),
            ),
          ],
          if (start != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 210,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _routeCenter(start, end),
                    zoom: end != null ? 12 : 14,
                  ),
                  // Explicit markerType avoids the Android PlatformMarkerType NPE
                  // when plugin versions are >= 2.16 (Dart) and 2.19+ (Android).
                  markerType: GoogleMapMarkerType.marker,
                  liteModeEnabled: false,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  onMapCreated: (_) {
                    if (!_miniMapReady && mounted) {
                      setState(() => _miniMapReady = true);
                    }
                  },
                  markers: _miniMapReady
                      ? <Marker>{
                          Marker(
                            markerId: const MarkerId('trip_start'),
                            position: start,
                            infoWindow: const InfoWindow(title: 'Start'),
                          ),
                          if (end != null)
                            Marker(
                              markerId: const MarkerId('trip_end'),
                              position: end,
                              infoWindow: const InfoWindow(title: 'Destination'),
                            ),
                        }
                      : const <Marker>{},
                  polylines: (_miniMapReady && end != null)
                      ? <Polyline>{
                          Polyline(
                            polylineId: const PolylineId('trip_preview'),
                            points: <LatLng>[start, end],
                            color: const Color(0xFF3B82F6),
                            width: 4,
                          ),
                        }
                      : const <Polyline>{},
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Preview map (start → destination)',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                color: _textMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chipStat(
                Icons.timeline,
                '$points',
                points == 1 ? 'route point' : 'route points',
              ),
              _chipStat(
                Icons.place_outlined,
                '$gpsEvents',
                'alerts with GPS',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy coordinates',
          onPressed: () => _copyCoords(subtitle),
          icon: Icon(Icons.copy_outlined, size: 20, color: _textMuted),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
      ],
    );
  }

  Widget _chipStat(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _textSecondary),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: _textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskSummary() {
    if (_riskSummary.isEmpty) return const SizedBox.shrink();

    final policy = _riskSummary['policy'] as Map<String, dynamic>? ?? {};
    final overallRiskLevel = _riskSummary['overallRiskLevel'] as String? ?? 'SAFE';
    final overallUnsafe = _riskSummary['overallUnsafe'] as bool? ?? false;
    final totalWindows = (policy['totalWindows'] as num?)?.toInt() ?? 0;
    final highWindows = (policy['highWindows'] as num?)?.toInt() ?? 0;
    final highRatio = (policy['highRatio'] as num?)?.toDouble() ?? 0.0;
    final policyReason = policy['reason'] as String? ?? '';

    final Color riskColor = (overallRiskLevel.contains('HIGH') || overallUnsafe)
        ? const Color(0xFFEF4444)
        : overallRiskLevel == 'MEDIUM'
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: riskColor),
              const SizedBox(width: 8),
              Text(
                'Safety Analysis',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: riskColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overallUnsafe ? 'TRIP RATED UNSAFE' : 'Overall: $overallRiskLevel',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: riskColor,
                  ),
                ),
                if (policyReason.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    policyReason,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  'Analysis Windows',
                  totalWindows.toString(),
                  _textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  'High Risk Events',
                  highWindows.toString(),
                  highWindows > 0 ? const Color(0xFFEF4444) : _textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  'Risk Ratio',
                  '${(highRatio * 100).toStringAsFixed(1)}%',
                  highRatio > 0.2
                      ? const Color(0xFFEF4444)
                      : highRatio > 0.1
                          ? const Color(0xFFF59E0B)
                          : _textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: _textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  DateTime _toDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is int) return DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now();
  }

  Widget _buildEventsTimeline() {
    if (_trip == null) return const SizedBox.shrink();

    final allEvents = <Map<String, dynamic>>[];

    for (final anomaly in _trip!.anomalies) {
      allEvents.add({
        'type': 'anomaly',
        'eventType': anomaly.type,
        'timestamp': anomaly.detectedAt,
        'severity': anomaly.severity,
        'location': anomaly.location,
      });
    }

    for (final event in _sensorEvents) {
      if (event['type'] != null) {
        allEvents.add({
          'type': 'sensor',
          'eventType': event['type'],
          'timestamp': event['timestamp'],
          'severity': event['severity'] ?? 'low',
          'value': event['value'],
          'gps': event['gps'],
        });
      }
    }

    for (final alert in _alerts) {
      allEvents.add({
        'type': 'alert',
        'eventType': alert['type'] ?? 'alert',
        'timestamp': alert['timestamp'],
        'severity': alert['severity'] ?? 'warning',
        'message': alert['reason'] ?? alert['message'],
        'riskScore': alert['riskScore'],
        'gps': alert['gps'],
      });
    }

    allEvents.sort((a, b) {
      final timeA = _toDateTime(a['timestamp']);
      final timeB = _toDateTime(b['timestamp']);
      return timeA.compareTo(timeB);
    });

    if (allEvents.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 40,
              color: const Color(0xFF10B981).withValues(alpha: 0.6),
            ),
            const SizedBox(height: 12),
            Text(
              'No safety events recorded',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This trip completed without any detected incidents.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Icon(Icons.timeline, size: 20, color: _textPrimary),
              const SizedBox(width: 8),
              Text(
                'Event Timeline',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${allEvents.length} events',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...allEvents.asMap().entries.map((entry) {
          final index = entry.key;
          final event = entry.value;
          return _buildTimelineItem(event, index, allEvents.length);
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> event, int index, int total) {
    final severity = event['severity'] as String? ?? 'low';
    final eventType = event['eventType'] as String? ?? '';
    final timestamp = event['timestamp'];
    final meaning = _getEventMeaning(eventType);
    final severityColor = _getSeverityColor(severity);
    final riskScore = event['riskScore'];
    final message = event['message'] as String?;

    final gps = event['gps'] as Map<String, dynamic>?;
    String? gpsLine;
    if (gps != null) {
      final lat = (gps['lat'] as num?)?.toDouble();
      final lon = (gps['lon'] as num?)?.toDouble();
      if (lat != null && lon != null) {
        gpsLine = '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: severityColor,
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: severityColor.withValues(alpha: 0.3),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (index < total - 1)
                  Container(
                    width: 2,
                    height: 52,
                    color: _border,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: index < total - 1 ? 8 : 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getEventLabel(eventType),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: severityColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          severity.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: severityColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meaning,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                  if (message != null && message.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      message,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: _textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (gpsLine != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'GPS: $gpsLine',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: _textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 11, color: _textMuted),
                      const SizedBox(width: 4),
                      Text(
                        _formatTime(timestamp),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: _textMuted,
                        ),
                      ),
                      if (riskScore != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.speed, size: 11, color: _textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Risk: ${((riskScore as num).toDouble() * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: _textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection() {
    if (_trip == null || _trip!.status.toLowerCase() != 'completed') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(
            _feedbackSubmitted ? Icons.check_circle : Icons.feedback_outlined,
            size: 32,
            color: _feedbackSubmitted
                ? const Color(0xFF10B981)
                : const Color(0xFF3B82F6),
          ),
          const SizedBox(height: 12),
          Text(
            _feedbackSubmitted ? 'Thanks for your feedback!' : 'Did you feel safe during this ride?',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _feedbackSubmitted
                ? 'Your response helps us improve safety detection.'
                : 'Your honest feedback helps our AI learn and improve.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (_feedbackSubmitted)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _existingFeedback == true ? Icons.thumb_up : Icons.thumb_down,
                  size: 18,
                  color: _existingFeedback == true
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 8),
                Text(
                  _existingFeedback == true ? 'Felt safe' : 'Did not feel safe',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _existingFeedback == true
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitFeedback(true),
                    icon: const Icon(Icons.thumb_up_outlined, size: 18),
                    label: Text(
                      'Yes, felt safe',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _submitFeedback(false),
                    icon: const Icon(Icons.thumb_down_outlined, size: 18),
                    label: Text(
                      'No, unsafe',
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFEF4444)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _themeIsDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trip Report',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _border, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildRouteOverview(),
                      _buildRiskSummary(),
                      const SizedBox(height: 8),
                      _buildEventsTimeline(),
                      _buildFeedbackSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

