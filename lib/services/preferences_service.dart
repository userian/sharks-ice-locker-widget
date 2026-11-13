import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/locker_assignment.dart';

/// Persists user settings (selected teams, enabled Sharks Ice facilities) and
/// cached locker room data across app launches and background widget refreshes.
class PreferencesService {
  static const String _selectedTeamsKey = 'selected_teams_v1';
  static const String _enabledFacilitiesKey = 'enabled_facilities_v1';
  static const String _knownTeamsCacheKey = 'known_teams_cache_v1';
  static const String _cachedTodayGamesKey = 'cached_today_games_v1';
  static const String _lastUpdatedIsoKey = 'last_updated_iso_v1';

  Future<List<String>> getSelectedTeams() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_selectedTeamsKey) ?? <String>[];
  }

  Future<void> setSelectedTeams(List<String> teams) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = teams.map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await prefs.setStringList(_selectedTeamsKey, cleaned);
  }

  Future<Set<SharksIceFacility>> getEnabledFacilities() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_enabledFacilitiesKey);
    if (stored == null || stored.isEmpty) {
      return {
        SharksIceFacility.sanJose,
        SharksIceFacility.fremont,
      };
    }
    return stored.map(SharksIceFacility.fromId).toSet();
  }

  Future<void> setEnabledFacilities(Set<SharksIceFacility> facilities) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _enabledFacilitiesKey,
      facilities.map((f) => f.id).toList(),
    );
  }

  Future<List<String>> getCachedKnownTeams() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_knownTeamsCacheKey) ?? _defaultSiahlSeedTeams;
  }

  Future<void> mergeKnownTeams(Iterable<String> discoveredTeams) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_knownTeamsCacheKey) ?? _defaultSiahlSeedTeams;
    final merged = {...existing, ...discoveredTeams.map((t) => t.trim())}
        .where((t) => t.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await prefs.setStringList(_knownTeamsCacheKey, merged);
  }

  Future<void> cacheTodayGames(List<GameLockerAssignment> games) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(games.map((g) => g.toJson()).toList());
    await prefs.setString(_cachedTodayGamesKey, encoded);
    await prefs.setString(_lastUpdatedIsoKey, DateTime.now().toIso8601String());
  }

  Future<List<GameLockerAssignment>> getCachedTodayGames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedTodayGamesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => GameLockerAssignment.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<DateTime?> getLastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_lastUpdatedIsoKey);
    if (iso == null) return null;
    return DateTime.tryParse(iso);
  }

  /// Common SIAHL team names pre-populated so the user can immediately search
  /// or test even while offline, in addition to live-scraped teams.
  static const List<String> _defaultSiahlSeedTeams = [
    'Arctic Wolves',
    'Bay Area Beers',
    'Black Ice',
    'Blades of Steel',
    'Booze Hounds',
    'California Gold',
    'Choking Hazards',
    'Crabs',
    'Dangles',
    'Desert Dogs',
    'Dump and Chase',
    'East Bayisko',
    'Fighting Turtles',
    'Flying Monkeys',
    'Fremont Freeze',
    'Goal Diggers',
    'Golden Seals',
    'Hat Trick Swayze',
    'Hooligans',
    'Ice Holes',
    'Ice Pirates',
    'Icebreakers',
    'Jagr Bombs',
    'Knights',
    'Lumberjacks',
    'Mighty Drunks',
    'Net Minders',
    'No Regretzkys',
    'Oakland Oaks',
    'Old Farts',
    'Puck Hogs',
    'Puck Norris',
    'Puckaneers',
    'Red Wings',
    'Rink Rats',
    'San Jose Barons',
    'San Jose Yetis',
    'Saved By The Goal',
    'Screaming Eagles',
    'Seal Team Sticks',
    'Silicon Valley Skaters',
    'Slap Shots',
    'Trash Pandas',
    'Weekend Warriors',
    'Winterhawks',
    'Zamboni Drivers',
  ];
}
