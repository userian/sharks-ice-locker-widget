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
  List<String> _availableTeams = [];
  String _searchQuery = '';
  bool _isLoadingTeams = false;
  bool _isSearchFocused = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleSearchFocusChange);
    _loadInitialSettings();
  }

  void _handleSearchFocusChange() {
    if (!mounted) return;
    setState(() {
      _isSearchFocused = _searchFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleSearchFocusChange);
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSettings() async {
    final facilities = await widget.preferencesService.getEnabledFacilities();
    final selected = await widget.preferencesService.getSelectedTeams();
    final cachedTeams = await widget.preferencesService.getCachedKnownTeams();

    if (!mounted) return;
    setState(() {
      _enabledFacilities = facilities;
      _selectedTeams = selected;
      _availableTeams = {...cachedTeams, ...selected}.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    });

    await _refreshTeamsFromTimeToScore();
  }

  Future<void> _refreshTeamsFromTimeToScore() async {
    if (_enabledFacilities.isEmpty) return;
    setState(() => _isLoadingTeams = true);
    try {
      // Fetch all teams across all leagues at the enabled facilities (plus all Sharks Ice leagues)
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

  List<String> _getFilteredTeams() {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _availableTeams;

    final startsWithMatches = <String>[];
    final containsMatches = <String>[];

    for (final team in _availableTeams) {
      final lower = team.toLowerCase();
      if (lower.startsWith(q)) {
        startsWithMatches.add(team);
      } else if (lower.contains(q)) {
        containsMatches.add(team);
      }
    }

    return [...startsWithMatches, ...containsMatches];
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

    // Collapse top sections when keyboard/search is active so matching teams
    // are immediately visible above the keyboard as you type.
    final isSearching = _isSearchFocused || trimmedQuery.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Widget & Team Settings'),
        actions: [
          if (isSearching)
            TextButton(
              onPressed: () {
                _searchFocusNode.unfocus();
              },
              child: const Text(
                'Done',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          IconButton(
            tooltip: 'Sync all league teams from TimeToScore',
            onPressed: _isLoadingTeams ? null : _refreshTeamsFromTimeToScore,
            icon: _isLoadingTeams
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Search Bar at the very top when searching (or below compact header when idle)
          if (!isSearching) ...[
            // Facilities Section
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FACILITIES TO INCLUDE',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: const Color(0xFF00788A),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: SharksIceFacility.values.map((facility) {
                      final selected = _enabledFacilities.contains(facility);
                      return FilterChip(
                        label: Text(facility.name),
                        selected: selected,
                        selectedColor:
                            const Color(0xFF00788A).withOpacity(0.18),
                        checkmarkColor: const Color(0xFF00788A),
                        onSelected: (val) => _toggleFacility(facility, val),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),

            // Selected Teams Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MY TEAMS (${_selectedTeams.length})',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: const Color(0xFF00788A),
                            ),
                      ),
                      if (_selectedTeams.isNotEmpty)
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            setState(() => _selectedTeams = []);
                            await widget.preferencesService.setSelectedTeams([]);
                            await widget.widgetSyncService.refreshAndSyncWidget();
                          },
                          child: const Text('Clear All'),
                        ),
                    ],
                  ),
                  if (_selectedTeams.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'No teams selected yet. Search or check your team(s) below.',
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _selectedTeams.map((team) {
                        return InputChip(
                          label: Text(
                            team,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor:
                              const Color(0xFF00788A).withOpacity(0.14),
                          deleteIconColor: const Color(0xFF005662),
                          onDeleted: () => _toggleTeam(team),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Search Box (always pinned near top so results below it are never hidden by keyboard)
          Padding(
            padding: EdgeInsets.fromLTRB(16, isSearching ? 10 : 0, 16, 4),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText:
                    'Search all ${_availableTeams.length} league teams...',
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

          // Live count / custom team add bar right below search
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
                    'Updating from TimeToScore...',
                    style: TextStyle(fontSize: 12, color: Color(0xFF00788A)),
                  ),
              ],
            ),
          ),

          // Scrollable Team Checklist (immediately visible above keyboard)
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
