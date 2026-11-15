import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/preferences_service.dart';
import 'services/timetoscore_parser.dart';
import 'services/widget_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferencesService = PreferencesService();
  final parser = TimeToScoreParser();
  final widgetSyncService = WidgetSyncService(
    preferencesService: preferencesService,
    parser: parser,
  );

  await widgetSyncService.initialize();

  runApp(
    SharksIceLockerApp(
      preferencesService: preferencesService,
      parser: parser,
      widgetSyncService: widgetSyncService,
    ),
  );
}

class SharksIceLockerApp extends StatelessWidget {
  const SharksIceLockerApp({
    super.key,
    required this.preferencesService,
    required this.parser,
    required this.widgetSyncService,
  });

  final PreferencesService preferencesService;
  final TimeToScoreParser parser;
  final WidgetSyncService widgetSyncService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Which Locker Room?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006D77),
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        preferencesService: preferencesService,
        parser: parser,
        widgetSyncService: widgetSyncService,
      ),
    );
  }
}
