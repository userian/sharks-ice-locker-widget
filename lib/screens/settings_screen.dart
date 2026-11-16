import 'package:flutter/material.dart';

import '../models/locker_assignment.dart';
import '../services/preferences_service.dart';
import '../services/timetoscore_parser.dart';
import '../services/widget_sync_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.preferencesService,
    required this.parser,
    required this.widgetSyncService,
  });

  final PreferencesService preferencesService;
  final TimeToScoreParser parser;
  final WidgetSyncService widgetSyncService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Set<SharksIceFacility> _enabledFacilities = {
    SharksIceFacility.sanJose,
    SharksIceFacility.fremont,
  };
  List<String> _selectedTeams = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final facilities = await widget.preferencesService.getEnabledFacilities();
    final selected = await widget.preferencesService.getSelectedTeams();
    if (!mounted) return;
    setState(() {
      _enabledFacilities = facilities;
      _selectedTeams = selected;
    });
  }

  Future<void> _toggleFacility(SharksIceFacility facility, bool enabled) async {
    final updated = Set<SharksIceFacility>.from(_enabledFacilities);
    if (enabled) {
      updated.add(facility);
    } else if (updated.length > 1) {
      updated.remove(facility);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keep at least one facility enabled.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _enabledFacilities = updated);
    await widget.preferencesService.setEnabledFacilities(updated);
    await widget.widgetSyncService.refreshAndSyncWidget();
  }

  Future<void> _removeTeam(String teamName) async {
    final updated = _selectedTeams
        .where((t) => t.toLowerCase() != teamName.toLowerCase())
        .toList();
    setState(() => _selectedTeams = updated);
    await widget.preferencesService.setSelectedTeams(updated);
    await widget.widgetSyncService.refreshAndSyncWidget();
  }

  Future<void> _clearAllTeams() async {
    setState(() => _selectedTeams = []);
    await widget.preferencesService.setSelectedTeams([]);
    await widget.widgetSyncService.refreshAndSyncWidget();
  }

  Future<void> _openAddTeamsPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddTeamsScreen(
          preferencesService: widget.preferencesService,
          parser: widget.parser,
          widgetSyncService: widget.widgetSyncService,
        ),
      ),
    );
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Facilities Section
          Text(
            'FACILITIES TO INCLUDE',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: const Color(0xFF005662),
                ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: SharksIceFacility.values.map((facility) {
                  final selected = _enabledFacilities.contains(facility);
                  return FilterChip(
                    label: Text(facility.name),
                    selected: selected,
                    selectedColor: const Color(0xFF00788A).withOpacity(0.18),
                    checkmarkColor: const Color(0xFF00788A),
                    onSelected: (val) => _toggleFacility(facility, val),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Button sitting directly above My Teams to open the Add Teams page
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D77),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _openAddTeamsPage,
              icon: const Icon(Icons.add),
              label: const Text(
                'Add Teams',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 3. My Teams Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MY TEAMS (${_selectedTeams.length})',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: const Color(0xFF005662),
                    ),
              ),
              if (_selectedTeams.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _clearAllTeams,
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (_selectedTeams.isEmpty)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No teams added yet. Tap "Add Teams" above to search and select your league teams.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _selectedTeams.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.sports_hockey,
                        color: Color(0xFF006D77),
                      ),
                      title: Text(
                        _selectedTeams[i],
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove team',
                        icon: const Icon(
                          Icons.close,
                          color: Colors.black54,
                        ),
                        onPressed: () => _removeTeam(_selectedTeams[i]),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Dedicated page for searching and adding teams, with the search input pinned
/// at the very top so matching league teams are always visible above the keyboard.
class AddTeamsScreen extends StatefulWidget {
  const AddTeamsScreen({
    super.key,
    required this.preferencesService,
    required this.parser,
    required this.widgetSyncService,
  });

  final PreferencesService preferencesService;
  final TimeToScoreParser parser;
  final WidgetSyncService widgetSyncService;

  @override
  State<AddTeamsScreen> createState() => _AddTeamsScreenState();
}

class _AddTeamsScreenState extends State<AddTeamsScreen> {
  List<String> _selectedTeams = [];
  List<String> _availableTeams = [];
  String _searchQuery = '';
  bool _isLoadingTeams = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialTeams();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialTeams() async {
    final selected = await widget.preferencesService.getSelectedTeams();
    final cachedTeams = await widget.preferencesService.getCachedKnownTeams();

    if (!mounted) return;
    setState(() {
      _selectedTeams = selected;
      _availableTeams = {...cachedTeams, ...selected}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });

    await _refreshTeamsFromTimeToScore();
  }

  Future<void> _refreshTeamsFromTimeToScore() async {
    setState(() => _isLoadingTeams = true);
    try {
      final liveTeams = await widget.parser.fetchAvailableTeams(
        facilities: SharksIceFacility.values.toSet(),
      );
      if (liveTeams.isNotEmpty) {
        await widget.preferencesService.mergeKnownTeams(liveTeams);
      }
      final merged = await widget.preferencesService.getCachedKnownTeams();
      if (!mounted) return;
      setState(() {
        _availableTeams = {...merged, ..._selectedTeams}.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingTeams = false);
      }
    }
  }

  Future<void> _toggleTeam(String teamName) async {
    final trimmed = teamName.trim();
    if (trimmed.isEmpty) return;

    final updated = List<String>.from(_selectedTeams);
    final existingIdx = updated.indexWhere(
      (t) => t.toLowerCase() == trimmed.toLowerCase(),
    );

    if (existingIdx >= 0) {
      updated.removeAt(existingIdx);
    } else {
      updated.add(trimmed);
    }

    setState(() {
      _selectedTeams = updated;
      if (!_availableTeams.any((t) => t.toLowerCase() == trimmed.toLowerCase())) {
        _availableTeams = [..._availableTeams, trimmed]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
    });

    await widget.preferencesService.setSelectedTeams(updated);
    await widget.preferencesService.mergeKnownTeams([trimmed]);
    await widget.widgetSyncService.refreshAndSyncWidget();
  }

  bool _isTeamSelected(String teamName) {
    final lower = teamName.toLowerCase();
    return _selectedTeams.any((t) => t.toLowerCase() == lower);
  }

  /// Normalizes words (including singular/plural `skulls` -> `skull` and `&` -> `and`)
  /// so searching "skulls and crosschecks" matches "Skull and CrossChecks".
  static List<String> _tokenizeNormalized(String input) {
    return input
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r"['’`.,\-_/]"), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) {
      if (w.length >= 4 && w.endsWith('s') && !w.endsWith('ss')) {
        return w.substring(0, w.length - 1);
      }
      return w;
    }).toList();
  }

  List<String> _getFilteredTeams() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _availableTeams;

    final queryTokens = _tokenizeNormalized(q);

    final startsWithMatches = <String>[];
    final containsMatches = <String>[];
    final tokenMatches = <String>[];

    for (final team in _availableTeams) {
      final lower = team.toLowerCase();
      if (lower.startsWith(q)) {
        startsWithMatches.add(team);
      } else if (lower.contains(q)) {
        containsMatches.add(team);
      } else if (queryTokens.isNotEmpty) {
        final teamTokens = _tokenizeNormalized(team);
        final allTokensMatch = queryTokens.every(
          (qt) => teamTokens.any((tt) => tt.contains(qt) || qt.contains(tt)),
        );
        if (allTokensMatch) {
          tokenMatches.add(team);
        }
      }
    }

    return [...startsWithMatches, ...containsMatches, ...tokenMatches];
  }

  Widget _buildHighlightedTeamTitle(String team, bool isSelected) {
    final query = _searchQuery.trim();
    final baseStyle = TextStyle(
      fontSize: 15,
      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
      color: Colors.black87,
    );

    if (query.isEmpty) {
      return Text(team, style: baseStyle);
    }

    final lowerTeam = team.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerTeam.indexOf(lowerQuery);
    if (matchIndex < 0) {
      return Text(team, style: baseStyle);
    }

    final before = team.substring(0, matchIndex);
    final match = team.substring(matchIndex, matchIndex + query.length);
    final after = team.substring(matchIndex + query.length);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF006D77),
              backgroundColor: const Color(0xFF00788A).withOpacity(0.15),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTeams = _getFilteredTeams();
    final trimmedQuery = _searchQuery.trim();
    final exactSearchMatchExists = trimmedQuery.isNotEmpty &&
        _availableTeams.any(
          (t) => t.toLowerCase() == trimmedQuery.toLowerCase(),
        );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF006D77),
        foregroundColor: Colors.white,
        title: const Text(
          'Add Teams',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Sync all league teams from TimeToScore',
            onPressed: _isLoadingTeams ? null : _refreshTeamsFromTimeToScore,
            icon: _isLoadingTeams
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar pinned at the very top of the page
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search league teams...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Live count bar right below search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    trimmedQuery.isEmpty
                        ? 'All League Teams (${_availableTeams.length})'
                        : 'Matching Teams (${filteredTeams.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
                if (_isLoadingTeams)
                  const Text(
                    'Syncing TimeToScore...',
                    style: TextStyle(fontSize: 12, color: Color(0xFF00788A)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Matching teams list directly under search (above the keyboard)
          Expanded(
            child: ListView.separated(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: filteredTeams.length +
                  (trimmedQuery.isNotEmpty && !exactSearchMatchExists ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index == filteredTeams.length) {
                  return ListTile(
                    leading: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFF006D77),
                    ),
                    title: Text(
                      'Add "$trimmedQuery" to My Teams',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF006D77),
                      ),
                    ),
                    onTap: () {
                      _toggleTeam(trimmedQuery);
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  );
                }

                final team = filteredTeams[index];
                final isSelected = _isTeamSelected(team);
                return CheckboxListTile(
                  dense: true,
                  value: isSelected,
                  activeColor: const Color(0xFF00788A),
                  title: _buildHighlightedTeamTitle(team, isSelected),
                  onChanged: (_) => _toggleTeam(team),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
