// lib/screens/search_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import 'project_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Project> _searchResults = [];
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final allProjects = provider.projects;

    // Search in title and content
    final results = allProjects.where((project) {
      final titleMatch = project.title.toLowerCase().contains(
        query.toLowerCase(),
      );
      // For rich text content, we'll do a simple contains check
      final contentMatch = project.richTextContent.toLowerCase().contains(
        query.toLowerCase(),
      );
      return titleMatch || contentMatch;
    }).toList();

    setState(() => _searchResults = results);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: _performSearch,
          decoration: InputDecoration(
            hintText: 'Search projects...',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade600),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
          style: const TextStyle(fontSize: 16),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_isSearching) {
      return _buildEmptyState(
        icon: Icons.search,
        title: 'Search for projects',
        subtitle: 'Enter a keyword to search in titles and content',
      );
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No results found',
        subtitle: 'Try searching with different keywords',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final project = _searchResults[index];
        return _buildSearchResultItem(project);
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(Project project) {
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
                  // Highlight search query in title
                  if (_searchQuery.isNotEmpty)
                    _buildHighlightedText(project.title, _searchQuery),
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

  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return const SizedBox.shrink();

    final matches = RegExp(query, caseSensitive: false).allMatches(text);
    if (matches.isEmpty) return const SizedBox.shrink();

    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        children: _highlightOccurrences(text, query),
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  List<TextSpan> _highlightOccurrences(String source, String query) {
    if (query.isEmpty) return [TextSpan(text: source)];

    final matches = RegExp(query, caseSensitive: false).allMatches(source);

    if (matches.isEmpty) return [TextSpan(text: source)];

    final List<TextSpan> spans = [];
    int start = 0;

    for (final match in matches) {
      if (match.start != start) {
        spans.add(TextSpan(text: source.substring(start, match.start)));
      }

      spans.add(
        TextSpan(
          text: source.substring(match.start, match.end),
          style: const TextStyle(
            color: Color(0xFF7C3AED),
            fontWeight: FontWeight.bold,
            backgroundColor: Color(0xFFF3E8FF),
          ),
        ),
      );

      start = match.end;
    }

    if (start != source.length) {
      spans.add(TextSpan(text: source.substring(start)));
    }

    return spans;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
