import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';

import '../models/locker_assignment.dart';
import 'preferences_service.dart';
import 'timetoscore_parser.dart';

const String kBackgroundRefreshTask = 'com.sharksice.lockerwidget.refreshTask';
const String kAppGroupId = 'group.com.sharksice.lockerwidget';
const String kIOSWidgetName = 'LockerRoomWidget';
const String kAndroidWidgetName = 'LockerRoomWidgetProvider';

/// Top-level entrypoint invoked by Workmanager for periodic background widget updates.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final syncService = WidgetSyncService();
      await syncService.refreshAndSyncWidget();
      return true;
    } catch (_) {
      return false;
    }
  });
}

/// Synchronizes current-day games and locker room assignments to the native
/// iOS WidgetKit and Android AppWidget extensions.
class WidgetSyncService {
  WidgetSyncService({
    PreferencesService? preferencesService,
    TimeToScoreParser? parser,
  })  : _prefs = preferencesService ?? PreferencesService(),
        _parser = parser ?? TimeToScoreParser();

  final PreferencesService _prefs;
  final TimeToScoreParser _parser;

  /// Initializes HomeWidget app group and schedules periodic 30-minute background checks.
  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(kAppGroupId);
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        'sharks_ice_lr_periodic_sync',
        kBackgroundRefreshTask,
        frequency: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (_) {
      // Safe fallback when running in environments without native plugin bindings (e.g. unit tests)
    }
  }

  /// Fetches today's games for enabled facilities, filters for the user's selected teams,
  /// caches the result, and pushes the updated payload to iOS and Android home screen widgets.
  Future<WidgetSyncResult> refreshAndSyncWidget() async {
    final facilities = await _prefs.getEnabledFacilities();
    final selectedTeams = await _prefs.getSelectedTeams();

    List<GameLockerAssignment> allTodayGames = await _parser.fetchTodayAssignments(
      facilities: facilities,
    );

    if (allTodayGames.isNotEmpty) {
      await _prefs.cacheTodayGames(allTodayGames);
      // Merge any newly seen team names into our known teams cache
      final seenTeams = <String>{
        for (final g in allTodayGames) ...[g.awayTeam, g.homeTeam],
      };
      await _prefs.mergeKnownTeams(seenTeams);
    } else {
      // Fall back to cached games from earlier today if offline
      final cached = await _prefs.getCachedTodayGames();
      allTodayGames =
          cached.where((g) => facilities.contains(g.facility)).toList();
    }

    final myGames = <UserGameView>[
      for (final game in allTodayGames) ...game.toUserGameViews(selectedTeams),
    ];

    await pushToNativeWidgets(
      myGames: myGames,
      selectedTeams: selectedTeams,
      enabledFacilities: facilities,
    );

    return WidgetSyncResult(
      allFacilityGamesToday: allTodayGames,
      myGamesToday: myGames,
      selectedTeams: selectedTeams,
      enabledFacilities: facilities,
      syncedAt: DateTime.now(),
    );
  }

  /// Writes key-value data to `HomeWidget` shared storage and requests a native timeline reload.
  Future<void> pushToNativeWidgets({
    required List<UserGameView> myGames,
    required List<String> selectedTeams,
    required Set<SharksIceFacility> enabledFacilities,
  }) async {
    String primaryLockerRoom = '—';
    String headlineText = 'No Games Today';
    String gameTimeBadge = '';
    String jerseyBadge = '';
    bool isHomeGame = true;

    if (myGames.isNotEmpty) {
      final first = myGames.first;
      primaryLockerRoom = first.myLockerRoom;
      gameTimeBadge = first.startTime;
      jerseyBadge = first.jerseyColor;
      isHomeGame = first.isHome;
      headlineText = first.myTeam;
    }

    try {
      await HomeWidget.saveWidgetData<String>(
        'user_games_json',
        UserGameView.encodeList(myGames),
      );
      await HomeWidget.saveWidgetData<int>(
        'selected_teams_count',
        selectedTeams.length,
      );
      await HomeWidget.saveWidgetData<int>('my_games_count', myGames.length);
      await HomeWidget.saveWidgetData<String>(
        'primary_locker_room',
        primaryLockerRoom,
      );
      await HomeWidget.saveWidgetData<String>('headline_text', headlineText);
      await HomeWidget.saveWidgetData<String>('game_time_badge', gameTimeBadge);
      await HomeWidget.saveWidgetData<String>('jersey_badge', jerseyBadge);
      await HomeWidget.saveWidgetData<bool>('is_home_game', isHomeGame);

      await HomeWidget.updateWidget(
        name: kAndroidWidgetName,
        iOSName: kIOSWidgetName,
        qualifiedAndroidName:
            'com.sharksice.sharks_ice_locker_widget.$kAndroidWidgetName',
      );
    } catch (_) {
      // Safe no-op on non-device test runs
    }
  }
}

class WidgetSyncResult {
  const WidgetSyncResult({
    required this.allFacilityGamesToday,
    required this.myGamesToday,
    required this.selectedTeams,
    required this.enabledFacilities,
    required this.syncedAt,
  });

  final List<GameLockerAssignment> allFacilityGamesToday;
  final List<UserGameView> myGamesToday;
  final List<String> selectedTeams;
  final Set<SharksIceFacility> enabledFacilities;
  final DateTime syncedAt;
}
