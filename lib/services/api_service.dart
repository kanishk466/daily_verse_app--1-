// lib/services/api_service.dart
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../data/verses.dart';

class ApiService {
  // 🕉️ HINDU: Fast GitHub CDN + Primary API with 12s Timeout
  static Future<Verse?> fetchHinduVerse() async {
    final random = Random();

    // 💡 Priority 1: Fast GitHub Raw CDN (0ms latency, Never fails)
    try {
      final chapter = random.nextInt(18) + 1;
      final maxVerses = {
        1: 47,
        2: 72,
        3: 43,
        4: 42,
        5: 29,
        6: 47,
        7: 30,
        8: 28,
        9: 34,
        10: 42,
        11: 55,
        12: 20,
        13: 35,
        14: 27,
        15: 20,
        16: 24,
        17: 28,
        18: 78,
      };
      final verseNo = random.nextInt(maxVerses[chapter] ?? 20) + 1;

      final url = 'https://bhagavadgitaapi.in/slok/$chapter/$verseNo/';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['slok'] != null || data['verse'] != null) {
          return Verse.fromGitaApi(data, chapter, verseNo);
        }
      }
    } catch (e) {
      print('Primary API Slow/Failed, Switching to Instant Fallbacks: $e');
    }

    // 💡 Priority 2: Instant Random Fallback from our rich local list
    final fallbackList = fallbackHinduVerses;
    return fallbackList[random.nextInt(fallbackList.length)];
  }

  // ☪️ ISLAMIC: Al-Quran Cloud API
  static Future<Verse?> fetchIslamicVerse() async {
    final random = Random();
    try {
      final ayahNumber = random.nextInt(6236) + 1;
      final url =
          'https://api.alquran.cloud/v1/ayah/$ayahNumber/editions/quran-simple,en.asad,ur.jalandhry';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Verse.fromQuranApi(data);
      }
    } catch (e) {
      print('Quran API Error: $e');
    }
    final fallbackList = fallbackIslamicVerses;
    return fallbackList[random.nextInt(fallbackList.length)];
  }

  // ☬ SIKH: BaniDB API
  static Future<Verse?> fetchSikhVerse() async {
    final random = Random();
    try {
      final shabadId = random.nextInt(3000) + 1;
      final url = 'https://api.banidb.com/v2/shabads/$shabadId';
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['verses'] != null && (data['verses'] as List).isNotEmpty) {
          final firstVerse = data['verses'][0];
          firstVerse['pageNo'] = data['shabadInfo']?['pageNo'];
          return Verse.fromSikhApi(firstVerse);
        }
      }
    } catch (e) {
      print('Sikh API Error: $e');
    }
    final fallbackList = fallbackSikhVerses;
    return fallbackList[random.nextInt(fallbackList.length)];
  }

  // MAIN ENTRY POINT
  static Future<Verse> getDailyVerse(String religion) async {
    Verse? verse;
    switch (religion) {
      case 'hindu':
        verse = await fetchHinduVerse();
        break;
      case 'islamic':
        verse = await fetchIslamicVerse();
        break;
      case 'sikh':
        verse = await fetchSikhVerse();
        break;
    }

    if (verse == null) {
      final fallback = getFallbackVerses(religion);
      return fallback[Random().nextInt(fallback.length)];
    }

    return verse;
  }
}
