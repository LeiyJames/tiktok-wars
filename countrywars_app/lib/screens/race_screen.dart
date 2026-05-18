// lib/screens/race_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/race_model.dart';
import '../services/websocket_service.dart';
import '../widgets/lane_widget.dart';

class RaceScreen extends StatefulWidget {
  final WebSocketService wsService;
  const RaceScreen({super.key, required this.wsService});

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  List<RaceEntry> _leaderboard = [];
  BattleState? _battle;
  String? _levelUpCountry;
  Timer? _levelUpTimer;
  List<_GiftParticle> _particles = [];

  @override
  void initState() {
    super.initState();
    // Force landscape for the streaming view
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    widget.wsService.addListener2(_onEvent);
  }

  @override
  void dispose() {
    widget.wsService.removeListener2(_onEvent);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? '';
    switch (type) {
      case 'full_update':
      case 'points_update':
        final lb = (data['leaderboard'] as List?)
                ?.map((e) => RaceEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];

        // Detect boosted countries
        final boostedCountry = data['country'] as String?;
        for (final entry in lb) {
          if (entry.country == boostedCountry) entry.isBoosted = true;
        }

        setState(() => _leaderboard = lb);

        if (data['battle'] != null) {
          setState(() =>
              _battle = BattleState.fromJson(data['battle'] as Map<String, dynamic>));
        }
        if (data['leveled_up'] == true) {
          _showLevelUp(data['country'] as String? ?? '');
        }
        if (data['event_type'] == 'gift') {
          _spawnGift(data['gift_name'] as String? ?? '🎁');
        }
        break;
      case 'battle_start':
        setState(() => _battle = BattleState(
              countryA: data['country_a'] ?? '',
              countryB: data['country_b'] ?? '',
              active: true,
            ));
        break;
      case 'battle_end':
        setState(() => _battle = null);
        break;
    }
  }

  void _showLevelUp(String country) {
    setState(() => _levelUpCountry = country);
    _levelUpTimer?.cancel();
    _levelUpTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _levelUpCountry = null);
    });
  }

  void _spawnGift(String giftName) {
    final particle = _GiftParticle(name: giftName);
    setState(() => _particles.add(particle));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _particles.remove(particle));
    });
  }

  int get _highestPoints =>
      _leaderboard.isEmpty ? 1 : _leaderboard.first.points.clamp(1, 999999999);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Dark gradient background (placeholder while no bg video) ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0B071C),
                  Color(0xFF1A103C),
                  Color(0xFF0D1B2A),
                  Color(0xFF0B071C),
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .tint(color: const Color(0xFF120830), duration: 8.seconds),

          // ── Main overlay panel ──
          Center(
            child: Container(
              width: 420,
              height: 700,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFD700).withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(),
                  if (_battle != null && _battle!.active) _buildBattleBanner(),
                  Expanded(child: _buildTrack()),
                  _buildTicker(),
                ],
              ),
            ),
          ),

          // ── Gift particles ──
          ..._particles.map((p) => _GiftParticleWidget(particle: p)),

          // ── Level Up popup ──
          if (_levelUpCountry != null)
            Center(
              child: _LevelUpPopup(country: _levelUpCountry!),
            ),

          // ── Connection status dot ──
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.wsService.connected ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('⚔️', style: TextStyle(fontSize: 20)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF0040),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Text('● ', style: TextStyle(color: Colors.white, fontSize: 10)),
                Text(
                  'LIVE',
                  style: GoogleFonts.orbitron(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fade(begin: 1, end: 0.4, duration: 1.seconds),
        ],
      ),
    );
  }

  Widget _buildBattleBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.3),
            Colors.orange.withOpacity(0.2),
            Colors.blue.withOpacity(0.3),
          ],
        ),
      ),
      child: Text(
        '⚔️ BATTLE: ${_battle!.countryA} VS ${_battle!.countryB}',
        textAlign: TextAlign.center,
        style: GoogleFonts.orbitron(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFFFD700),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .shimmer(duration: 1.5.seconds, color: Colors.orange.withOpacity(0.3));
  }

  Widget _buildTrack() {
    if (_leaderboard.isEmpty) {
      return Center(
        child: Text(
          'Waiting for viewers...\nComment your country to join!',
          textAlign: TextAlign.center,
          style: GoogleFonts.orbitron(
            color: Colors.white38,
            fontSize: 13,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _leaderboard.length,
      itemBuilder: (_, i) => SizedBox(
        height: 60,
        child: LaneWidget(
          entry: _leaderboard[i],
          highestPoints: _highestPoints,
        ),
      ),
    );
  }

  Widget _buildTicker() {
    final msg =
        '⚔️  COUNTRY WARS!  ◆  Comment your country name, code, or flag emoji to join!  ◆  👍 Likes • 💬 Comments • 🎁 Gifts • 🔁 Shares • ➕ Follows all give POINTS!  ◆  🏆 The winning country WINS THE WAR!  ◆  ';
    return Container(
      height: 26,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        border: Border(
          top: BorderSide(color: const Color(0xFFFFD700).withOpacity(0.3)),
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: _MarqueeTicker(text: msg),
    );
  }
}

// ── Marquee Ticker ─────────────────────────────────────────────────────────────
class _MarqueeTicker extends StatefulWidget {
  final String text;
  const _MarqueeTicker({required this.text});

  @override
  State<_MarqueeTicker> createState() => _MarqueeTickerState();
}

class _MarqueeTickerState extends State<_MarqueeTicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..addListener(() {
        if (_scroll.hasClients) {
          _scroll.jumpTo(
              _ctrl.value * _scroll.position.maxScrollExtent);
        }
      });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.repeat());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Row(
        children: [
          Text(
            widget.text + widget.text,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              color: const Color(0xFFFFD700),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gift Particle ──────────────────────────────────────────────────────────────
class _GiftParticle {
  final String name;
  _GiftParticle({required this.name});
}

class _GiftParticleWidget extends StatelessWidget {
  final _GiftParticle particle;
  const _GiftParticleWidget({required this.particle});

  @override
  Widget build(BuildContext context) {
    final giftEmoji = _giftEmoji(particle.name);
    return Positioned(
      top: 60,
      left: MediaQuery.of(context).size.width * 0.4,
      child: Text(giftEmoji, style: const TextStyle(fontSize: 36))
          .animate()
          .moveY(begin: 0, end: 200, duration: 2.seconds)
          .fadeOut(begin: 1, duration: 2.seconds)
          .rotate(begin: 0, end: 1),
    );
  }

  String _giftEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('rose')) return '🌹';
    if (n.contains('lion')) return '🦁';
    if (n.contains('universe')) return '🪐';
    if (n.contains('galaxy')) return '🌌';
    if (n.contains('firework')) return '🎆';
    if (n.contains('ice cream')) return '🍦';
    return '🎁';
  }
}

// ── Level Up Popup ─────────────────────────────────────────────────────────────
class _LevelUpPopup extends StatelessWidget {
  final String country;
  const _LevelUpPopup({required this.country});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD700), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withOpacity(0.5),
            blurRadius: 60,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('⚡', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(
            'LEVEL UP!',
            style: GoogleFonts.orbitron(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFFD700),
            ),
          ),
          Text(
            country,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    )
        .animate()
        .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 500.ms, curve: Curves.elasticOut)
        .then(delay: 2.5.seconds)
        .scale(begin: const Offset(1, 1), end: const Offset(0, 0), duration: 400.ms);
  }
}
