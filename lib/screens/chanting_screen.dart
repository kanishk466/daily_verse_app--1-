// lib/screens/chanting_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChantingScreen extends StatefulWidget {
  final String religion;
  final Color primaryColor;

  const ChantingScreen({
    super.key,
    required this.religion,
    required this.primaryColor,
  });

  @override
  State<ChantingScreen> createState() => _ChantingScreenState();
}

class _ChantingScreenState extends State<ChantingScreen> {
  int _count = 0;
  int _target = 108;
  int _completedLaps = 0;
  bool _hapticEnabled = true;
  bool _soundEnabled = true;

  @override
  void initState() {
    super.initState();
    _setTargetForReligion();
    _loadState();
  }

  void _setTargetForReligion() {
    if (widget.religion == 'islamic') {
      _target = 33;
    } else {
      _target = 108;
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _count = prefs.getInt('chant_count_${widget.religion}') ?? 0;
      _completedLaps = prefs.getInt('chant_laps_${widget.religion}') ?? 0;
      _hapticEnabled = prefs.getBool('chant_haptic') ?? true;
      _soundEnabled = prefs.getBool('chant_sound') ?? true;
    });
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('chant_count_${widget.religion}', _count);
    await prefs.setInt('chant_laps_${widget.religion}', _completedLaps);
  }

  void _increment() {
    setState(() {
      _count++;

      // Haptic Feedback (Vibration)
      if (_hapticEnabled) {
        HapticFeedback.lightImpact();
      }

      // Sound Feedback (System Click)
      if (_soundEnabled) {
        SystemSound.play(SystemSoundType.click);
      }

      // Target Completion Check
      if (_count % _target == 0) {
        _completedLaps++;
        if (_hapticEnabled) {
          // Double Heavy Impact on Completion!
          HapticFeedback.heavyImpact();
          Future.delayed(const Duration(milliseconds: 150), () {
            HapticFeedback.heavyImpact();
          });
        }
        _showCompletionDialog();
      }
    });
    _saveState();
  }

  void _reset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('Reset Counter?'),
        content:
            const Text('Kya aap aaj ka chanting count zero karna chahte hain?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _count = 0;
                _completedLaps = 0;
              });
              _saveState();
              Navigator.pop(ctx);
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showCompletionDialog() {
    final term = widget.religion == 'islamic' ? 'Tasbeeh' : 'Mala';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: widget.primaryColor,
        content: Row(
          children: [
            const Text('🎉 ', style: TextStyle(fontSize: 20)),
            Expanded(
              child: Text(
                '1 $term Completed! Total Completed: $_completedLaps',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.black),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String get _title {
    switch (widget.religion) {
      case 'hindu':
        return '📿 Jap Mala Counter';
      case 'islamic':
        return '📿 Digital Tasbeeh';
      case 'sikh':
        return '📿 Waheguru Simran Counter';
      default:
        return '📿 Counter';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_count % _target) / _target;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _title,
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _hapticEnabled ? Icons.vibration : Icons.mobile_off,
              color: _hapticEnabled ? widget.primaryColor : Colors.grey,
            ),
            onPressed: () {
              setState(() => _hapticEnabled = !_hapticEnabled);
              SharedPreferences.getInstance()
                  .then((p) => p.setBool('chant_haptic', _hapticEnabled));
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _reset,
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _increment, // Tap ANYWHERE on screen to Count!
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Target Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Target: $_target counts per lap | Laps Completed: $_completedLaps',
                  style: TextStyle(
                    color: widget.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              // Circular Progress + Giant Count Display
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 240,
                    height: 240,
                    child: CircularProgressIndicator(
                      value: progress == 0 && _count > 0 ? 1.0 : progress,
                      strokeWidth: 12,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      color: widget.primaryColor,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_count',
                        style: GoogleFonts.poppins(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_count % _target} / $_target',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const Spacer(),

              // Tap Instruction Hint
              Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  children: [
                    Icon(Icons.touch_app, color: widget.primaryColor, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      'Screen par kahin bhi TAP karein',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
