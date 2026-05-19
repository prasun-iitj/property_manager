import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/team_member.dart';
import '../../services/team_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  final _team = TeamService();
  bool _runningBackup = false;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _runBackup() async {
    setState(() => _runningBackup = true);
    try {
      final result = await _team.runBackupNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup saved (${_formatBytes(result['sizeBytes'] as int? ?? 0)})',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _runningBackup = false);
    }
  }

  Future<void> _toggleSchedule(bool enabled) async {
    try {
      await _team.updateBackupSettings(enabled: enabled);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Daily cloud backup enabled (2:00 AM IST)'
                : 'Scheduled backup disabled',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Cloud backup'),
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<SystemConfig>(
        stream: _team.streamSystemConfig(),
        builder: (context, configSnap) {
          final config = configSnap.data ?? const SystemConfig();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cloud_upload, color: Color(0xFF0F766E)),
                              SizedBox(width: 10),
                              Text(
                                'Automatic backup',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Full Firestore export to Firebase Cloud Storage every day at 2:00 AM (India time).',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Scheduled backup'),
                            subtitle: Text(
                              config.backupEnabled
                                  ? 'Enabled'
                                  : 'Disabled',
                            ),
                            value: config.backupEnabled,
                            onChanged: _toggleSchedule,
                          ),
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.schedule),
                            title: const Text('Last backup'),
                            subtitle: Text(
                              config.lastBackupAt != null
                                  ? dateFmt.format(config.lastBackupAt!)
                                  : 'Not run yet',
                            ),
                          ),
                          if (config.lastBackupPath != null) ...[
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.folder_outlined),
                              title: const Text('Storage path'),
                              subtitle: Text(
                                config.lastBackupPath!,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                          if (config.lastBackupSizeBytes != null)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.data_usage),
                              title: const Text('Size'),
                              subtitle: Text(
                                _formatBytes(config.lastBackupSizeBytes!),
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _runningBackup ? null : _runBackup,
                              icon: _runningBackup
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.backup),
                              label: Text(
                                _runningBackup ? 'Backing up…' : 'Run backup now',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                minimumSize: const Size.fromHeight(48),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Recent backups',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              StreamBuilder<List<BackupRecord>>(
                stream: _team.streamBackupHistory(),
                builder: (context, snap) {
                  final records = snap.data ?? [];
                  if (records.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No backup history yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final r = records[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: ListTile(
                            leading: Icon(
                              r.status == 'completed'
                                  ? Icons.check_circle
                                  : Icons.error_outline,
                              color: r.status == 'completed'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              r.createdAt != null
                                  ? dateFmt.format(r.createdAt!)
                                  : r.id,
                            ),
                            subtitle: Text(
                              '${_formatBytes(r.sizeBytes)} · ${r.triggeredBy}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        );
                      },
                      childCount: records.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}
