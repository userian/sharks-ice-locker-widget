import 'package:flutter/material.dart';

import '../models/locker_assignment.dart';
import '../services/preferences_service.dart';
import '../services/timetoscore_parser.dart';
import '../services/widget_sync_service.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.preferencesService,
    required this.parser,
    required this.widgetSyncService,
  });

  final PreferencesService preferencesService;
  final TimeToScoreParser parser;
  final WidgetSyncService widgetSyncService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<UserGameView> _myGamesToday = const [];
  List<String> _selectedTeams = const [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.widgetSyncService.refreshAndSyncWidget();
      if (!mounted) return;
      setState(() {
        _myGamesToday = result.myGamesToday;
        _selectedTeams = result.selectedTeams;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          preferencesService: widget.preferencesService,
          parser: widget.parser,
          widgetSyncService: widget.widgetSyncService,
        ),
      ),
    );
    await _refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
        title: const Text(
          'Which Locker Room?',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _refreshData,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildWidgetPreviewCard(),
            const SizedBox(height: 20),
            Text(
              'MY GAMES TODAY',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: const Color(0xFF005662),
                  ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_selectedTeams.isEmpty)
              _buildEmptyTeamsPrompt()
            else if (_myGamesToday.isEmpty)
              _buildNoGamesTodayCard()
            else
              ..._myGamesToday.map(_buildMyGameCard),
          ],
        ),
      ),
    );
  }

  Widget _buildWidgetPreviewCard() {
    final firstGame = _myGamesToday.isNotEmpty ? _myGamesToday.first : null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF002F35), Color(0xFF006D77)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: firstGame == null
          ? Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'LR\n—',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'No Games Today',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                // 1. Locker Room
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB703),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'LR',
                        style: TextStyle(
                          color: Color(0xFF002F35),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        firstGame.myLockerRoom,
                        style: const TextStyle(
                          color: Color(0xFF002F35),
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // 2. Time + 3. Team Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstGame.startTime,
                        style: const TextStyle(
                          color: Color(0xFFFFB703),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        firstGame.myTeam,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // 4. Jersey with little icon (White vs Dark)
                _buildJerseyBadge(isWhiteJersey: firstGame.isHome),
              ],
            ),
    );
  }

  Widget _buildMyGameCard(UserGameView game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // 1. Locker Room
            Container(
              width: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF006D77),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'LR',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    game.myLockerRoom,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // 2. Time + 3. Team Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.startTime,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF006D77),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.myTeam,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // 4. Jersey with little icon (White vs Dark)
            _buildJerseyBadge(isWhiteJersey: game.isHome),
          ],
        ),
      ),
    );
  }

  Widget _buildJerseyBadge({required bool isWhiteJersey}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isWhiteJersey ? Colors.white : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWhiteJersey ? const Color(0xFFCBD5E1) : Colors.white24,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          JerseyIcon(isWhiteJersey: isWhiteJersey, size: 16),
          const SizedBox(width: 6),
          Text(
            isWhiteJersey ? 'White' : 'Dark',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isWhiteJersey ? const Color(0xFF0F172A) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTeamsPrompt() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.sports_hockey, size: 36, color: Color(0xFF006D77)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D77),
                foregroundColor: Colors.white,
              ),
              onPressed: _openSettings,
              icon: const Icon(Icons.add),
              label: const Text('Select Teams in Settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoGamesTodayCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No games today for your selected teams.',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }
}

/// Little hockey jersey icon rendered in either Light/White or Dark style.
class JerseyIcon extends StatelessWidget {
  const JerseyIcon({
    super.key,
    required this.isWhiteJersey,
    this.size = 16,
  });

  final bool isWhiteJersey;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _JerseyPainter(isWhiteJersey: isWhiteJersey),
    );
  }
}

class _JerseyPainter extends CustomPainter {
  const _JerseyPainter({required this.isWhiteJersey});

  final bool isWhiteJersey;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(w * 0.30, h * 0.12)
      ..lineTo(w * 0.05, h * 0.32)
      ..lineTo(w * 0.16, h * 0.50)
      ..lineTo(w * 0.26, h * 0.40)
      ..lineTo(w * 0.26, h * 0.90)
      ..lineTo(w * 0.74, h * 0.90)
      ..lineTo(w * 0.74, h * 0.40)
      ..lineTo(w * 0.84, h * 0.50)
      ..lineTo(w * 0.95, h * 0.32)
      ..lineTo(w * 0.70, h * 0.12)
      ..quadraticBezierTo(w * 0.50, h * 0.26, w * 0.30, h * 0.12)
      ..close();

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = isWhiteJersey ? Colors.white : const Color(0xFF0F172A);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..color = isWhiteJersey ? const Color(0xFF0F172A) : Colors.white;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _JerseyPainter oldDelegate) =>
      oldDelegate.isWhiteJersey != isWhiteJersey;
}
