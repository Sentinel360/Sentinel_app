import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Caches sensor data locally when offline and flushes to Firestore when
/// connectivity returns. Uses SharedPreferences for simplicity (no new deps).
class OfflineCacheService {
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  static const String _cacheKey = 'sentinel360_offline_sensor_cache';
  static const int _maxCacheSize = 500; // Max events to cache

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Add a sensor event to the local cache.
  Future<void> cacheEvent(String tripId, Map<String, dynamic> eventData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      final entry = jsonEncode({
        'tripId': tripId,
        'data': eventData,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      });

      cached.add(entry);

      // Trim if over max size (remove oldest)
      if (cached.length > _maxCacheSize) {
        cached.removeRange(0, cached.length - _maxCacheSize);
      }

      await prefs.setStringList(_cacheKey, cached);
      debugPrint('[OfflineCache] Cached event for trip $tripId (${cached.length} total)');
    } catch (e) {
      debugPrint('[OfflineCache] Cache write error: $e');
    }
  }

  /// Get the number of cached events waiting to be flushed.
  Future<int> get pendingCount async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_cacheKey) ?? []).length;
  }

  /// Flush all cached events to Firestore. Call when connectivity returns.
  /// Returns the number of events successfully flushed.
  Future<int> flushToFirestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(_cacheKey) ?? [];

      if (cached.isEmpty) return 0;

      debugPrint('[OfflineCache] Flushing ${cached.length} cached events to Firestore...');

      int flushed = 0;
      final failed = <String>[];

      for (final entryJson in cached) {
        try {
          final entry = jsonDecode(entryJson) as Map<String, dynamic>;
          final tripId = entry['tripId'] as String;
          final data = entry['data'] as Map<String, dynamic>;

          // Mark as replayed from cache so the pipeline knows
          data['_fromCache'] = true;
          data['_cachedAt'] = entry['cachedAt'];

          await _db
              .collection('trips')
              .doc(tripId)
              .collection('sensor_data')
              .add(data);

          flushed++;
        } catch (e) {
          // Keep events that fail to flush for next attempt
          failed.add(entryJson);
          debugPrint('[OfflineCache] Flush error for one event: $e');
        }
      }

      // Replace cache with only the failed events
      await prefs.setStringList(_cacheKey, failed);

      debugPrint('[OfflineCache] Flushed $flushed events, ${failed.length} remaining');
      return flushed;
    } catch (e) {
      debugPrint('[OfflineCache] Flush error: $e');
      return 0;
    }
  }

  /// Clear all cached events (e.g., on logout).
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
