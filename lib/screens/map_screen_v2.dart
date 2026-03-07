import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/trip_manager.dart';
import '../services/sensor_service.dart';
import '../services/ble_service.dart';
import '../services/route_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────
Color _riskToColor(String? riskColor) {
  switch (riskColor) {
    case 'orange':
      return const Color(0xFFF59E0B);
    case 'red':
      return const Color(0xFFEF4444);
    default:
      return const Color(0xFF10B981);
  }
}

bool _isHighRisk(String? riskLevel) =>
    riskLevel == 'HIGH RISK' || riskLevel == 'HIGH';

const LatLng _kAccraCenter = LatLng(5.6037, -0.1870);

// ── Places suggestion model ───────────────────────────────────────────────────
class _PlaceSuggestion {
  final String placeId;
  final String mainText;
  final String secondaryText;

  _PlaceSuggestion({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
}

enum _MapPhase { search, preview, active }

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final RouteService _routeService = RouteService();
  GoogleMapController? _mapController;
  late AnimationController _panelController;
  late AnimationController _pulseController;
  late Animation<Offset> _panelSlide;
  late Animation<double> _pulseAnim;

  _MapPhase _screen = _MapPhase.search;

  // Places autocomplete
  List<_PlaceSuggestion> _suggestions = [];
  bool _suggestionsLoading = false;
  Timer? _debounce;

  // Selected destination
  String? _destName;
  LatLng? _destLatLng;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Real user location
  LatLng? _userLocation;
  bool _locationLoading = true;
  bool _hasLocationPermission = false;
  StreamSubscription<Position>? _locationSub;

  ActiveTripState? _tripState;
  StreamSubscription<ActiveTripState>? _tripSub;

  LatLng get _origin => _userLocation ?? _kAccraCenter;
  // Web Services key (Places REST). Keep Maps SDK key in AndroidManifest via MAPS_API_KEY.
  String get _placesKey => dotenv.env['GOOGLE_MAPS_WEB_API_KEY'] ??
      dotenv.env['GOOGLE_PLACES_API_KEY'] ??
      dotenv.env['GOOGLE_MAPS_API_KEY'] ??
      '';

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

    _initLocation();
  }

  // ── Location ──────────────────────────────────────────────────────────────

  Future<void> _initLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _hasLocationPermission = false;
          });
        }
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locationLoading = false;
            _hasLocationPermission = false;
          });
        }
        return;
      }

      // For Maps "my location" layer, allow either whileInUse or always.
      final granted = perm == LocationPermission.whileInUse ||
          perm == LocationPermission.always;

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _locationLoading = false;
          _hasLocationPermission = granted;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_userLocation!, 15),
        );
      }

      _locationSub =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen((Position p) {
            if (mounted) {
              setState(() => _userLocation = LatLng(p.latitude, p.longitude));
            }
          });
    } catch (e) {
      debugPrint('MapScreen: location error - $e');
      if (mounted) {
        setState(() {
          _locationLoading = false;
          _hasLocationPermission = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController?.dispose();
    _panelController.dispose();
    _pulseController.dispose();
    _tripSub?.cancel();
    _locationSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Places Autocomplete ───────────────────────────────────────────────────

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    // Debounce: wait 400ms after user stops typing before calling API
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(q);
    });
  }

  Future<void> _fetchSuggestions(String input) async {
    if (_placesKey.isEmpty) {
      debugPrint('MapScreen: no API key for Places');
      return;
    }

    setState(() => _suggestionsLoading = true);

    try {
      // Bias results toward Ghana using location + radius
      final origin = _origin;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(input)}'
        '&location=${origin.latitude},${origin.longitude}'
        '&radius=50000' // 50km bias radius around user
        '&components=country:gh' // restrict to Ghana
        '&key=$_placesKey',
      );

      final response = await http.get(url);
      if (!mounted) return;

      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final predictions = data['predictions'] as List;
        setState(() {
          _suggestions = predictions.map((p) {
            final structured = p['structured_formatting'];
            return _PlaceSuggestion(
              placeId: p['place_id'] as String,
              mainText: structured['main_text'] as String,
              secondaryText: (structured['secondary_text'] ?? '') as String,
            );
          }).toList();
          _suggestionsLoading = false;
        });
      } else {
        debugPrint(
          'Places API: ${data['status']}'
          '${data['error_message'] != null ? ' — ${data['error_message']}' : ''}',
        );
        setState(() {
          _suggestions = [];
          _suggestionsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Places autocomplete error: $e');
      if (mounted)
        setState(() {
          _suggestions = [];
          _suggestionsLoading = false;
        });
    }
  }

  Future<void> _selectSuggestion(_PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    _searchController.text = suggestion.mainText;
    setState(() {
      _suggestions = [];
    });

    // Resolve place_id → lat/lng using Place Details API
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${suggestion.placeId}'
        '&fields=geometry,name'
        '&key=$_placesKey',
      );
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final loc = data['result']['geometry']['location'];
        final latLng = LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        );
        final name = data['result']['name'] as String;

        setState(() {
          _destName = name;
          _destLatLng = latLng;
          _screen = _MapPhase.preview;
        });
        _buildRoute(latLng, name);
      }
    } catch (e) {
      debugPrint('Place details error: $e');
    }
  }

  // ── Route building ────────────────────────────────────────────────────────

  Future<void> _buildRoute(LatLng dest, String destName) async {
    final origin = _origin;

    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('origin'),
          position: origin,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'You are here'),
        ),
        Marker(
          markerId: const MarkerId('dest'),
          position: dest,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: destName),
        ),
      };
      // Dashed placeholder while API call is in flight
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [origin, dest],
          color: const Color(0xFF3B82F6).withOpacity(0.4),
          width: 4,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    });

    _fitCamera(origin, dest);

    try {
      final routePoints = await _routeService.fetchRoute(
        startLat: origin.latitude,
        startLng: origin.longitude,
        endLat: dest.latitude,
        endLng: dest.longitude,
      );

      if (!mounted) return;

      final pts = routePoints
          .map((gp) => LatLng(gp.latitude, gp.longitude))
          .toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: pts,
            color: const Color(0xFF3B82F6),
            width: 5,
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
        };
      });

      if (pts.length > 1) _fitCameraToPolyline(pts);
    } catch (e) {
      debugPrint('Route error: $e — keeping straight-line fallback');
    }
  }

  void _fitCamera(LatLng a, LatLng b) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            math.min(a.latitude, b.latitude) - 0.01,
            math.min(a.longitude, b.longitude) - 0.01,
          ),
          northeast: LatLng(
            math.max(a.latitude, b.latitude) + 0.01,
            math.max(a.longitude, b.longitude) + 0.01,
          ),
        ),
        80,
      ),
    );
  }

  void _fitCameraToPolyline(List<LatLng> pts) {
    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.005, minLng - 0.005),
          northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        60,
      ),
    );
  }

  // ── Trip lifecycle ────────────────────────────────────────────────────────

  Future<void> _startTrip() async {
    if (_destLatLng == null || _destName == null) return;
    final String? id = await TripManager().startTrip(
      originLat: _origin.latitude,
      originLon: _origin.longitude,
      destLat: _destLatLng!.latitude,
      destLon: _destLatLng!.longitude,
      destinationName: _destName!,
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
        _destName = null;
        _destLatLng = null;
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

    if (_screen == _MapPhase.active && risk != null && _polylines.isNotEmpty) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: _polylines.first.points,
          color: rc,
          width: 5,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      };
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF050A14)
          : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _kAccraCenter,
              zoom: 13,
            ),
            style: isDark ? _kDarkMapStyle : null,
            onMapCreated: (c) {
              _mapController = c;
              if (_userLocation != null) {
                c.animateCamera(CameraUpdate.newLatLngZoom(_userLocation!, 15));
              }
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: _hasLocationPermission,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),

          // GPS loading indicator
          if (_locationLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Getting your location...',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // My location button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _mapBtn(
              icon: Icons.my_location_rounded,
              onTap: () {
                if (_userLocation != null) {
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(_userLocation!, 16),
                  );
                }
              },
              isDark: isDark,
            ),
          ),

          if (_screen == _MapPhase.active) _buildActiveHeader(isDark, risk, rc),

          if (_screen != _MapPhase.search) _buildSensorBadge(isDark),

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
    final instantLevel = risk?.riskLevel ?? 'SAFE';
    final overallUnsafe = risk?.overallUnsafe == true;
    final headerLevel = overallUnsafe
        ? '${risk?.overallRiskLevel ?? instantLevel} (Trip Unsafe)'
        : instantLevel;
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
                scale: (_isHighRisk(risk?.riskLevel) || overallUnsafe)
                    ? _pulseAnim.value
                    : 1.0,
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
                    headerLevel,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: rc,
                    ),
                  ),
                  Text(
                    _destName ?? 'Active Trip',
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
            _previewPanel(isDark, tp, ts)
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
              hintText: 'Search any location in Ghana...',
              hintStyle: GoogleFonts.inter(color: ts, fontSize: 14),
              prefixIcon: Icon(Icons.search, color: ts, size: 20),
              suffixIcon: _suggestionsLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    )
                  : null,
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
                      (s) => ListTile(
                        leading: const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF3B82F6),
                          size: 18,
                        ),
                        title: Text(
                          s.mainText,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: tp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: s.secondaryText.isNotEmpty
                            ? Text(
                                s.secondaryText,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: ts,
                                ),
                              )
                            : null,
                        dense: true,
                        onTap: () => _selectSuggestion(s),
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

  Widget _previewPanel(bool isDark, Color tp, Color ts) {
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
                  _destName = null;
                  _destLatLng = null;
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
                  _destName ?? '',
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
            label: 'Your current location',
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
            label: _destName ?? '',
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
    final overallRiskLevel = risk?.overallRiskLevel ?? riskLevel;
    final overallUnsafe = risk?.overallUnsafe ?? false;
    final riskScore = risk?.riskScore ?? 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        children: [
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
                      if (risk?.policyReason.isNotEmpty == true)
                        Text(
                          risk!.policyReason,
                          style: GoogleFonts.inter(fontSize: 11, color: ts),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                  value: overallUnsafe
                      ? '$overallRiskLevel (UNSAFE)'
                      : overallRiskLevel,
                  label: 'Status',
                  isDark: isDark,
                  tp: tp,
                  ts: ts,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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

const String _kDarkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#0b1220"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#0b1220"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#b8c5d6"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#dbe7f5"}]},
  {"featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#172338"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#d7e5f6"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#1b2a42"}]},
  {"featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#0b1220"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c4668"}]},
  {"featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#1a2940"}]},
  {"featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [{"color": "#cfe0f5"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0a2340"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#9dc4ea"}]}
]
''';
