// lib/screens/filter_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import 'project_detail_screen.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  Set<ProjectSection> _selectedSections = {};
  DateTimeRange? _selectedDateRange;
  bool _hasStatusUpdates = false;
  List<Project> _filteredProjects = [];
  bool _showFilters = true;

  @override
  void initState() {
    super.initState();
    _applyFilters();
  }

  void _applyFilters() {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final allProjects = provider.projects;

    var filtered = allProjects.toList();

    // Filter by sections
    if (_selectedSections.isNotEmpty) {
      filtered = filtered
          .where((p) => _selectedSections.contains(p.section))
          .toList();
    }

    // Filter by date range
    if (_selectedDateRange != null) {
      filtered = filtered.where((p) {
        return p.createdAt.isAfter(_selectedDateRange!.start) &&
            p.createdAt.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    // Filter by status updates
    if (_hasStatusUpdates) {
      filtered = filtered.where((p) => p.statusHistory.isNotEmpty).toList();
    }

    setState(() => _filteredProjects = filtered);
  }

  void _clearFilters() {
    setState(() {
      _selectedSections.clear();
      _selectedDateRange = null;
      _hasStatusUpdates = false;
    });
    _applyFilters();
  }

  Color _getSectionColor(ProjectSection section) {
    switch (section) {
      case ProjectSection.inbox:
        return const Color(0xFF7C3AED);
      case ProjectSection.preparing:
        return const Color(0xFFF59E0B);
      case ProjectSection.processing:
        return const Color(0xFF3B82F6);
      case ProjectSection.working:
        return const Color(0xFF10B981);
      case ProjectSection.parked:
        return const Color(0xFFEF4444);
      case ProjectSection.completed:
        return const Color(0xFF6366F1);
    }
  }

  IconData _getSectionIcon(ProjectSection section) {
    switch (section) {
      case ProjectSection.inbox:
        return Icons.inbox_rounded;
      case ProjectSection.preparing:
        return Icons.build_circle_rounded;
      case ProjectSection.processing:
        return Icons.loop_rounded;
      case ProjectSection.working:
        return Icons.engineering_rounded;
      case ProjectSection.parked:
        return Icons.pause_circle_rounded;
      case ProjectSection.completed:
        return Icons.check_circle_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilters =
        _selectedSections.isNotEmpty ||
        _selectedDateRange != null ||
        _hasStatusUpdates;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Filter Projects'),
        actions: [
          if (hasActiveFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear All'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Results summary bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_filteredProjects.length} projects found',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_list_off : Icons.filter_list,
                    color: const Color(0xFF7C3AED),
                  ),
                  onPressed: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: _showFilters ? _buildFilterView() : _buildResultsView(),
          ),
        ],
      ),
      // Apply button at bottom when filters are shown
      bottomNavigationBar: _showFilters
          ? Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _showFilters = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Results',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildFilterView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionFilters(),
          const SizedBox(height: 24),
          _buildDateRangeFilter(),
          const SizedBox(height: 24),
          _buildAdditionalFilters(),
          const SizedBox(height: 80), // Space for bottom button
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    if (_filteredProjects.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredProjects.length,
      itemBuilder: (context, index) {
        return _buildProjectItem(_filteredProjects[index]);
      },
    );
  }

  Widget _buildSectionFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sections',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProjectSection.values.map((section) {
              final color = _getSectionColor(section);
              final isSelected = _selectedSections.contains(section);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedSections.remove(section);
                    } else {
                      _selectedSections.add(section);
                    }
                  });
                  _applyFilters();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.1)
                        : Colors.grey.shade100,
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getSectionIcon(section),
                        color: isSelected ? color : Colors.grey.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        section.toString().split('.').last.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? color : Colors.grey.shade700,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _selectedDateRange,
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Color(0xFF7C3AED),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                setState(() => _selectedDateRange = picked);
                _applyFilters();
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range, color: Colors.grey.shade600),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedDateRange != null
                          ? '${DateFormat('MMM d').format(_selectedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_selectedDateRange!.end)}'
                          : 'Select date range',
                      style: TextStyle(
                        color: _selectedDateRange != null
                            ? Colors.grey.shade900
                            : Colors.grey.shade600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (_selectedDateRange != null)
                    GestureDetector(
                      onTap: () {
                        setState(() => _selectedDateRange = null);
                        _applyFilters();
                      },
                      child: Icon(
                        Icons.clear,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Additional Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              setState(() => _hasStatusUpdates = !_hasStatusUpdates);
              _applyFilters();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _hasStatusUpdates,
                      onChanged: (value) {
                        setState(() => _hasStatusUpdates = value ?? false);
                        _applyFilters();
                      },
                      activeColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Has status updates',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Show only projects with history',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectItem(Project project) {
    final sectionColor = _getSectionColor(project.section);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectDetailScreen(project: project),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: sectionColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sectionColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          project.section
                              .toString()
                              .split('.')
                              .last
                              .toUpperCase(),
                          style: TextStyle(
                            color: sectionColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy').format(project.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (project.statusHistory.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(
                          Icons.history,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${project.statusHistory.length} updates',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.filter_list_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No projects match your filters',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                setState(() => _showFilters = true);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7C3AED)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Adjust Filters',
                style: TextStyle(color: Color(0xFF7C3AED)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
