import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/trip_service.dart';
import '../models/trip_model.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  late TripService _tripService;
  final ScrollController _scrollController = ScrollController();
  final List<TripModel> _trips = [];
  bool _isLoading = false;
  bool _hasMoreTrips = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tripService = TripService();
    _initializeTrips();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeTrips() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      final trips = await _tripService.getAllTrips(user.uid);
      setState(() {
        _trips.clear();
        _trips.addAll(trips);
        _isLoading = false;
        _hasMoreTrips = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load trips: $e';
        _isLoading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMoreTrips) {
        _loadMoreTrips();
      }
    }
  }

  Future<void> _loadMoreTrips() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final newTrips = await _tripService.getAllTrips(user.uid);

      setState(() {
        if (newTrips.length <= _trips.length) {
          _hasMoreTrips = false;
        } else {
          _trips.addAll(newTrips.skip(_trips.length));
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get _bgColor => _isDark ? const Color(0xFF050A14) : Colors.white;
  Color get _surfaceColor =>
      _isDark ? const Color(0xFF0F172A) : Colors.grey.shade50;
  Color get _borderColor =>
      _isDark ? const Color(0xFF1E293B) : Colors.grey.shade200;
  Color get _accentBlue => const Color(0xFF3B82F6);
  Color get _greenSuccess => const Color(0xFF10B981);
  Color get _orangeWarning => const Color(0xFFF59E0B);
  Color get _redError => const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: _isDark ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Trip History',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: _isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: _borderColor,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    if (_isLoading && _trips.isEmpty) {
      return _buildLoadingState();
    }

    if (_trips.isEmpty) {
      return _buildEmptyState();
    }

    return _buildTripsListView();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: _accentBlue,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading your trips...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.directions_car_outlined,
                size: 40,
                color: _accentBlue.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Trips Yet',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your trip history will appear here once you start a journey.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _redError.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.error_outline,
                size: 40,
                color: _redError,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Error Loading Trips',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'An unexpected error occurred',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _initializeTrips,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  color: _accentBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Retry',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripsListView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _trips.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _trips.length) {
          return _buildLoadingIndicator();
        }

        final trip = _trips[index];
        return _buildTripCard(trip);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: CircularProgressIndicator(
          color: _accentBlue,
        ),
      ),
    );
  }

  Widget _buildTripCard(TripModel trip) {
    final statusLower = trip.status.toLowerCase();
    final isCompleted = statusLower == 'completed';
    final isActive = statusLower == 'active';

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/trip_detail',
          arguments: trip.tripId,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _borderColor,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.displayName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color:
                                    _isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              trip.dateFormatted,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusBadge(isCompleted, isActive),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTripDetail(
                          Icons.schedule,
                          'Duration',
                          trip.durationFormatted,
                        ),
                      ),
                      Expanded(
                        child: _buildTripDetail(
                          Icons.place_outlined,
                          'Distance',
                          '${trip.distance?.toStringAsFixed(1) ?? "0.0"} km',
                        ),
                      ),
                    ],
                  ),
                  if (trip.anomalyCount > 0) ...[
                    const SizedBox(height: 12),
                    _buildAnomalyWarning(trip.anomalyCount),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isCompleted, bool isActive) {
    Color badgeBgColor;
    Color badgeTextColor;
    IconData badgeIcon;
    String badgeText;

    if (isCompleted) {
      badgeBgColor = _greenSuccess.withOpacity(0.15);
      badgeTextColor = _greenSuccess;
      badgeIcon = Icons.check_circle;
      badgeText = 'COMPLETED';
    } else if (isActive) {
      badgeBgColor = _orangeWarning.withOpacity(0.15);
      badgeTextColor = _orangeWarning;
      badgeIcon = Icons.radio_button_checked;
      badgeText = 'ACTIVE';
    } else {
      badgeBgColor = Colors.grey.shade300.withOpacity(0.3);
      badgeTextColor = _isDark ? Colors.grey.shade400 : Colors.grey.shade600;
      badgeIcon = Icons.pause_circle_outline;
      badgeText = 'PAUSED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badgeIcon,
            size: 14,
            color: badgeTextColor,
          ),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: badgeTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: _accentBlue,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color:
                      _isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnomalyWarning(int anomalyCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _redError.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _redError.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            size: 16,
            color: _redError,
          ),
          const SizedBox(width: 6),
          Text(
            '$anomalyCount ${anomalyCount == 1 ? 'anomaly' : 'anomalies'} detected',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _redError,
            ),
          ),
        ],
      ),
    );
  }
}
