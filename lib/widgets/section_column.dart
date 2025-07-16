// lib/widgets/section_column.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import 'project_card.dart';

class SectionColumn extends StatelessWidget {
  final ProjectSection section;
  final List<Project> projects;
  final Function(String, ProjectSection) onProjectMoved;

  const SectionColumn({
    super.key,
    required this.section,
    required this.projects,
    required this.onProjectMoved,
  });

  Color get sectionColor {
    switch (section) {
      case ProjectSection.inbox:
        return const Color(0xFF7C3AED); // Soft purple
      case ProjectSection.preparing:
        return const Color(0xFFF59E0B); // Warm amber
      case ProjectSection.processing:
        return const Color(0xFF3B82F6); // Calm blue
      case ProjectSection.working:
        return const Color(0xFF10B981); // Fresh green
      case ProjectSection.parked:
        return const Color(0xFFEF4444); // Soft red
      case ProjectSection.completed:
        return const Color(0xFF6366F1); // Indigo
    }
  }

  Color get sectionBackgroundColor {
    switch (section) {
      case ProjectSection.inbox:
        return const Color(0xFFF3E8FF); // Light purple
      case ProjectSection.preparing:
        return const Color(0xFFFEF3C7); // Light amber
      case ProjectSection.processing:
        return const Color(0xFFDBEAFE); // Light blue
      case ProjectSection.working:
        return const Color(0xFFD1FAE5); // Light green
      case ProjectSection.parked:
        return const Color(0xFFFEE2E2); // Light red
      case ProjectSection.completed:
        return const Color(0xFFE0E7FF); // Light indigo
    }
  }

  String get sectionName {
    return section.toString().split('.').last.toUpperCase();
  }

  IconData get sectionIcon {
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
    return Container(
      width: 340,
      margin: const EdgeInsets.only(right: 20, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: sectionColor.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: sectionColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _buildProjectList(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sectionBackgroundColor.withOpacity(0.5),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
        border: Border(
          bottom: BorderSide(color: sectionColor.withOpacity(0.1), width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sectionColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(sectionIcon, color: sectionColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sectionName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: sectionColor.withOpacity(0.9),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${projects.length} ${projects.length == 1 ? 'project' : 'projects'}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: Icon(Icons.more_horiz, color: sectionColor.withOpacity(0.6)),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(BuildContext context) {
    return DragTarget<Map<String, dynamic>>(
      onWillAccept: (data) => true,
      onAccept: (data) {
        final projectId = data['projectId'] as String;
        final fromSection = data['section'] as ProjectSection;
        if (fromSection != section) {
          onProjectMoved(projectId, section);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty
                ? sectionColor.withOpacity(0.05)
                : Colors.transparent,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: candidateData.isNotEmpty
                ? Border.all(color: sectionColor.withOpacity(0.3), width: 2)
                : null,
          ),
          child: projects.isEmpty && candidateData.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: projects.length,
                  itemBuilder: (context, index) {
                    return Dismissible(
                      key: Key(projects[index].id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text('Delete Project'),
                              content: Text(
                                'Are you sure you want to delete "${projects[index].title}"?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      onDismissed: (direction) {
                        Provider.of<ProjectProvider>(
                          context,
                          listen: false,
                        ).deleteProject(projects[index].id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${projects[index].title} deleted'),
                            backgroundColor: Colors.red.shade600,
                            action: SnackBarAction(
                              label: 'UNDO',
                              textColor: Colors.white,
                              onPressed: () {
                                // You would need to implement an undo feature
                                // This would require storing the deleted project temporarily
                              },
                            ),
                          ),
                        );
                      },
                      child: ProjectCard(
                        project: projects[index],
                        sectionColor: sectionColor,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: sectionBackgroundColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 48,
                color: sectionColor.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No projects yet',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Drag projects here',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
