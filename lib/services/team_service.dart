import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/firestore_paths.dart';
import '../models/team_member.dart';

class TeamService {
  TeamService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-south1');

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<TeamMember>> streamTeamMembers() {
    return _db.collection(FirestorePaths.users).snapshots().map((snap) {
      final list = snap.docs.map(TeamMember.fromDoc).toList();
      list.sort((a, b) => a.email.compareTo(b.email));
      return list;
    });
  }

  Stream<SystemConfig> streamSystemConfig() {
    return _db
        .doc('${FirestorePaths.config}/${FirestorePaths.systemConfigDoc}')
        .snapshots()
        .map((s) => SystemConfig.fromMap(s.data()));
  }

  Stream<List<BackupRecord>> streamBackupHistory({int limit = 15}) {
    return _db
        .collection(FirestorePaths.backupHistory)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(BackupRecord.fromDoc).toList());
  }

  String _messageFromError(Object e) {
    if (e is FirebaseFunctionsException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }

  Future<void> registerSuperAdminEmail(
    String email, {
    bool useMyLoginEmail = false,
  }) async {
    try {
      await _functions.httpsCallable('registerSuperAdminEmail').call({
        if (!useMyLoginEmail) 'email': email.trim(),
        'useMyLoginEmail': useMyLoginEmail,
      });
    } catch (e) {
      throw _messageFromError(e);
    }
  }

  Future<AdminOtpRequest> requestAdminOtp({
    required String purpose,
    String? targetEmail,
  }) async {
    try {
      final result = await _functions.httpsCallable('requestAdminOtp').call({
        'purpose': purpose,
        if (targetEmail != null) 'targetEmail': targetEmail,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      return AdminOtpRequest(
        requestId: data['requestId'] as String,
        sentTo: data['sentTo'] as String? ?? '',
        expiresInSeconds: data['expiresInSeconds'] as int? ?? 600,
      );
    } catch (e) {
      throw _messageFromError(e);
    }
  }

  Future<void> createStaffMember({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      await _functions.httpsCallable('createTeamMember').call({
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
        'role': 'staff',
      });
    } catch (e) {
      throw _messageFromError(e);
    }
  }

  Future<void> createAdminMember({
    required String email,
    required String password,
    required String name,
    required String otpRequestId,
    required String otp,
  }) async {
    try {
      await _functions.httpsCallable('createAdminTeamMember').call({
        'email': email.trim(),
        'password': password,
        'name': name.trim(),
        'otpRequestId': otpRequestId,
        'otp': otp.trim(),
      });
    } catch (e) {
      throw _messageFromError(e);
    }
  }

  Future<void> updateMemberRole({
    required String uid,
    required String role,
    String? otpRequestId,
    String? otp,
  }) async {
    try {
      await _functions.httpsCallable('updateTeamMemberRole').call({
        'uid': uid,
        'role': role,
        if (otpRequestId != null) 'otpRequestId': otpRequestId,
        if (otp != null) 'otp': otp.trim(),
      });
    } catch (e) {
      throw _messageFromError(e);
    }
  }

  Future<void> setMemberDisabled(String uid, bool disabled) async {
    try {
      final callable = disabled ? 'disableTeamMember' : 'enableTeamMember';
      await _functions.httpsCallable(callable).call({'uid': uid});
    } catch (e) {
      throw _messageFromError(e);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<Map<String, dynamic>> runBackupNow() async {
    try {
      final result = await _functions.httpsCallable('runBackupNow').call();
      return Map<String, dynamic>.from(result.data as Map);
    } catch (e) {
      throw _messageFromError(e);
    }
  }

  Future<void> updateBackupSettings({required bool enabled}) async {
    try {
      await _functions.httpsCallable('updateBackupSettings').call({
        'enabled': enabled,
        'schedule': '0 2 * * *',
        'timeZone': 'Asia/Kolkata',
      });
    } catch (e) {
      throw _messageFromError(e);
    }
  }
}

class AdminOtpRequest {
  final String requestId;
  final String sentTo;
  final int expiresInSeconds;

  const AdminOtpRequest({
    required this.requestId,
    required this.sentTo,
    required this.expiresInSeconds,
  });
}
