// lib/screens/modern_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../widgets/section_column.dart';
import 'project_editor_screen.dart';
import 'status_report_screen.dart';
import 'search_screen.dart';
import 'filter_screen.dart';

class ModernHomeScreen extends StatefulWidget {
  const ModernHomeScreen({super.key});

  @override
  State<ModernHomeScreen> createState() => _ModernHomeScreenState();
}

class _ModernHomeScreenState extends State<ModernHomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        Provider.of<ProjectProvider>(context, listen: false).loadProjects();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Project Board',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.grey.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
        actions: [
          // Menu buttons in a row with proper spacing
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeaderButton(
                icon: Icons.search,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                icon: Icons.filter_list,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FilterScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              _buildHeaderButton(
                icon: Icons.analytics,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StatusReportScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSubHeader(),
            Expanded(child: _buildKanbanBoard()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildSubHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Manage your projects with Kanban view',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to create consistent header buttons
  Widget _buildHeaderButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 40,
      width: 40,
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
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: Colors.grey.shade700,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildKanbanBoard() {
    return Consumer<ProjectProvider>(
      builder: (context, provider, child) {
        return PageView.builder(
          controller: PageController(
            viewportFraction: 0.9,
          ), // Slight peek effect
          itemCount: ProjectSection.values.length,
          itemBuilder: (context, index) {
            final section = ProjectSection.values[index];
            final projects = provider.getProjectsBySection(section);

            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                horizontalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SectionColumn(
                      section: section,
                      projects: projects,
                      onProjectMoved: (projectId, newSection) {
                        provider.moveProjectToSection(projectId, newSection);
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProjectEditorScreen()),
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('New Project'),
      foregroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
