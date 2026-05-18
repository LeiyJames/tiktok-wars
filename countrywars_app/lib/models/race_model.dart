// lib/models/race_model.dart

class CountryStats {
  final int likes;
  final int comments;
  final int gifts;
  final int follows;
  final int shares;

  CountryStats({
    this.likes = 0,
    this.comments = 0,
    this.gifts = 0,
    this.follows = 0,
    this.shares = 0,
  });

  factory CountryStats.fromJson(Map<String, dynamic> j) => CountryStats(
        likes: (j['likes'] ?? 0) as int,
        comments: (j['comments'] ?? 0) as int,
        gifts: (j['gifts'] ?? 0) as int,
        follows: (j['follows'] ?? 0) as int,
        shares: (j['shares'] ?? 0) as int,
      );
}

class RaceEntry {
  final String country;
  final String flag;
  final int points;
  final int rank;
  final int level;
  final CountryStats stats;

  /// Whether this entry is currently in a speed-boost state
  bool isBoosted;

  RaceEntry({
    required this.country,
    required this.flag,
    required this.points,
    required this.rank,
    required this.level,
    required this.stats,
    this.isBoosted = false,
  });

  factory RaceEntry.fromJson(Map<String, dynamic> j) => RaceEntry(
        country: j['country'] ?? '',
        flag: j['flag'] ?? '🏳️',
        points: (j['points'] ?? 0) as int,
        rank: (j['rank'] ?? 0) as int,
        level: (j['level'] ?? 1) as int,
        stats: CountryStats.fromJson(j['stats'] ?? {}),
      );

  /// ISO 3166-1 alpha-2 code extracted from flag emoji
  String get isoCode {
    if (flag.runes.length == 2) {
      final r = flag.runes.toList();
      final a = String.fromCharCode(r[0] - 0x1F1A5);
      final b = String.fromCharCode(r[1] - 0x1F1A5);
      return '$a$b'.toUpperCase();
    }
    return 'un';
  }

  String get flagUrl =>
      'https://flagcdn.com/w40/${isoCode.toLowerCase()}.png';
}

class BattleState {
  final String countryA;
  final String countryB;
  final bool active;

  BattleState({
    required this.countryA,
    required this.countryB,
    required this.active,
  });

  factory BattleState.fromJson(Map<String, dynamic> j) => BattleState(
        countryA: j['country_a'] ?? '',
        countryB: j['country_b'] ?? '',
        active: (j['active'] ?? 0) == 1,
      );
}
