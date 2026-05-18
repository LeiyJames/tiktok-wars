// lib/screens/setup_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/websocket_service.dart';
import 'race_screen.dart';

class SetupScreen extends StatefulWidget {
  final WebSocketService wsService;
  const SetupScreen({super.key, required this.wsService});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _urlCtrl = TextEditingController();
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  Future<void> _loadSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url') ?? '';
    if (saved.isNotEmpty) {
      _urlCtrl.text = saved;
    }
  }

  Future<void> _connect() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter your server URL');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', url);

    widget.wsService.setUrl(url);
    widget.wsService.connect();

    // Wait briefly to check connection
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      if (widget.wsService.connected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => RaceScreen(wsService: widget.wsService),
          ),
        );
      } else {
        setState(() {
          _connecting = false;
          _error = 'Could not connect. Check your server URL and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B071C),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚔️', style: TextStyle(fontSize: 60)),
              const SizedBox(height: 12),
              Text(
                'COUNTRY WARS',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFFD700),
                ),
              ),
              Text(
                'RACING OVERLAY',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  color: Colors.white38,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Backend Server URL',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        color: Colors.white54,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://your-app.railway.app',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            const Icon(Icons.link, color: Colors.white38),
                      ),
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _connect(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _connecting ? null : _connect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD700),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _connecting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.black,
                                ),
                              )
                            : Text(
                                'CONNECT TO SERVER',
                                style: GoogleFonts.orbitron(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Need a server? Deploy your backend to Railway.app',
                style: TextStyle(color: Colors.white38, fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
