import 'package:flutter/material.dart';
import '../../services/team_service.dart';
import '../../widgets/admin_otp_dialog.dart';

class TeamMemberFormScreen extends StatefulWidget {
  const TeamMemberFormScreen({super.key});

  @override
  State<TeamMemberFormScreen> createState() => _TeamMemberFormScreenState();
}

class _TeamMemberFormScreenState extends State<TeamMemberFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _team = TeamService();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String _role = 'staff';
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      if (_role == 'staff') {
        await _team.createStaffMember(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
      } else {
        final otpReq = await _team.requestAdminOtp(
          purpose: 'create_admin',
          targetEmail: _email.text.trim(),
        );
        if (!mounted) return;
        setState(() => _loading = false);

        final otp = await AdminOtpDialog.show(
          context,
          sentToMasked: otpReq.sentTo,
          expiresInSeconds: otpReq.expiresInSeconds,
        );
        if (otp == null || !mounted) return;

        setState(() => _loading = true);
        await _team.createAdminMember(
          email: _email.text,
          password: _password.text,
          name: _name.text,
          otpRequestId: otpReq.requestId,
          otp: otp,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team member added')),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Add team member'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_role == 'admin')
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDBA74)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security, color: Color(0xFFC2410C)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Adding an admin requires a verification code emailed to the super admin.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  if (v == null || !v.contains('@')) return 'Enter valid email';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Temporary password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length < 6) {
                    return 'Minimum 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              const Text(
                'Access level',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'staff',
                    label: Text('Staff'),
                    icon: Icon(Icons.badge_outlined),
                  ),
                  ButtonSegment(
                    value: 'admin',
                    label: Text('Admin'),
                    icon: Icon(Icons.admin_panel_settings_outlined),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _role == 'staff'
                    ? 'Staff: Property Hub only (sites, plots, payments).'
                    : 'Admin: Full dashboard, ledger, reports, and team management.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF1E3A8A),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
