// lib/screens/project_editor_screen.dart
// This screen allows users to create or edit a project with rich text content.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../models/project.dart';
import '../providers/project_provider.dart';

class ProjectEditorScreen extends StatefulWidget {
  final Project? project;

  const ProjectEditorScreen({super.key, this.project});

  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  late TextEditingController _titleController;
  late QuillController _quillController;
  late ProjectSection _selectedSection;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.project?.title ?? '');
    _selectedSection = widget.project?.section ?? ProjectSection.inbox;
    _focusNode = FocusNode();

    if (widget.project != null && widget.project!.richTextContent.isNotEmpty) {
      final doc = Document.fromJson(
        jsonDecode(widget.project!.richTextContent),
      );
      _quillController = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      _quillController = QuillController.basic();
    }
  }

  void _saveProject() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a project title')),
      );
      return;
    }

    final richTextContent = jsonEncode(
      _quillController.document.toDelta().toJson(),
    );

    final provider = Provider.of<ProjectProvider>(context, listen: false);

    if (widget.project == null) {
      final newProject = Project(
        title: _titleController.text,
        richTextContent: richTextContent,
        section: _selectedSection,
      );
      provider.addProject(newProject);
    } else {
      final updatedProject = widget.project!.copyWith(
        title: _titleController.text,
        richTextContent: richTextContent,
        section: _selectedSection,
      );
      provider.updateProject(updatedProject);
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project == null ? 'New Project' : 'Edit Project'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProject),
        ],
      ),
      body: Column(
        children: [
          // Project title and section selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Project Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ProjectSection>(
                  value: _selectedSection,
                  decoration: const InputDecoration(
                    labelText: 'Section',
                    border: OutlineInputBorder(),
                  ),
                  items: ProjectSection.values.map((section) {
                    return DropdownMenuItem(
                      value: section,
                      child: Text(section.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSection = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          // Editor area - takes remaining space
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: QuillEditor.basic(
                controller: _quillController,
                focusNode: _focusNode,
              ),
            ),
          ),
          // Toolbar - fixed at bottom
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: QuillSimpleToolbar(controller: _quillController),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
