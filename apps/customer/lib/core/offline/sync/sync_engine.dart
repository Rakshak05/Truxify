import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../conflict/conflict_resolver.dart';
import '../db/offline_event_db.dart';
import '../models/trip_event.dart';

class SyncEngine {
  SyncEngine({
    required this.db,
    required this.apiBaseUrl,
    ConflictResolver? resolver,
    this.maxRetries = 5,
    this.batchSize = 20,
  }) : resolver = resolver ?? ConflictResolver();

  final OfflineEventDb db;
  final String apiBaseUrl;
  final ConflictResolver resolver;
  final int maxRetries;
  final int batchSize;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final Connectivity _connectivity = Connectivity();

  Future<void> startListening() async {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      final hasNetwork = results.any((result) => result != ConnectivityResult.none);
      if (hasNetwork) {
        unawaited(syncPending());
      }
    });
  }

  Future<void> stopListening() async {
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  Future<int> syncPending() async {
    final pending = await db.pendingEvents(limit: batchSize);
    if (pending.isEmpty) {
      return 0;
    }

    final resolved = resolver.resolve(pending);
    await _markAsSyncing(resolved);

    final uploaded = await _uploadBatch(resolved);
    if (uploaded) {
      for (final event in resolved) {
        await db.markSynced(event.id);
      }
      return resolved.length;
    }

    for (final event in resolved) {
      await db.markFailed(event.id, retryCount: event.retryCount + 1);
    }
    return 0;
  }

  Future<void> _markAsSyncing(List<TripEvent> events) async {
    for (final event in events) {
      await db.markSyncing(event.id);
    }
  }

  Future<bool> _uploadBatch(List<TripEvent> events) async {
    final body = jsonEncode({'events': events.map((event) => event.toJson()).toList()});

    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/v1/trips/events/batch'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    return response.statusCode == 200 || response.statusCode == 202;
  }
}
