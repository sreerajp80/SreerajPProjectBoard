// lib/screens/status_report_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/project_provider.dart';
import '../models/project_status_report.dart';
import '../database/database_helper.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class StatusReportScreen extends StatefulWidget {
  const StatusReportScreen({super.key});

  @override
  State<StatusReportScreen> createState() => _StatusReportScreenState();
}

class _StatusReportScreenState extends State<StatusReportScreen> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  List<ProjectStatusReport> _dailyReports = [];
  Map<String, int> _yearlyData = {};

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    final provider = Provider.of<ProjectProvider>(context, listen: false);
    final reports = await provider.getProjectStatusReports(
      _startDate,
      _endDate,
    );
    final yearData = await provider.getYearlyProjectData();

    setState(() {
      _dailyReports = reports;
      _yearlyData = yearData;
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF7C3AED)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Status Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _showExportImportDialog,
            tooltip: 'Export/Import Data',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDateRangeSelector(),
            const SizedBox(height: 24),
            _buildDailyStatusList(),
            const SizedBox(height: 32),
            _buildYearlyGraph(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.date_range, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Date Range',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                Text(
                  '${DateFormat('MMM d').format(_startDate)} - ${DateFormat('MMM d, yyyy').format(_endDate)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: const Text('Change'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyStatusList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Daily Project Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
              ),
            ),
          ),
          const Divider(height: 1),
          if (_dailyReports.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  'No project activity in this period',
                  style: TextStyle(color: Colors.grey.shade500),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dailyReports.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final report = _dailyReports[index];
                return _buildDailyReportItem(report);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDailyReportItem(ProjectStatusReport report) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            DateFormat('d').format(report.date),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7C3AED),
            ),
          ),
        ),
      ),
      title: Text(
        DateFormat('EEEE, MMMM d').format(report.date),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text('Total Projects: ${report.totalProjects}'),
          if (report.statusChanges > 0)
            Text(
              '${report.statusChanges} status changes',
              style: TextStyle(color: Colors.green.shade600),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: () {
          // Navigate to detailed day view
        },
      ),
    );
  }

  Widget _buildYearlyGraph() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Yearly Project Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: Colors.grey.shade200, strokeWidth: 1);
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final months = [
                          'J',
                          'F',
                          'M',
                          'A',
                          'M',
                          'J',
                          'J',
                          'A',
                          'S',
                          'O',
                          'N',
                          'D',
                        ];
                        return Text(
                          months[value.toInt() % 12],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getChartSpots(),
                    isCurved: true,
                    color: const Color(0xFF7C3AED),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
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

  List<FlSpot> _getChartSpots() {
    List<FlSpot> spots = [];
    for (int i = 0; i < 12; i++) {
      spots.add(
        FlSpot(i.toDouble(), (_yearlyData[i.toString()] ?? 0).toDouble()),
      );
    }
    return spots;
  }

  void _showExportImportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Database Management'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file, color: Color(0xFF7C3AED)),
              title: const Text('Export Database'),
              subtitle: const Text('Save database to device'),
              onTap: () {
                Navigator.pop(context);
                _exportDatabase();
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Color(0xFF10B981)),
              title: const Text('Import Database'),
              subtitle: const Text('Restore from backup'),
              onTap: () {
                Navigator.pop(context);
                _importDatabase();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFF3B82F6)),
              title: const Text('Share Database'),
              subtitle: const Text('Share with other devices'),
              onTap: () {
                Navigator.pop(context);
                _shareDatabase();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportDatabase() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final dbPath = await dbHelper.getDatabasePath();
      final dbFile = File(dbPath);

      final directory = await getExternalStorageDirectory();
      final backupDir = Directory('${directory!.path}/ProjectBackups');

      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final exportPath = '${backupDir.path}/backup_$timestamp.db';

      await dbFile.copy(exportPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Database exported to: ProjectBackups/backup_$timestamp.db',
            ),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () => Share.shareXFiles([XFile(exportPath)]),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importDatabase() async {
    try {
      // For Android, we'll use a different approach
      final directory = await getExternalStorageDirectory();
      final importDir = Directory('${directory!.path}/ProjectBackups');

      if (!await importDir.exists()) {
        await importDir.create(recursive: true);
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Database'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('To import a database backup:'),
              const SizedBox(height: 16),
              const Text('1. Place your backup .db file in:'),
              const SizedBox(height: 8),
              SelectableText(
                importDir.path,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 16),
              const Text('2. Name it: import_backup.db'),
              const SizedBox(height: 16),
              const Text('3. Click Import below'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performImport(importDir);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import setup failed: $e')));
      }
    }
  }

  Future<void> _performImport(Directory importDir) async {
    try {
      final importFile = File('${importDir.path}/import_backup.db');

      if (!await importFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No import file found. Place import_backup.db in the specified folder.',
              ),
            ),
          );
        }
        return;
      }

      final dbHelper = DatabaseHelper.instance;
      final dbPath = await dbHelper.getDatabasePath();

      // Close current database
      await dbHelper.close();

      // Copy import file to database location
      await importFile.copy(dbPath);

      // Delete the import file after successful import
      await importFile.delete();

      if (mounted) {
        // Reload projects
        Provider.of<ProjectProvider>(context, listen: false).loadProjects();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database imported successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _shareDatabase() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final dbPath = await dbHelper.getDatabasePath();

      await Share.shareXFiles(
        [XFile(dbPath)],
        subject: 'Project Database Backup',
        text:
            'Project database backup from ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Share failed: $e')));
      }
    }
  }
}
