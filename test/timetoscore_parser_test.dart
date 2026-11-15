import 'package:flutter_test/flutter_test.dart';
import 'package:sharks_ice_locker_widget/models/locker_assignment.dart';
import 'package:sharks_ice_locker_widget/services/timetoscore_parser.dart';

void main() {
  group('TimeToScoreParser.parseLrAssignmentsHtml', () {
    test('parses multi-facility tables and matches selected user teams', () {
      const sampleHtml = '''
      <html>
        <body>
          <h2>Solar4America Ice at San Jose - Thursday, Nov 12</h2>
          <table>
            <tr>
              <th>Time</th>
              <th>Rink</th>
              <th>Level</th>
              <th>Visitor</th>
              <th>LR</th>
              <th>Home</th>
              <th>LR</th>
            </tr>
            <tr>
              <td>7:45 PM</td>
              <td>White</td>
              <td>Adult Div 4</td>
              <td>Puck Norris</td>
              <td>W2</td>
              <td>Choking Hazards</td>
              <td>W4</td>
            </tr>
            <tr>
              <td>9:30 PM</td>
              <td>Orange</td>
              <td>Adult Div 2</td>
              <td>Seal Team Sticks</td>
              <td>1</td>
              <td>Golden Seals</td>
              <td>3</td>
            </tr>
          </table>

          <h2>Sharks Ice at Fremont</h2>
          <table>
            <tr>
              <th>Time</th>
              <th>Rink</th>
              <th>Division</th>
              <th>Away Team</th>
              <th>Away LR</th>
              <th>Home Team</th>
              <th>Home LR</th>
            </tr>
            <tr>
              <td>8:15 PM</td>
              <td>Fremont Rink</td>
              <td>Fremont Int B</td>
              <td>Fremont Freeze</td>
              <td>F1</td>
              <td>Choking Hazards</td>
              <td>F3</td>
            </tr>
          </table>
        </body>
      </html>
      ''';

      final parser = TimeToScoreParser();
      final games = parser.parseLrAssignmentsHtml(sampleHtml);

      expect(games.length, 3);
      expect(games[0].facility, SharksIceFacility.sanJose);
      expect(games[0].rink, 'White');
      expect(games[0].awayTeam, 'Puck Norris');
      expect(games[0].awayLockerRoom, 'W2');
      expect(games[0].homeTeam, 'Choking Hazards');
      expect(games[0].homeLockerRoom, 'W4');

      // Bare numbers "1" and "3" on Orange rink become "O1" and "O3"
      expect(games[1].awayLockerRoom, 'O1');
      expect(games[1].homeLockerRoom, 'O3');

      expect(games[2].facility, SharksIceFacility.fremont);
      expect(games[2].homeLockerRoom, 'F3');

      // Filter for "Choking Hazards" (Home) and "Puck Norris" (Away)
      final myViews = [
        for (final g in games)
          ...g.toUserGameViews(['Choking Hazards', 'Puck Norris']),
      ];
      expect(myViews.length, 3);

      // Game 0 Away: Puck Norris -> Dark jersey, W2
      expect(myViews[0].myTeam, 'Puck Norris');
      expect(myViews[0].isHome, isFalse);
      expect(myViews[0].jerseyColor, 'Dark');
      expect(myViews[0].jerseyBadge, 'Dark');
      expect(myViews[0].myLockerRoom, 'W2');

      // Game 0 Home: Choking Hazards -> White jersey, W4
      expect(myViews[1].myTeam, 'Choking Hazards');
      expect(myViews[1].isHome, isTrue);
      expect(myViews[1].jerseyColor, 'White');
      expect(myViews[1].jerseyBadge, 'White');
      expect(myViews[1].myLockerRoom, 'W4');
      expect(myViews[1].opponentTeam, 'Puck Norris');
    });

    test('parses all league teams from display-stats.php HTML', () {
      const statsHtml = '''
      <table>
        <tr><th colspan="100">Adult Division 8 West</th></tr>
        <tr><th colspan="100"><a href="display-league-stats?stat_class=1&league=1">Division Player Stats</a></th></tr>
        <tr><th>Team</th><th>GP</th><th>W</th><th>L</th><th>T</th><th>OTL</th><th>PTS</th></tr>
        <tr>
          <td><a href='display-schedule?team=3885&season=52&league=1&stat_class=1'>Scarebears </a></td>
          <td>5</td><td>5</td><td>0</td><td>0</td><td>0</td><td>10</td>
        </tr>
        <tr>
          <td><a href='display-schedule?team=4122&season=52&league=1&stat_class=1'>Irish Car Bombs 4 </a></td>
          <td>5</td><td>4</td><td>1</td><td>0</td><td>0</td><td>8</td>
        </tr>
      </table>
      ''';

      final parser = TimeToScoreParser();
      final teams = parser.parseTeamsFromStatsHtml(statsHtml);
      expect(teams, containsAll(['Scarebears', 'Irish Car Bombs 4']));
      expect(teams, isNot(contains('Division Player Stats')));
    });
  });
}
