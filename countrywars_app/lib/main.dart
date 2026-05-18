// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/websocket_service.dart';
import 'screens/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const CountryWarsApp());
}

class CountryWarsApp extends StatelessWidget {
  const CountryWarsApp({super.key});

  @override
  Widget build(BuildContext context) {
    final wsService = WebSocketService();
    return MaterialApp(
      title: 'Country Wars',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B071C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
        ),
      ),
      home: SetupScreen(wsService: wsService),
    );
  }
}
