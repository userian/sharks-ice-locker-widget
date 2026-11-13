import 'dart:convert';

/// Supported Sharks Ice / TimeToScore facilities that the user can toggle on or off.
enum SharksIceFacility {
  sanJose(
    id: 'san_jose',
    name: 'Sharks Ice at San Jose',
    shortName: 'Sharks Ice (San Jose)',
    lrAssignmentsUrl:
        'https://stats.sharksice.timetoscore.com/display-lr-assignments.php',
    statsUrl: 'https://stats.sharksice.timetoscore.com/display-stats.php?league=1',
    knownRinkKeywords: [
      'san jose',
      'north',
      'south',
      'east',
      'center',
      'west',
      'tech cu',
      'sharks',
      'orange',
      'black',
      'grey',
      'white',
      'teal',
    ],
  ),
  fremont(
    id: 'fremont',
    name: 'Sharks Ice at Fremont',
    shortName: 'Sharks Ice (Fremont)',
    lrAssignmentsUrl:
        'https://stats.sharksice.timetoscore.com/display-lr-assignments.php',
    statsUrl: 'https://stats.sharksice.timetoscore.com/display-stats.php?league=21',
    knownRinkKeywords: [
      'fremont',
    ],
  ),
  oakland(
    id: 'oakland',
    name: 'Oakland Ice Center',
    shortName: 'Oakland Ice',
    lrAssignmentsUrl:
        'https://stats.oaklandice.timetoscore.com/display-lr-assignments.php',
    statsUrl:
        'https://stats.oaklandice.timetoscore.com/display-stats.php?league=1',
    knownRinkKeywords: [
      'oakland',
      'nhl',
      'olympic',
    ],
  );

  const SharksIceFacility({
    required this.id,
    required this.name,
    required this.shortName,
    required this.lrAssignmentsUrl,
    required this.statsUrl,
    required this.knownRinkKeywords,
  });

  final String id;
  final String name;
  final String shortName;
  final String lrAssignmentsUrl;
  final String statsUrl;
  final List<String> knownRinkKeywords;

  static SharksIceFacility fromId(String id) {
    return SharksIceFacility.values.firstWhere(
      (f) => f.id == id,
      orElse: () => SharksIceFacility.sanJose,
    );
  }
}

/// Raw game and locker room assignment row parsed from display-lr-assignments.php.
class GameLockerAssignment {
  const GameLockerAssignment({
    required this.facility,
    required this.dateLabel,
    required this.startTime,
    required this.rink,
    required this.division,
    required this.awayTeam,
    required this.awayLockerRoom,
    required this.homeTeam,
    required this.homeLockerRoom,
    this.gameId,
  });

  final SharksIceFacility facility;
  final String dateLabel;
  final String startTime;
  final String rink;
  final String division;
  final String awayTeam;
  final String awayLockerRoom;
  final String homeTeam;
  final String homeLockerRoom;
  final String? gameId;

  /// Checks if either homeTeam or awayTeam matches any of [selectedTeams] (case-insensitive).
  bool involvesAnyTeam(Iterable<String> selectedTeams) {
    final normalizedSelected =
        selectedTeams.map(_normalizeTeamName).where((t) => t.isNotEmpty).toSet();
    if (normalizedSelected.isEmpty) return false;
    final awayNorm = _normalizeTeamName(awayTeam);
    final homeNorm = _normalizeTeamName(homeTeam);
    return normalizedSelected.contains(awayNorm) ||
        normalizedSelected.contains(homeNorm);
  }

  /// Converts this raw game row into one or more [UserGameView] items for the user's matched team(s).
  List<UserGameView> toUserGameViews(Iterable<String> selectedTeams) {
    final normalizedSelected =
        selectedTeams.map(_normalizeTeamName).where((t) => t.isNotEmpty).toSet();
    final results = <UserGameView>[];

    final awayNorm = _normalizeTeamName(awayTeam);
    final homeNorm = _normalizeTeamName(homeTeam);

    if (normalizedSelected.contains(awayNorm)) {
      results.add(
        UserGameView(
          myTeam: awayTeam,
          opponentTeam: homeTeam,
          isHome: false,
          myLockerRoom: awayLockerRoom.isEmpty ? 'TBD' : awayLockerRoom,
          opponentLockerRoom: homeLockerRoom.isEmpty ? 'TBD' : homeLockerRoom,
          facilityId: facility.id,
          facilityName: facility.shortName,
          rink: rink,
          startTime: startTime,
          dateLabel: dateLabel,
          division: division,
        ),
      );
    }

    if (normalizedSelected.contains(homeNorm)) {
      results.add(
        UserGameView(
          myTeam: homeTeam,
          opponentTeam: awayTeam,
          isHome: true,
          myLockerRoom: homeLockerRoom.isEmpty ? 'TBD' : homeLockerRoom,
          opponentLockerRoom: awayLockerRoom.isEmpty ? 'TBD' : awayLockerRoom,
          facilityId: facility.id,
          facilityName: facility.shortName,
          rink: rink,
          startTime: startTime,
          dateLabel: dateLabel,
          division: division,
        ),
      );
    }

    return results;
  }

  static String _normalizeTeamName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic> toJson() => {
        'facility': facility.id,
        'dateLabel': dateLabel,
        'startTime': startTime,
        'rink': rink,
        'division': division,
        'awayTeam': awayTeam,
        'awayLockerRoom': awayLockerRoom,
        'homeTeam': homeTeam,
        'homeLockerRoom': homeLockerRoom,
        'gameId': gameId,
      };

  factory GameLockerAssignment.fromJson(Map<String, dynamic> json) {
    return GameLockerAssignment(
      facility: SharksIceFacility.fromId(json['facility'] as String? ?? 'san_jose'),
      dateLabel: json['dateLabel'] as String? ?? 'Today',
      startTime: json['startTime'] as String? ?? '',
      rink: json['rink'] as String? ?? '',
      division: json['division'] as String? ?? '',
      awayTeam: json['awayTeam'] as String? ?? '',
      awayLockerRoom: json['awayLockerRoom'] as String? ?? '',
      homeTeam: json['homeTeam'] as String? ?? '',
      homeLockerRoom: json['homeLockerRoom'] as String? ?? '',
      gameId: json['gameId'] as String?,
    );
  }
}

/// Player-centric view of a game today, serialized directly to the iOS WidgetKit
/// and Android AppWidget extensions via `home_widget`.
class UserGameView {
  const UserGameView({
    required this.myTeam,
    required this.opponentTeam,
    required this.isHome,
    required this.myLockerRoom,
    required this.opponentLockerRoom,
    required this.facilityId,
    required this.facilityName,
    required this.rink,
    required this.startTime,
    required this.dateLabel,
    required this.division,
  });

  final String myTeam;
  final String opponentTeam;
  final bool isHome;
  final String myLockerRoom;
  final String opponentLockerRoom;
  final String facilityId;
  final String facilityName;
  final String rink;
  final String startTime;
  final String dateLabel;
  final String division;

  /// SIAHL jersey rule: Home wears White, Away wears Dark.
  String get jerseyColor => isHome ? 'White' : 'Dark';

  /// Compact badge label for widgets and cards.
  String get jerseyBadge => isHome ? 'White' : 'Dark';

  Map<String, dynamic> toJson() => {
        'myTeam': myTeam,
        'opponentTeam': opponentTeam,
        'isHome': isHome,
        'jerseyColor': jerseyColor,
        'myLockerRoom': myLockerRoom,
        'opponentLockerRoom': opponentLockerRoom,
        'facilityId': facilityId,
        'facilityName': facilityName,
        'rink': rink,
        'startTime': startTime,
        'dateLabel': dateLabel,
        'division': division,
      };

  factory UserGameView.fromJson(Map<String, dynamic> json) {
    return UserGameView(
      myTeam: json['myTeam'] as String? ?? '',
      opponentTeam: json['opponentTeam'] as String? ?? '',
      isHome: json['isHome'] as bool? ?? false,
      myLockerRoom: json['myLockerRoom'] as String? ?? 'TBD',
      opponentLockerRoom: json['opponentLockerRoom'] as String? ?? 'TBD',
      facilityId: json['facilityId'] as String? ?? 'san_jose',
      facilityName: json['facilityName'] as String? ?? 'San Jose',
      rink: json['rink'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      dateLabel: json['dateLabel'] as String? ?? 'Today',
      division: json['division'] as String? ?? '',
    );
  }

  static String encodeList(List<UserGameView> games) =>
      jsonEncode(games.map((g) => g.toJson()).toList());

  static List<UserGameView> decodeList(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return const [];
    final decoded = jsonDecode(rawJson) as List<dynamic>;
    return decoded
        .map((item) => UserGameView.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
