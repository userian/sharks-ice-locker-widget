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
    final stored = prefs.getStringList(_knownTeamsCacheKey) ?? const <String>[];
    final combined = {..._defaultSiahlSeedTeams, ...stored}
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return combined;
  }

  Future<void> mergeKnownTeams(Iterable<String> discoveredTeams) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_knownTeamsCacheKey) ?? const <String>[];
    final merged = {
      ..._defaultSiahlSeedTeams,
      ...existing,
      ...discoveredTeams.map((t) => t.trim()),
    }.where((t) => t.isNotEmpty).toList()
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

  /// Comprehensive SIAHL team names pre-populated for instant offline search,
  /// merged automatically with live-scraped teams from TimeToScore `display-stats.php`.
  static const List<String> _defaultSiahlSeedTeams = [
    '2nd Battalion',
    '3rd Line Scrubs',
    'A-Team',
    'Americans',
    'Arctic Wolves',
    'Bandits 1',
    'Bandits 2',
    'Battalion',
    'Bay Area Beers',
    'Beasts of Bourbon',
    'Beaver Dragons',
    'Beerbears on Ice',
    'Beerhawks',
    'BK 10',
    'Black Ice',
    'Black Mambas',
    'Blade Runners',
    'Blades of Steel',
    'Booze Hounds',
    'Boozehounds',
    'Buffalo Wings',
    'California Gold',
    'Cant Score Wont Score',
    'Cant Skate Wont Skate',
    'Cant Stop Wont Stop',
    'Cereal Killers',
    'Chiefs',
    'Chiefs 2',
    'Chiefs 3',
    'Chiefs 4',
    'Chieftains',
    'Choking Hazards',
    'Chupacabra',
    'CineLux Theatres',
    'Cobra Kai 1',
    'Cobra Kai 2',
    'Crabs',
    'Dangles',
    'Desert Dogs',
    'Destroyers',
    'Devcon HC',
    'Diablos',
    'Double Secret Probation',
    'Draggin Iceholes',
    'Dragons',
    'Dump and Chase',
    'Dung Beetle',
    'Dust HC',
    'Falcons',
    'Fighting Icecocks 2',
    'Fighting Turtles',
    'Firebirds',
    'Flying Monkeys',
    'Flying Pandas',
    'Fremont Freeze',
    'French Toast',
    'Gang Green',
    'Goal Diggers',
    'Golden Seals',
    'Good Guys',
    'Goon and Friends',
    'Grizzlies',
    'Habs',
    'Hat Trick Swayze',
    'Hawks',
    'Hectors Bush Trimmers',
    'Hectors Pool Service',
    'Hooligans',
    'Ice Badgers',
    'Ice Breakers',
    'Ice Force',
    'Ice Holes',
    'Ice Monkeys',
    'Ice Pirates',
    'Icebreakers',
    'Irish Car Bombs',
    'Irish Car Bombs 2',
    'Irish Car Bombs 3',
    'Irish Car Bombs 4',
    'Jagr Bombs',
    'Jets',
    'Junkies',
    'K-Wings',
    'K-Wings Supreme',
    'Knights',
    'Leftovers',
    'Lumberjacks',
    'Marauders',
    'Mermen',
    'Mermen Too',
    'Mighty Drunks',
    'Misfits',
    'Money Shots',
    'Money Shots II',
    'Moose',
    'Mucho Macho Muchachos',
    'Net Minders',
    'Night Hawks 2',
    'Night Hawks 3',
    'No Regretzkys',
    'Norcal Crossover',
    'Norcal Crossover Batalion',
    'Norcal Leafs',
    'Nuggets',
    'NVIDIA',
    'Oakland Oaks',
    'Ogilthorpe',
    'OHC',
    'OHC 2',
    'Old Farts',
    'Pacific Predators',
    'Pager Flakes',
    'Palmer Pride',
    'Pied Sniper',
    'PileOns',
    'Pond Hoppy',
    'Possums',
    'Power Play Biz Tech',
    'Puck Hogs',
    'Puck Norris',
    'Puckaneers',
    'Purple Cobras',
    'Raccoons',
    'Rangers',
    'Ravens',
    'Rebel Scum 1',
    'Rebel Scum 2',
    'Rebel Scum 3',
    'Rebels',
    'Red Dogs',
    'Red Dragons',
    'Red Hawks',
    'Red Wings',
    'Rink Rats',
    'Rogue Squadron',
    'Royals 1',
    'Royals 2',
    'Royals 3',
    'San Jose Barons',
    'San Jose Yetis',
    'Saved By The Goal',
    'Scarebears',
    'Schrute Farms',
    'Screaming Eagles',
    'Seal Team Sticks',
    'Seal Team Sticks 2',
    'Seal Team Sticks 3',
    'Shocker',
    'Silicon Valley Skaters',
    'Slap Shots',
    'Southsiders',
    'Stampede',
    'Stiflers Mom 1',
    'Swashpucklers',
    'Taquieria Con Carne',
    'Team America',
    'Team Beer',
    'The Fruit Company',
    'The Fruit Company 2',
    'The Nightmen',
    'Thresher Sharks',
    'Thresher Sharks 2',
    'Time Lords',
    'Time to Score',
    'Trash Pandas',
    'Tsunami',
    'Tyrannosaurs',
    'Unhealthy Scratch',
    'Weekend Warriors',
    'Whiskey Richards',
    'Winterhawks',
    'Wolverines 1',
    'Yavin 4 Rebels',
    'Zamboni Drivers',
  ];
}
