import 'package:freightfair/core/offline/gps/gps_delta_compressor.dart';

import 'db/offline_event_db.dart';
import 'models/trip_event.dart';
import 'sync/sync_engine.dart';
import 'websocket/resilient_websocket.dart';

class OfflineSyncManager {
  OfflineSyncManager({required this.apiBaseUrl, required this.wsUrl});

  final String apiBaseUrl;
  final String wsUrl;

  final OfflineEventDb _db = OfflineEventDb();
  late final SyncEngine _syncEngine;
  late final ResilientWebSocket _ws;

  Future<void> init() async {
    await _db.open();
    _syncEngine = SyncEngine(db: _db, apiBaseUrl: apiBaseUrl);
    await _syncEngine.startListening();
    _ws = ResilientWebSocket(wsUrl);
    await _ws.connect();
  }

  Future<void> recordGpsUpdate({required String tripId, required GpsPoint point}) async {
    final event = TripEvent.gpsUpdate(
      tripId,
      {'latitude': point.latitude, 'longitude': point.longitude, 'timestampMs': point.timestampMs},
    );
    await _db.insert(event);
    await _syncEngine.syncPending();
  }

  Future<void> recordOtpDelivery({required String tripId, required String stopId, required String otp}) async {
    final event = TripEvent.otpDelivery(tripId, stopId, otp);
    await _db.insert(event);
    await _syncEngine.syncPending();
  }

  Future<void> recordTripEnd({required String tripId}) async {
    final event = TripEvent.tripEnd(tripId);
    await _db.insert(event);
    await _syncEngine.syncPending();
  }

  Future<void> dispose() async {
    await _syncEngine.stopListening();
    await _ws.close();
    await _db.close();
  }
}
