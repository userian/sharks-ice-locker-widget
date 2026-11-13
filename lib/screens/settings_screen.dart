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
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialSettings();
  }

  @override
  void dispose() {
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
      final liveTeams = await widget.parser.fetchAvailableTeams(
        facilities: _enabledFacilities,
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
      // Keep at least one facility selected
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
    await _refreshTeamsFromTimeToScore();
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

  @override
  Widget build(BuildContext context) {
    final filteredTeams = _availableTeams.where((team) {
      if (_searchQuery.trim().isEmpty) return true;
      return team.toLowerCase().contains(_searchQuery.trim().toLowerCase());
    }).toList();

    final exactSearchMatchExists = _searchQuery.trim().isNotEmpty &&
        _availableTeams.any(
          (t) => t.toLowerCase() == _searchQuery.trim().toLowerCase(),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget & Team Settings'),
        actions: [
          IconButton(
            tooltip: 'Sync teams from TimeToScore',
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
          // 1. Facilities Section
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHARKS ICE FACILITIES TO INCLUDE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: const Color(0xFF00788A),
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose which rinks the widget checks for today\'s locker room assignments.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
              ],
            ),
          ),
          const Divider(height: 20),

          // 2. Selected Teams Chips
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
                    padding: EdgeInsets.symmetric(vertical: 8),
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
          const SizedBox(height: 12),

          // 3. Search / Custom Add Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search SIAHL teams or type a custom team name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
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
                  vertical: 12,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          if (_searchQuery.trim().isNotEmpty && !exactSearchMatchExists)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: Text('Add "${_searchQuery.trim()}" to My Teams'),
                onPressed: () {
                  final customTeam = _searchQuery.trim();
                  _toggleTeam(customTeam);
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
            ),

          const SizedBox(height: 8),

          // 4. Scrollable Team Checklist
          Expanded(
            child: ListView.separated(
              itemCount: filteredTeams.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final team = filteredTeams[index];
                final isSelected = _isTeamSelected(team);
                return CheckboxListTile(
                  value: isSelected,
                  activeColor: const Color(0xFF00788A),
                  title: Text(
                    team,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
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
