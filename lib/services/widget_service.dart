// lib/services/widget_service.dart
import 'package:home_widget/home_widget.dart';
import '../data/verses.dart';

class WidgetService {
  // Android App Widget Group / Name
  static const String androidWidgetName = 'VerseWidgetProvider';

  // Widget update karne ka function
  static Future<void> updateVerseWidget(Verse verse, String appTitle) async {
    try {
      // Data save karo jo widget dikhayega
      await HomeWidget.saveWidgetData<String>('widget_title', appTitle);
      await HomeWidget.saveWidgetData<String>(
          'widget_original', verse.original);
      await HomeWidget.saveWidgetData<String>('widget_hindi', verse.hindi);
      await HomeWidget.saveWidgetData<String>('widget_source', verse.source);

      // Widget UI ko refresh ka signal do
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
      );
    } catch (e) {
      print('Widget update error: $e');
    }
  }
}
