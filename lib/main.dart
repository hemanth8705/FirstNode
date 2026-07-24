import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/audio_service.dart';
import 'services/storage.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  // Needed because we touch platform plugins (shared_preferences) before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Create the store and kick off loading saved data (not awaited — the Home
  // screen shows a spinner until AppState reports `loaded`).
  final appState = AppState(Storage())..init();

  runApp(FirstNodeApp(appState: appState));
}

class FirstNodeApp extends StatelessWidget {
  final AppState appState;
  const FirstNodeApp({required this.appState, super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // The data store, shared with every screen.
        ChangeNotifierProvider<AppState>.value(value: appState),
        // The audio player, created once and disposed with the app.
        Provider<AudioService>(
          create: (_) => AudioService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'FirstNode',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const HomeScreen(),
      ),
    );
  }
}
