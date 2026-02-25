import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/trip_manager.dart';
import '../services/sensor_service.dart';
import '../services/ble_service.dart';
import '../services/route_service.dart'; // Import RouteService

// ── Ghana locations ───────────────────────────────────────────────────────────
const List<Map<String, dynamic>> kGhanaLocations = [
  {'name': 'Kotoka International Airport', 'lat': 5.6052, 'lon': -0.1668},
  {'name': 'Accra Mall', 'lat': 5.6361, 'lon': -0.1769},
  {'name': 'University of Ghana', 'lat': 5.6502, 'lon': -0.1870},
  {'name': 'Kwame Nkrumah Memorial Park', 'lat': 5.5501, 'lon': -0.2069},
  {'name': 'Labadi Beach', 'lat': 5.5571, 'lon': -0.1225},
  {'name': 'Osu Castle', 'lat': 5.5480, 'lon': -0.1733},
  {'name': 'Tema Station', 'lat': 5.5488, 'lon': -0.2095},
  {'name': 'East Legon', 'lat': 5.6360, 'lon': -0.1520},
  {'name': 'Cantonments', 'lat': 5.5758, 'lon': -0.1676},
  {'name': 'Labone', 'lat': 5.5812, 'lon': -0.1620},
  {'name': 'Spintex Road', 'lat': 5.6178, 'lon': -0.1196},
  {'name': 'Dansoman', 'lat': 5.5392, 'lon': -0.2532},
];

// ── Helpers: convert RiskUpdate string fields to Flutter types ────────────────
Color _riskToColor(String? riskColor) {
  switch (riskColor) {
    case 'orange':
      return const Color(0xFFF59E0B);
    case 'red':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF10B981); // green / null → safe
  }
}

bool _isHighRisk(String? riskLevel) => riskLevel == 'HIGH RISK';

// ── Screen phases ─────────────────────────────────────────────────────────────
enum _MapPhase { search, preview, active }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final RouteService _routeService = RouteService(); // Initialize RouteService
  GoogleMapController? _mapController;
  late AnimationController _panelController;
  late AnimationController _pulseController;
  late Animation<Offset> _panelSlide;
  late Animation<double> _pulseAnim;

  _MapPhase _screen = _MapPhase.search;
  List<Map<String, dynamic>> _suggestions = [];
  Map<String, dynamic>? _dest;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final LatLng _origin = const LatLng(5.6037, -0.1870); // Accra center

  ActiveTripState? _tripState;
  StreamSubscription<ActiveTripState>? _tripSub;

  @override
  void initState() {
    super.initState();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _panelSlide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic),
        );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _panelController.forward();

    _tripSub = TripManager().stateStream.listen((s) {
      if (mounted) setState(() => _tripState = s);
    });
    _tripState = TripManager().currentState;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    _panelController.dispose();
    _pulseController.dispose();
    _tripSub?.cancel();
    super.dispose();
  }

  // ── Search ────────────────────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final lower = q.toLowerCase();
    setState(() {
      _suggestions = kGhanaLocations
          .where((l) => (l['name'] as String).toLowerCase().contains(lower))
          .toList();
    });
  }

  void _selectDest(Map<String, dynamic> loc) {
    _searchController.text = loc['name'] as String;
    setState(() {
      _dest = loc;
      _suggestions = [];
      _screen = _MapPhase.preview;
    });
    _buildRoute(loc);
    FocusScope.of(context).unfocus();
  }

  // Updated _buildRoute to fetch real road points from RouteService
  Future<void> _buildRoute(Map<String, dynamic> dest) async {
    final dLatLng = LatLng(dest['lat'] as double, dest['lon'] as double);

    // Initial markers for origin and destination
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('origin'),
          position: _origin,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
        Marker(
          markerId: const MarkerId('dest'),
          position: dLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: dest['name'] as String),
        ),
      };
    });

    try {
      // Fetch actual road coordinates using Directions API through RouteService
      final routePoints = await _routeService.fetchRoute(
        startLat: _origin.latitude,
        startLng: _origin.longitude,
        endLat: dLatLng.latitude,
        endLng: dLatLng.longitude,
      );

      final polylinePoints = routePoints
          .map((gp) => LatLng(gp.latitude, gp.longitude))
          .toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: polylinePoints,
            color: const Color(0xFF3B82F6),
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });
    } catch (e) {
      debugPrint("Route fetching error: $e. Falling back to straight line.");
      // Fallback to a straight dash line if API fails
      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: [_origin, dLatLng],
            color: const Color(0xFF3B82F6).withOpacity(0.5),
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ),
        };
      });
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            math.min(_origin.latitude, dLatLng.latitude) - 0.01,
            math.min(_origin.longitude, dLatLng.longitude) - 0.01,
          ),
          northeast: LatLng(
            math.max(_origin.latitude, dLatLng.latitude) + 0.01,
            math.max(_origin.longitude, dLatLng.longitude) + 0.01,
          ),
        ),
        80,
      ),
    );
  }

  // ── Trip lifecycle ────────────────────────────────────────────────────────

  Future<void> _startTrip() async {
    if (_dest == null) return;
    final String? id = await TripManager().startTrip(
      originLat: _origin.latitude,
      originLon: _origin.longitude,
      destLat: _dest!['lat'] as double,
      destLon: _dest!['lon'] as double,
      destinationName: _dest!['name'] as String,
    );
    if (id != null && mounted) {
      setState(() => _screen = _MapPhase.active);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to start trip. Try again.')),
      );
    }
  }

  Future<void> _endTrip() async {
    await TripManager().endTrip();
    if (mounted) {
      setState(() {
        _screen = _MapPhase.search;
        _dest = null;
        _markers = {};
        _polylines = {};
        _searchController.clear();
      });
    }
  }

  Future<void> _triggerSOS() async {
    await TripManager().triggerSOS();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SOS triggered! Emergency contacts being notified.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark(context);
    final RiskUpdate? risk = _tripState?.latestRisk;
    final Color rc = _riskToColor(risk?.riskColor);

    // Update polyline colour live during active trip
    if (_screen == _MapPhase.active && risk != null && _polylines.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _polylines.first.points,
          color: rc,
          width: 5,
        ),
      };
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF050A14)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _origin, zoom: 13),
            onMapCreated: (c) {
              _mapController = c;
              if (isDark) c.setMapStyle(_kDarkMapStyle);
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // My location button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _mapBtn(
              icon: Icons.my_location_rounded,
              onTap: () => _mapController?.animateCamera(
                CameraUpdate.newLatLngZoom(_origin, 15),
              ),
              isDark: isDark,
            ),
          ),

          // Active header
          if (_screen == _MapPhase.active) _buildActiveHeader(isDark, risk, rc),

          // Sensor badge
          if (_screen != _MapPhase.search) _buildSensorBadge(isDark),

          // Bottom panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _panelSlide,
              child: _buildBottomPanel(isDark, risk, rc),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(isDark),
    );
  }

  // ── Active header ─────────────────────────────────────────────────────────

  Widget _buildActiveHeader(bool isDark, RiskUpdate? risk, Color rc) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          MediaQuery.of(context).padding.top + 12,
          16,
          12,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F172A).withOpacity(0.95)
              : Colors.white.withOpacity(0.95),
          border: Border(
            bottom: BorderSide(color: rc.withOpacity(0.4), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Transform.scale(
                scale: _isHighRisk(risk?.riskLevel) ? _pulseAnim.value : 1.0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: rc,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: rc.withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    risk?.riskLevel ?? 'SAFE',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: rc,
                    ),
                  ),
                  Text(
                    _dest?['name'] ?? 'Active Trip',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _triggerSOS,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Text(
                  'SOS',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sensor badge ──────────────────────────────────────────────────────────

  Widget _buildSensorBadge(bool isDark) {
    final bool ble = _tripState?.bleState == BLEConnectionState.connected;
    final String src = _tripState?.activeSource ?? 'PHONE';
    return Positioned(
      top: _screen == _MapPhase.active
          ? MediaQuery.of(context).padding.top + 80
          : MediaQuery.of(context).padding.top + 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withOpacity(0.9)
              : Colors.white.withOpacity(0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: ble
                ? const Color(0xFF8B5CF6).withOpacity(0.4)
                : const Color(0xFF334155).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              src == 'IOT' ? Icons.memory : Icons.smartphone,
              color: ble ? const Color(0xFF8B5CF6) : const Color(0xFF64748B),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              src == 'IOT' ? 'IoT Active' : 'Phone Sensors',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom panel ──────────────────────────────────────────────────────────

  Widget _buildBottomPanel(bool isDark, RiskUpdate? risk, Color rc) {
    final Color surf = isDark ? const Color(0xFF0F172A) : Colors.white;
    final Color bdr = isDark
        ? const Color(0xFF1E293B).withOpacity(0.8)
        : const Color(0xFFE2E8F0);
    final Color tp = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final Color ts = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: bdr, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          if (_screen == _MapPhase.search)
            _searchPanel(isDark, tp, ts, surf, bdr)
          else if (_screen == _MapPhase.preview)
            _previewPanel(isDark, tp, ts, surf, bdr)
          else
            _activePanel(isDark, risk, rc, tp, ts),
        ],
      ),
    );
  }

  // ── Search panel ──────────────────────────────────────────────────────────

  Widget _searchPanel(bool isDark, Color tp, Color ts, Color surf, Color bdr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where to?',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: tp,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: GoogleFonts.inter(color: tp, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search destination...',
              hintStyle: GoogleFonts.inter(color: ts, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: ts, size: 20),
              filled: true,
              fillColor: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.6)
                  : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: bdr),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: bdr),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF3B82F6),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          if (_suggestions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: bdr),
              ),
              child: Column(
                children: _suggestions
                    .take(5)
                    .map(
                      (loc) => ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF3B82F6),
                          size: 18,
                        ),
                        title: Text(
                          loc['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: tp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        dense: true,
                        onTap: () => _selectDest(loc),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Preview panel ─────────────────────────────────────────────────────────

  Widget _previewPanel(bool isDark, Color tp, Color ts, Color surf, Color bdr) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _screen = _MapPhase.search;
                  _markers = {};
                  _polylines = {};
                }),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.arrow_back_rounded, color: tp, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _dest?['name'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tp,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _routeRow(
            icon: Icons.my_location,
            color: const Color(0xFF3B82F6),
            label: 'Current Location',
            ts: ts,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 18),
            child: Container(
              height: 20,
              width: 1.5,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          _routeRow(
            icon: Icons.location_on,
            color: const Color(0xFFEF4444),
            label: _dest?['name'] ?? '',
            ts: ts,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _tripState?.phase == TripPhase.starting
                  ? null
                  : _startTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _tripState?.phase == TripPhase.starting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'Start Trip',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required IconData icon,
    required Color color,
    required String label,
    required Color ts,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: ts,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Active panel ──────────────────────────────────────────────────────────

  Widget _activePanel(
    bool isDark,
    RiskUpdate? risk,
    Color rc,
    Color tp,
    Color ts,
  ) {
    final elapsed = _tripState?.elapsed ?? Duration.zero;
    final riskLevel = risk?.riskLevel ?? 'SAFE';
    final riskScore = risk?.riskScore ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
          // Risk card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: rc.withOpacity(isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: rc.withOpacity(0.3), width: 1.5),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: Stack(
                    children: [
                      CircularProgressIndicator(
                        value: riskScore,
                        backgroundColor: rc.withOpacity(0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(rc),
                        strokeWidth: 5,
                      ),
                      Center(
                        child: Text(
                          '${(riskScore * 100).toInt()}',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: rc,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        riskLevel,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: rc,
                        ),
                      ),
                      if (risk?.explanation.isNotEmpty == true)
                        Text(
                          risk!.explanation,
                          style: GoogleFonts.inter(fontSize: 11, color: ts),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _statChip(
                  icon: Icons.timer_outlined,
                  value: _fmtDuration(elapsed),
                  label: 'Duration',
                  isDark: isDark,
                  tp: tp,
                  ts: ts,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statChip(
                  icon: Icons.sensors,
                  value: _tripState?.activeSource ?? 'PHONE',
                  label: 'Source',
                  isDark: isDark,
                  tp: tp,
                  ts: ts,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statChip(
                  icon: Icons.shield_outlined,
                  value: riskLevel,
                  label: 'Status',
                  isDark: isDark,
                  tp: tp,
                  ts: ts,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // End trip
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _tripState?.phase == TripPhase.ending
                  ? null
                  : _endTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                foregroundColor: const Color(0xFFEF4444),
                elevation: 0,
                side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _tripState?.phase == TripPhase.ending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Color(0xFFEF4444),
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      'End Trip',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
    required Color tp,
    required Color ts,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.6)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withOpacity(0.5)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: ts, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tp,
            ),
          ),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: ts)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  Widget _mapBtn({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
          size: 20,
        ),
      ),
    );
  }

  // ── Nav bar ───────────────────────────────────────────────────────────────

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
                Icons.home_outlined,
                Icons.home,
                'Home',
                false,
                isDark,
                () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              _navItem(
                Icons.explore_outlined,
                Icons.explore,
                'Map',
                true,
                isDark,
                () {},
              ),
              _navItem(
                Icons.router_outlined,
                Icons.router,
                'Device',
                false,
                isDark,
                () => Navigator.pushNamed(context, '/device'),
                color: const Color(0xFF8B5CF6),
              ),
              _navItem(
                Icons.emergency_outlined,
                Icons.emergency,
                'SOS',
                false,
                isDark,
                () => Navigator.pushNamed(context, '/emergency'),
                color: const Color(0xFFEF4444),
              ),
              _navItem(
                Icons.person_outline,
                Icons.person,
                'Profile',
                false,
                isDark,
                () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    IconData activeIcon,
    String label,
    bool isActive,
    bool isDark,
    VoidCallback onTap, {
    Color? color,
  }) {
    final Color c =
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
          color: isActive ? c.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: c, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dark map style ────────────────────────────────────────────────────────────
const String _kDarkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#0f172a"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#0f172a"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#64748b"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#0f172a"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#334155"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0a1628"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#1e293b"}]}
]
''';
