import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../models/locker_assignment.dart';

/// Fetches and parses today's locker room assignments and active league teams
/// from TimeToScore (`display-lr-assignments.php` and `display-stats.php`).
class TimeToScoreParser {
  TimeToScoreParser({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Fetches all current-day games and locker room assignments for the user's
  /// enabled [facilities].
  Future<List<GameLockerAssignment>> fetchTodayAssignments({
    required Set<SharksIceFacility> facilities,
  }) async {
    if (facilities.isEmpty) return const [];

    // Deduplicate URLs so San Jose + Fremont (which share stats.sharksice.timetoscore.com)
    // only require a single HTTP request.
    final urlToDefaultFacility = <String, SharksIceFacility>{};
    for (final facility in facilities) {
      urlToDefaultFacility.putIfAbsent(facility.lrAssignmentsUrl, () => facility);
    }

    final allGames = <GameLockerAssignment>[];

    for (final entry in urlToDefaultFacility.entries) {
      final url = entry.key;
      final defaultFacility = entry.value;
      try {
        final response = await _client
            .get(
              Uri.parse(url),
              headers: const {
                'Accept': 'text/html,application/xhtml+xml',
                'User-Agent': 'SharksIceLockerWidget/1.0',
              },
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200 && response.body.isNotEmpty) {
          final parsed = parseLrAssignmentsHtml(
            response.body,
            defaultFacility: defaultFacility,
          );
          allGames.addAll(
            parsed.where((game) => facilities.contains(game.facility)),
          );
        }
      } catch (_) {
        // Continue if one facility endpoint is temporarily unreachable.
      }
    }

    return allGames;
  }

  /// Parses raw HTML from `display-lr-assignments.php` into [GameLockerAssignment] items.
  List<GameLockerAssignment> parseLrAssignmentsHtml(
    String htmlContent, {
    SharksIceFacility defaultFacility = SharksIceFacility.sanJose,
  }) {
    final document = html_parser.parse(htmlContent);
    final assignments = <GameLockerAssignment>[];

    var currentFacility = defaultFacility;
    var currentDateLabel = 'Today';

    final tables = document.querySelectorAll('table');
    for (final table in tables) {
      // Check preceding heading or caption for facility/date context
      final contextText = _extractTableContextText(table);
      if (contextText.isNotEmpty) {
        currentFacility = _detectFacility(contextText, fallback: currentFacility);
      }

      final rows = table.querySelectorAll('tr');
      _ColumnMapping? columnMap;

      for (final row in rows) {
        final cells = row.children
            .where((el) => el.localName == 'th' || el.localName == 'td')
            .toList();
        if (cells.isEmpty) continue;

        final cellTexts =
            cells.map((c) => _cleanText(c.text)).toList(growable: false);

        // Single-cell banner row (often facility name, rink header, or date banner)
        if (cells.length == 1 ||
            (cells.length <= 2 &&
                (cells.first.attributes.containsKey('colspan') ||
                    row.querySelectorAll('th').isNotEmpty))) {
          final banner = cellTexts.join(' ').trim();
          if (banner.isNotEmpty) {
            currentFacility = _detectFacility(banner, fallback: currentFacility);
            if (_looksLikeDateBanner(banner)) {
              currentDateLabel = banner;
            }
          }
          continue;
        }

        // Check if this row is a column header row
        final detectedHeader = _tryParseHeaderRow(cellTexts);
        if (detectedHeader != null) {
          columnMap = detectedHeader;
          continue;
        }

        // Otherwise attempt to parse as a game + locker room row
        final effectiveMap =
            columnMap ?? _ColumnMapping.fallbackForLength(cellTexts.length);
        if (effectiveMap == null) continue;

        final assignment = _extractAssignmentFromRow(
          cellTexts,
          effectiveMap,
          currentFacility: currentFacility,
          currentDateLabel: currentDateLabel,
        );

        if (assignment != null) {
          assignments.add(assignment);
        }
      }
    }

    return assignments;
  }

  /// Fetches a sorted list of team names across the enabled [facilities] by combining
  /// teams from today's `display-lr-assignments.php` and the active season's
  /// `display-stats.php` standings pages.
  Future<List<String>> fetchAvailableTeams({
    required Set<SharksIceFacility> facilities,
  }) async {
    final teamNames = <String>{};

    // 1. Include all teams playing today on display-lr-assignments.php
    final todayGames = await fetchTodayAssignments(facilities: facilities);
    for (final game in todayGames) {
      if (game.awayTeam.isNotEmpty) teamNames.add(game.awayTeam);
      if (game.homeTeam.isNotEmpty) teamNames.add(game.homeTeam);
    }

    // 2. Also scrape team links from display-stats.php for each selected facility
    for (final facility in facilities) {
      try {
        final response = await _client
            .get(
              Uri.parse(facility.statsUrl),
              headers: const {'User-Agent': 'SharksIceLockerWidget/1.0'},
            )
            .timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          teamNames.addAll(parseTeamsFromStatsHtml(response.body));
        }
      } catch (_) {
        // Ignore network errors and rely on cached/today teams or manual entry
      }
    }

    final sorted = teamNames.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  /// Parses team names from `display-stats.php` (anchors linking to `display-schedule.php?team=`).
  List<String> parseTeamsFromStatsHtml(String htmlContent) {
    final document = html_parser.parse(htmlContent);
    final teams = <String>{};

    for (final anchor in document.querySelectorAll('a[href*="display-schedule.php"]')) {
      final name = _cleanText(anchor.text);
      if (name.isNotEmpty && !_isGenericHeader(name)) {
        teams.add(name);
      }
    }

    return teams.toList();
  }

  String _extractTableContextText(Element table) {
    final caption = table.querySelector('caption');
    if (caption != null && caption.text.trim().isNotEmpty) {
      return _cleanText(caption.text);
    }
    final prev = table.previousElementSibling;
    if (prev != null &&
        (prev.localName == 'h1' ||
            prev.localName == 'h2' ||
            prev.localName == 'h3' ||
            prev.localName == 'h4' ||
            prev.localName == 'div' ||
            prev.localName == 'p')) {
      return _cleanText(prev.text);
    }
    return '';
  }

  SharksIceFacility _detectFacility(
    String text, {
    required SharksIceFacility fallback,
  }) {
    final lower = text.toLowerCase();
    if (lower.contains('fremont')) {
      return SharksIceFacility.fremont;
    }
    if (lower.contains('oakland')) {
      return SharksIceFacility.oakland;
    }
    if (lower.contains('san jose') ||
        lower.contains('solar4america') ||
        lower.contains('tech cu')) {
      return SharksIceFacility.sanJose;
    }
    return fallback;
  }

  bool _looksLikeDateBanner(String text) {
    final lower = text.toLowerCase();
    const weekdays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
      'today',
    ];
    return weekdays.any(lower.contains) ||
        RegExp(r'\b\d{1,2}/\d{1,2}\b').hasMatch(lower);
  }

  _ColumnMapping? _tryParseHeaderRow(List<String> cells) {
    final lowerCells = cells.map((c) => c.toLowerCase()).toList();

    final hasTime = lowerCells.any((c) => c.contains('time') || c == 'start');
    final hasTeamCols = lowerCells.any(
      (c) =>
          c.contains('away') ||
          c.contains('visitor') ||
          c.contains('home') ||
          c.contains('team'),
    );

    if (!hasTime && !hasTeamCols) return null;

    int? dateCol;
    int? timeCol;
    int? rinkCol;
    int? divisionCol;
    int? awayTeamCol;
    int? awayLrCol;
    int? homeTeamCol;
    int? homeLrCol;

    final lrCols = <int>[];

    for (var i = 0; i < lowerCells.length; i++) {
      final col = lowerCells[i];
      if (dateCol == null && col.contains('date')) {
        dateCol = i;
      } else if (timeCol == null && (col.contains('time') || col == 'start')) {
        timeCol = i;
      } else if (rinkCol == null &&
          (col.contains('rink') || col.contains('surface') || col.contains('ice'))) {
        rinkCol = i;
      } else if (divisionCol == null &&
          (col.contains('level') ||
              col.contains('div') ||
              col.contains('league') ||
              col.contains('type'))) {
        divisionCol = i;
      } else if (awayTeamCol == null &&
          (col == 'away' ||
              col == 'visitor' ||
              col == 'visiting team' ||
              col == 'away team')) {
        awayTeamCol = i;
      } else if (homeTeamCol == null &&
          (col == 'home' || col == 'home team')) {
        homeTeamCol = i;
      } else if (col.contains('lr') ||
          col.contains('locker') ||
          col.contains('room') ||
          col.contains('dress')) {
        if (col.contains('away') || col.contains('vis')) {
          awayLrCol = i;
        } else if (col.contains('home')) {
          homeLrCol = i;
        } else {
          lrCols.add(i);
        }
      }
    }

    // Assign generic "LR" columns based on their position relative to Away and Home teams
    if (awayLrCol == null && lrCols.isNotEmpty) {
      awayLrCol = lrCols.first;
    }
    if (homeLrCol == null && lrCols.length >= 2) {
      homeLrCol = lrCols[1];
    }

    if (awayTeamCol == null || homeTeamCol == null) {
      return null;
    }

    return _ColumnMapping(
      dateCol: dateCol,
      timeCol: timeCol ?? 0,
      rinkCol: rinkCol,
      divisionCol: divisionCol,
      awayTeamCol: awayTeamCol,
      awayLrCol: awayLrCol,
      homeTeamCol: homeTeamCol,
      homeLrCol: homeLrCol,
    );
  }

  GameLockerAssignment? _extractAssignmentFromRow(
    List<String> cells,
    _ColumnMapping map, {
    required SharksIceFacility currentFacility,
    required String currentDateLabel,
  }) {
    String getCell(int? index) {
      if (index == null || index < 0 || index >= cells.length) return '';
      return cells[index].trim();
    }

    final startTime = getCell(map.timeCol);
    final awayTeam = getCell(map.awayTeamCol);
    final homeTeam = getCell(map.homeTeamCol);

    // Filter out non-game rows or repeated header rows
    if (awayTeam.isEmpty ||
        homeTeam.isEmpty ||
        _isGenericHeader(awayTeam) ||
        _isGenericHeader(homeTeam)) {
      return null;
    }

    // Require startTime to look like a time (e.g. "7:30 PM", "21:15", "10:00a")
    if (!RegExp(r'\d{1,2}:\d{2}').hasMatch(startTime)) {
      return null;
    }

    final rink = getCell(map.rinkCol);
    final division = getCell(map.divisionCol);
    final awayLr = _formatLockerRoomCode(getCell(map.awayLrCol), rink);
    final homeLr = _formatLockerRoomCode(getCell(map.homeLrCol), rink);
    final rowDate = getCell(map.dateCol);

    final facility = _detectFacility(
      '$rink $division',
      fallback: currentFacility,
    );

    return GameLockerAssignment(
      facility: facility,
      dateLabel: rowDate.isNotEmpty ? rowDate : currentDateLabel,
      startTime: startTime,
      rink: rink.isNotEmpty ? rink : facility.shortName,
      division: division,
      awayTeam: awayTeam,
      awayLockerRoom: awayLr,
      homeTeam: homeTeam,
      homeLockerRoom: homeLr,
    );
  }

  /// Preserves alphanumeric locker room codes like `W4`, `O2`, `B1`, `G3`,
  /// or prefixes the rink initial if the table cell only contains a bare digit (`4` + `White` -> `W4`).
  String _formatLockerRoomCode(String rawLr, String rink) {
    final cleaned = rawLr.trim();
    if (cleaned.isEmpty) return 'TBD';

    // If it already has a letter prefix (e.g. "W4", "O2", "B1", "G3"), keep it uppercase
    if (RegExp(r'^[A-Za-z]+\s*\d+$').hasMatch(cleaned)) {
      return cleaned.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    }

    // If it is just a number (e.g. "4") and the rink specifies White/Orange/Black/Grey/etc., prefix it
    if (RegExp(r'^\d+$').hasMatch(cleaned) && rink.trim().isNotEmpty) {
      final rinkLower = rink.toLowerCase();
      if (rinkLower.contains('white')) return 'W$cleaned';
      if (rinkLower.contains('orange')) return 'O$cleaned';
      if (rinkLower.contains('black')) return 'B$cleaned';
      if (rinkLower.contains('grey') || rinkLower.contains('gray')) {
        return 'G$cleaned';
      }
      if (rinkLower.contains('teal') || rinkLower.contains('tech')) {
        return 'T$cleaned';
      }
      if (rinkLower.contains('north')) return 'N$cleaned';
      if (rinkLower.contains('south')) return 'S$cleaned';
      if (rinkLower.contains('east')) return 'E$cleaned';
      if (rinkLower.contains('center')) return 'C$cleaned';
    }

    return cleaned;
  }

  bool _isGenericHeader(String value) {
    final lower = value.toLowerCase();
    return const {
      'away',
      'Away Team',
      'visitor',
      'home',
      'home team',
      'team',
      'time',
      'rink',
      'lr',
      'locker room',
    }.contains(lower);
  }

  String _cleanText(String input) {
    return input
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _ColumnMapping {
  const _ColumnMapping({
    this.dateCol,
    required this.timeCol,
    this.rinkCol,
    this.divisionCol,
    required this.awayTeamCol,
    this.awayLrCol,
    required this.homeTeamCol,
    this.homeLrCol,
  });

  final int? dateCol;
  final int timeCol;
  final int? rinkCol;
  final int? divisionCol;
  final int awayTeamCol;
  final int? awayLrCol;
  final int homeTeamCol;
  final int? homeLrCol;

  /// Fallback column layout when a table on `display-lr-assignments.php` omits `<th>` headers.
  static _ColumnMapping? fallbackForLength(int length) {
    // Common 7-column TimeToScore layout:
    // [Time, Rink, Division/Level, Away Team, Away LR, Home Team, Home LR]
    if (length == 7) {
      return const _ColumnMapping(
        timeCol: 0,
        rinkCol: 1,
        divisionCol: 2,
        awayTeamCol: 3,
        awayLrCol: 4,
        homeTeamCol: 5,
        homeLrCol: 6,
      );
    }
    // Common 8-column layout with Date first:
    // [Date, Time, Rink, Division, Away Team, Away LR, Home Team, Home LR]
    if (length >= 8) {
      return const _ColumnMapping(
        dateCol: 0,
        timeCol: 1,
        rinkCol: 2,
        divisionCol: 3,
        awayTeamCol: 4,
        awayLrCol: 5,
        homeTeamCol: 6,
        homeLrCol: 7,
      );
    }
    // Compact 6-column layout:
    // [Time, Rink, Away Team, Away LR, Home Team, Home LR]
    if (length == 6) {
      return const _ColumnMapping(
        timeCol: 0,
        rinkCol: 1,
        awayTeamCol: 2,
        awayLrCol: 3,
        homeTeamCol: 4,
        homeLrCol: 5,
      );
    }
    return null;
  }
}
