import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'data/verses.dart';
import 'repository/verse_repository.dart';
import 'screens/chanting_screen.dart';
import 'services/notification_service.dart';

const String currentReligion = 'hindu'; // 'hindu' / 'islamic' / 'sikh'

String get appName {
  switch (currentReligion) {
    case 'hindu':
      return 'Gita Shlok Daily';
    case 'islamic':
      return 'Quran Verse Daily';
    case 'sikh':
      return 'Gurbani Daily';
    default:
      return 'Daily Verse';
  }
}

String get appEmoji {
  switch (currentReligion) {
    case 'hindu':
      return '🕉️';
    case 'islamic':
      return '☪️';
    case 'sikh':
      return '☬';
    default:
      return '📖';
  }
}

Color get primaryColor {
  switch (currentReligion) {
    case 'hindu':
      return const Color(0xFFFF9800);
    case 'islamic':
      return const Color(0xFF4CAF50);
    case 'sikh':
      return const Color(0xFF2196F3);
    default:
      return Colors.amber;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Safe notification initialization - App load hone me kabhi hang nahi hogi
  try {
    if (!kIsWeb) {
      await NotificationService.init(currentReligion);
    }
  } catch (e) {
    debugPrint("Notification init error: $e");
  }

  runApp(const DailyVerseApp());
}

class DailyVerseApp extends StatelessWidget {
  const DailyVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorSchemeSeed: primaryColor,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repo = VerseRepository();

  Verse? currentVerse;
  bool loading = true;
  String selectedCategory = 'all';
  int streak = 1;
  List<int> favorites = [];
  String? errorMessage;

  // Notification Preferences
  bool notifEnabled = true;
  int notifHour = 7;
  int notifMinute = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await _repo.initialize(currentReligion);

      final prefs = await SharedPreferences.getInstance();
      streak = prefs.getInt('streak') ?? 1;
      favorites = prefs.getStringList('favorites')?.map(int.parse).toList() ?? [];

      notifEnabled = prefs.getBool('notif_enabled') ?? true;
      notifHour = prefs.getInt('notif_hour') ?? 7;
      notifMinute = prefs.getInt('notif_minute') ?? 0;

      final initialVerse = _repo.next(category: selectedCategory);

      setState(() {
        currentVerse = initialVerse;
        loading = false;
        errorMessage = null;
      });

      if (initialVerse != null) _pushToWidget(initialVerse);
    } catch (e) {
      debugPrint("Error initializing repository: $e");
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  void _onNew() {
    setState(() {
      currentVerse = _repo.next(category: selectedCategory);
    });
    if (currentVerse != null) _pushToWidget(currentVerse!);
  }

  void _onCategory(String cat) {
    setState(() {
      selectedCategory = cat;
      currentVerse = _repo.next(category: cat);
    });
    if (currentVerse != null) _pushToWidget(currentVerse!);
  }

  void _pushToWidget(Verse v) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData('widget_title', '$appEmoji $appName');
      await HomeWidget.saveWidgetData('widget_original', v.original);
      await HomeWidget.saveWidgetData('widget_hindi', v.hindi);
      await HomeWidget.saveWidgetData('widget_source', v.source);
      await HomeWidget.updateWidget(
        name: 'HomeWidgetProvider',
        androidName: 'HomeWidgetProvider',
      );
    } catch (_) {}
  }

  Future<void> _toggleFav(int id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (favorites.contains(id)) {
        favorites.remove(id);
      } else {
        favorites.add(id);
      }
    });
    await prefs.setStringList(
      'favorites',
      favorites.map((e) => e.toString()).toList(),
    );
  }

  void _share(Verse v) {
    Share.share(
      '${v.original}\n\n${v.hindi}\n\n${v.english}\n\n— ${v.source}\n\n$appEmoji $appName',
    );
  }

  // ⏰ Custom Time Picker Dialog
  Future<void> _selectNotificationTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: notifHour, minute: notifMinute),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: primaryColor,
              surface: const Color(0xFF161B22),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        notifHour = picked.hour;
        notifMinute = picked.minute;
      });

      await NotificationService.scheduleDailyNotification(
        notifHour,
        notifMinute,
        currentReligion,
      );

      if (mounted) {
        final formattedTime =
            TimeOfDay(hour: notifHour, minute: notifMinute).format(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: primaryColor,
            content: Text(
              '🔔 Daily Reminder set for $formattedTime',
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    }
  }

  // ⚙️ Settings Modal Sheet
  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
     shape: const RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final timeString =
                TimeOfDay(hour: notifHour, minute: notifMinute).format(ctx);

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '⚙️ App Settings',
                    style: GoogleFonts.poppins(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Notification Switch
                  SwitchListTile(
                    title: const Text('Daily Notification'),
                    subtitle: const Text('Har din shlok padhne ka reminder',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                    value: notifEnabled,
                    activeColor: primaryColor,
                    onChanged: (val) async {
                      setModalState(() => notifEnabled = val);
                      setState(() => notifEnabled = val);
                      await NotificationService.toggleNotification(
                          val, currentReligion);
                    },
                  ),

                  // Notification Time Selector
                  if (notifEnabled)
                    ListTile(
                      leading:
                          const Icon(Icons.access_time, color: Colors.amber),
                      title: const Text('Reminder Time'),
                      subtitle: Text('Current: $timeString',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      trailing: Icon(Icons.arrow_forward_ios,
                          size: 16, color: primaryColor),
                      onTap: () async {
                        Navigator.pop(ctx);
                        await _selectNotificationTime();
                      },
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    // Error Fallback Screen
    if (errorMessage != null || currentVerse == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.amber),
                const SizedBox(height: 16),
                Text(
                  'Unable to load data',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage ?? 'No verses found in offline database.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                  onPressed: () {
                    setState(() => loading = true);
                    _boot();
                  },
                  child: const Text('Retry', style: TextStyle(color: Colors.black)),
                )
              ],
            ),
          ),
        ),
      );
    }

    final verse = currentVerse!;
    final cats = _repo.categories();
    final isFav = favorites.contains(verse.id);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header with Settings Gear Icon
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(appEmoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      appName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text('$streak',
                            style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon:
                        Icon(Icons.settings_outlined, color: Colors.grey[400]),
                    onPressed: _openSettings,
                  ),
                ],
              ),
            ),

            // Categories
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final c = cats[i];
                  final selected = selectedCategory == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        c[0].toUpperCase() + c.substring(1),
                        style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.black : Colors.grey[400],
                        ),
                      ),
                      selected: selected,
                      selectedColor: primaryColor,
                      backgroundColor: Colors.white.withOpacity(0.06),
                      side: BorderSide.none,
                      onSelected: (_) => _onCategory(c),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      primaryColor.withOpacity(0.12),
                      primaryColor.withOpacity(0.04),
                    ]),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: primaryColor.withOpacity(0.2)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          verse.original,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tiroDevanagariHindi(
                            fontSize: 20,
                            height: 1.7,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(
                            color: primaryColor.withOpacity(0.3),
                            thickness: 0.5),
                        const SizedBox(height: 20),
                        Text(
                          verse.hindi,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            color: Colors.grey[300],
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          verse.english,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '📖 ${verse.source}',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _btn(isFav ? '❤️' : '🤍', isFav ? 'Saved' : 'Save',
                      () => _toggleFav(verse.id)),
                  _btn('🔄', 'New', _onNew),
                  _btn('📤', 'Share', () => _share(verse)),
                  _btn('📿', 'Chant', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChantingScreen(
                          religion: currentReligion,
                          primaryColor: primaryColor,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn(String icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        ],
      ),
    );
  }
}