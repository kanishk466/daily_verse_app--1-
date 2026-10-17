import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../data/verses.dart';

class VerseRepository {
  // Singleton
  static final VerseRepository _instance = VerseRepository._internal();
  factory VerseRepository() => _instance;
  VerseRepository._internal();

  // Tier-1: Master local database (loaded from assets)
  final List<Verse> _localDb = [];

  // Tier-2: In-memory ring buffer (for 0ms UI reads)
  final List<Verse> _buffer = [];
  static const int _bufferSize = 12;

  bool _initialized = false;
  final _random = Random();

  /// Call once at app start
  Future<void> initialize(String religion) async {
    if (_initialized) return;

    try {
      final raw = await rootBundle.loadString('assets/database/$religion.json');
      final List<dynamic> list = jsonDecode(raw);

      _localDb
        ..clear()
        ..addAll(list
            .map((e) => Verse.fromJson(e as Map<String, dynamic>, religion)));

      _refillBuffer();
      _initialized = true;

      // Non-blocking background sync (architecture layer)
      _triggerBackgroundSync(religion);
    } catch (e) {
      // Fail-safe: keep empty, UI will show fallback
      print('VerseRepository init error: $e');
    }
  }

  /// 0ms read — UI always calls this
  Verse next({String category = 'all'}) {
    if (_buffer.isEmpty) _refillBuffer(category: category);

    // Prefer category match from buffer
    if (category != 'all') {
      final matchIndex = _buffer.indexWhere((v) => v.category == category);
      if (matchIndex != -1) {
        return _buffer.removeAt(matchIndex);
      }
    }

    // Fallback: any from buffer
    if (_buffer.isNotEmpty) {
      return _buffer.removeAt(0);
    }

    // Ultimate fallback
    return _localDb.isNotEmpty
        ? _localDb[_random.nextInt(_localDb.length)]
        : _fallbackVerse();
  }

  List<String> categories() {
    final set = _localDb.map((v) => v.category).toSet().toList();
    return ['all', ...set];
  }

  bool get isReady => _initialized && _localDb.isNotEmpty;

  // ───────── Private helpers ─────────

  void _refillBuffer({String category = 'all'}) {
    _buffer.clear();
    final source = category == 'all'
        ? List<Verse>.from(_localDb)
        : _localDb.where((v) => v.category == category).toList();

    if (source.isEmpty) {
      _buffer.addAll(_localDb);
    } else {
      source.shuffle(_random);
      _buffer.addAll(source.take(_bufferSize));
    }

    // If still short, pad with random from full DB
    while (_buffer.length < _bufferSize && _localDb.isNotEmpty) {
      _buffer.add(_localDb[_random.nextInt(_localDb.length)]);
    }
  }

  /// Background sync stub (non-blocking)
  /// Later: hit Firebase / REST and merge into local store
  void _triggerBackgroundSync(String religion) {
    Future.microtask(() async {
      try {
        // TODO Phase 1.5:
        // final remote = await SyncService.fetchUpdates(religion);
        // merge into _localDb + persist to Hive/SharedPreferences
      } catch (_) {
        // Silent fail — never block UI
      }
    });
  }

  Verse _fallbackVerse() {
    return const Verse(
      id: 0,
      religion: 'hindu',
      original: 'कर्मण्येवाधिकारस्ते मा फलेषु कदाचन।',
      transliteration: 'Karmanye vadhikaraste ma phaleshu kadachana',
      hindi: 'तेरा अधिकार केवल कर्म में है, फल में नहीं।',
      english: 'You have a right to duty, not to its fruits.',
      source: 'Bhagavad Gita 2.47',
      category: 'motivation',
    );
  }
}
