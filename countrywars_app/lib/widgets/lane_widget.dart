// lib/widgets/lane_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/race_model.dart';

class LaneWidget extends StatefulWidget {
  final RaceEntry entry;
  final int highestPoints;

  const LaneWidget({
    super.key,
    required this.entry,
    required this.highestPoints,
  });

  @override
  State<LaneWidget> createState() => _LaneWidgetState();
}

class _LaneWidgetState extends State<LaneWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _runnerAnim;
  Timer? _boostTimer;
  bool _isBoosted = false;

  // Running body animation using a simple up/down bounce
  @override
  void initState() {
    super.initState();
    _runnerAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LaneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entry.points > oldWidget.entry.points) {
      _triggerBoost();
    }
  }

  void _triggerBoost() {
    setState(() => _isBoosted = true);
    _boostTimer?.cancel();
    _boostTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isBoosted = false);
    });
    _runnerAnim.duration = _isBoosted
        ? const Duration(milliseconds: 140)
        : const Duration(milliseconds: 350);
  }

  @override
  void dispose() {
    _runnerAnim.dispose();
    _boostTimer?.cancel();
    super.dispose();
  }

  double get _runnerLeftFraction {
    if (widget.highestPoints <= 0) return 0;
    return (widget.entry.points / widget.highestPoints) * 0.68;
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Color get _rankColor {
    switch (widget.entry.rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.white54;
    }
  }

  String get _rankIcon {
    switch (widget.entry.rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#${widget.entry.rank}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ── Left glass info panel ──
          Container(
            width: 130,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.black.withOpacity(0),
                ],
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 22,
                  child: Text(
                    _rankIcon,
                    style: TextStyle(fontSize: 13, color: _rankColor),
                  ),
                ),
                const SizedBox(width: 4),
                // Flag
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: CachedNetworkImage(
                    imageUrl: widget.entry.flagUrl,
                    width: 24,
                    height: 16,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) =>
                        Text(widget.entry.flag, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 5),
                // Points + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _fmt(widget.entry.points),
                        style: GoogleFonts.orbitron(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFD700),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          _statChip('👍', widget.entry.stats.likes),
                          const SizedBox(width: 3),
                          _statChip('🎁', widget.entry.stats.gifts),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Race track area ──
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final runnerLeft = maxWidth * _runnerLeftFraction;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Dust particles
                    if (_isBoosted)
                      Positioned(
                        bottom: 4,
                        left: runnerLeft - 10,
                        child: _DustTrail(boosted: _isBoosted),
                      ),

                    // Runner character
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.elasticOut,
                      bottom: 0,
                      left: runnerLeft,
                      child: _RunnerCharacter(
                        entry: widget.entry,
                        isBoosted: _isBoosted,
                        animController: _runnerAnim,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String emoji, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 8)),
        Text(
          _fmt(count),
          style: const TextStyle(fontSize: 8, color: Colors.white70),
        ),
      ],
    );
  }
}

// ── Runner Character ──────────────────────────────────────────────────────────
class _RunnerCharacter extends StatelessWidget {
  final RaceEntry entry;
  final bool isBoosted;
  final AnimationController animController;

  const _RunnerCharacter({
    required this.entry,
    required this.isBoosted,
    required this.animController,
  });

  @override
  Widget build(BuildContext context) {
    Widget runner = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flag above head
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: CachedNetworkImage(
            imageUrl: entry.flagUrl,
            width: 18,
            height: 12,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) =>
                Text(entry.flag, style: const TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(height: 1),
        // Running stick figure emoji (bouncing)
        AnimatedBuilder(
          animation: animController,
          builder: (_, __) {
            return Transform.translate(
              offset: Offset(0, -animController.value * 3),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..rotateZ(isBoosted ? -0.15 : 0),
                child: Text(
                  '🏃',
                  style: TextStyle(
                    fontSize: isBoosted ? 28 : 24,
                    shadows: isBoosted
                        ? [
                            const Shadow(
                              color: Color(0xFF00FFAA),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );

    if (isBoosted) {
      runner = runner
          .animate(onPlay: (c) => c.repeat())
          .shimmer(
            duration: 400.ms,
            color: const Color(0xFF00FFAA).withOpacity(0.4),
          );
    }

    return runner;
  }
}

// ── Dust Trail ───────────────────────────────────────────────────────────────
class _DustTrail extends StatelessWidget {
  final bool boosted;
  const _DustTrail({required this.boosted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        3,
        (i) => Container(
          margin: const EdgeInsets.only(right: 3),
          width: boosted ? 16.0 : 8.0,
          height: 3,
          decoration: BoxDecoration(
            color: boosted
                ? const Color(0xFF00FFAA).withOpacity(0.6 - i * 0.15)
                : Colors.white.withOpacity(0.3 - i * 0.08),
            borderRadius: BorderRadius.circular(2),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .fadeOut(duration: (200 + i * 80).ms),
      ),
    );
  }
}
