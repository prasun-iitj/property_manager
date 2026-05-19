import 'package:cloud_firestore/cloud_firestore.dart';

class TeamMember {
  final String uid;
  final String email;
  final String name;
  final String role;
  final bool disabled;
  final bool isSuperAdmin;

  const TeamMember({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.disabled = false,
    this.isSuperAdmin = false,
  });

  factory TeamMember.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TeamMember(
      uid: doc.id,
      email: (data['email'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      role: (data['role'] ?? 'staff').toString(),
      disabled: data['disabled'] == true,
      isSuperAdmin: data['isSuperAdmin'] == true,
    );
  }
}

class SystemConfig {
  final String? superAdminOtpEmail;
  final String? superAdminUid;
  final bool backupEnabled;
  final DateTime? lastBackupAt;
  final String? lastBackupPath;
  final int? lastBackupSizeBytes;

  const SystemConfig({
    this.superAdminOtpEmail,
    this.superAdminUid,
    this.backupEnabled = true,
    this.lastBackupAt,
    this.lastBackupPath,
    this.lastBackupSizeBytes,
  });

  factory SystemConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const SystemConfig();
    final last = data['lastBackupAt'];
    final email = data['superAdminOtpEmail']?.toString() ??
        data['superAdminEmail']?.toString();
    return SystemConfig(
      superAdminOtpEmail: email,
      superAdminUid: data['superAdminUid']?.toString(),
      backupEnabled: data['backupEnabled'] != false,
      lastBackupAt: last is Timestamp ? last.toDate() : null,
      lastBackupPath: data['lastBackupPath']?.toString(),
      lastBackupSizeBytes: data['lastBackupSizeBytes'] is int
          ? data['lastBackupSizeBytes'] as int
          : null,
    );
  }

  bool get hasSuperAdminOtpEmail =>
      superAdminOtpEmail != null && superAdminOtpEmail!.contains('@');
}

class BackupRecord {
  final String id;
  final String path;
  final int sizeBytes;
  final String status;
  final DateTime? createdAt;
  final String triggeredBy;

  const BackupRecord({
    required this.id,
    required this.path,
    required this.sizeBytes,
    required this.status,
    this.createdAt,
    required this.triggeredBy,
  });

  factory BackupRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final ts = data['createdAt'];
    return BackupRecord(
      id: doc.id,
      path: (data['path'] ?? '').toString(),
      sizeBytes: data['sizeBytes'] is int ? data['sizeBytes'] as int : 0,
      status: (data['status'] ?? 'unknown').toString(),
      createdAt: ts is Timestamp ? ts.toDate() : null,
      triggeredBy: (data['triggeredBy'] ?? '').toString(),
    );
  }
}
