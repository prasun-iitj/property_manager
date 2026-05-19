import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/team_member.dart';
import '../../services/team_service.dart';
import '../../widgets/admin_otp_dialog.dart';
import 'team_member_form_screen.dart';

class ManageTeamScreen extends StatefulWidget {
  const ManageTeamScreen({super.key});

  @override
  State<ManageTeamScreen> createState() => _ManageTeamScreenState();
}

class _ManageTeamScreenState extends State<ManageTeamScreen> {
  final _team = TeamService();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final loginEmail = FirebaseAuth.instance.currentUser?.email;
    if (loginEmail != null && loginEmail.isNotEmpty) {
      _emailController.text = loginEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _registerSuperAdminEmail({bool useMyLogin = false}) async {
    try {
      await _team.registerSuperAdminEmail(
        _emailController.text,
        useMyLoginEmail: useMyLogin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Super admin OTP email saved')),
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

  Future<void> _changeRole(TeamMember member, String newRole) async {
    if (member.role == newRole) return;

    String? otpRequestId;
    String? otp;

    if (newRole == 'admin') {
      try {
        final otpReq = await _team.requestAdminOtp(
          purpose: 'promote_admin',
          targetEmail: member.email,
        );
        if (!mounted) return;
        final code = await AdminOtpDialog.show(
          context,
          sentToMasked: otpReq.sentTo,
          expiresInSeconds: otpReq.expiresInSeconds,
        );
        if (code == null) return;
        otpRequestId = otpReq.requestId;
        otp = code;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
    }

    try {
      await _team.updateMemberRole(
        uid: member.uid,
        role: newRole,
        otpRequestId: otpRequestId,
        otp: otp,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} is now $newRole')),
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

  Future<void> _toggleDisabled(TeamMember member) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (member.uid == currentUid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot disable your own account')),
      );
      return;
    }

    final disable = !member.disabled;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(disable ? 'Disable account?' : 'Enable account?'),
        content: Text(
          disable
              ? '${member.email} will not be able to sign in.'
              : '${member.email} can sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(disable ? 'Disable' : 'Enable'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _team.setMemberDisabled(member.uid, disable);
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

  Future<void> _sendPasswordReset(TeamMember member) async {
    try {
      await _team.sendPasswordResetEmail(member.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reset email sent to ${member.email}')),
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

  static String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final visible = local.length <= 2 ? local : local.substring(0, 2);
    return '$visible***@${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Manage team'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeamMemberFormScreen()),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Add member'),
      ),
      body: StreamBuilder<SystemConfig>(
        stream: _team.streamSystemConfig(),
        builder: (context, configSnap) {
          final config = configSnap.data ?? const SystemConfig();

          return CustomScrollView(
            slivers: [
              if (!config.hasSuperAdminOtpEmail)
                SliverToBoxAdapter(child: _superAdminSetupCard())
              else
                SliverToBoxAdapter(child: _superAdminInfoCard(config)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    'Team members',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
              StreamBuilder<List<TeamMember>>(
                stream: _team.streamTeamMembers(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final members = snap.data ?? [];
                  if (members.isEmpty) {
                    return const SliverFillRemaining(
                      child: Center(child: Text('No team members yet')),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _memberTile(members[i]),
                      childCount: members.length,
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          );
        },
      ),
    );
  }

  Widget _superAdminSetupCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(0xFFEFF6FF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mark_email_read_outlined, color: Color(0xFF1E3A8A)),
                SizedBox(width: 8),
                Text(
                  'Set super admin email',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Admin verification codes are sent to this email (free — uses your Gmail or SMTP).',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Super admin email',
                hintText: 'you@company.com',
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => _registerSuperAdminEmail(),
              icon: const Icon(Icons.verified_user),
              label: const Text('Save OTP email'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _registerSuperAdminEmail(useMyLogin: true),
              icon: const Icon(Icons.login),
              label: const Text('Use my current login email'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _superAdminInfoCard(SystemConfig config) {
    final email = config.superAdminOtpEmail ?? '';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFDBEAFE),
          child: Icon(Icons.mark_email_read_outlined, color: Color(0xFF1E3A8A)),
        ),
        title: const Text('Super admin email OTP'),
        subtitle: Text('Codes sent to ${_maskEmail(email)}'),
      ),
    );
  }

  Widget _memberTile(TeamMember member) {
    final isAdmin = member.role == 'admin';
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isSelf = member.uid == currentUid;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin
              ? const Color(0xFF1E3A8A)
              : Colors.grey.shade400,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          member.name.isEmpty ? member.email : member.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: member.disabled ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(member.email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(isAdmin ? 'Admin' : 'Staff'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      isAdmin ? const Color(0xFFDBEAFE) : Colors.grey.shade200,
                ),
                if (member.isSuperAdmin)
                  const Chip(
                    label: Text('Super admin'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (member.disabled)
                  Chip(
                    label: const Text('Disabled'),
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.red.shade100,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: isSelf
            ? const Text('You', style: TextStyle(color: Colors.grey))
            : PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'staff' || v == 'admin') {
                    await _changeRole(member, v);
                  } else if (v == 'toggle') {
                    await _toggleDisabled(member);
                  } else if (v == 'reset') {
                    await _sendPasswordReset(member);
                  }
                },
                itemBuilder: (_) => [
                  if (!isAdmin)
                    const PopupMenuItem(
                      value: 'admin',
                      child: Text('Promote to admin (email OTP)'),
                    ),
                  if (isAdmin)
                    const PopupMenuItem(
                      value: 'staff',
                      child: Text('Change to staff'),
                    ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(member.disabled ? 'Enable account' : 'Disable account'),
                  ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Send password reset email'),
                  ),
                ],
              ),
      ),
    );
  }
}
