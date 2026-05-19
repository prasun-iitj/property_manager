import 'package:flutter/material.dart';

/// Explains limited access when signed in as staff (not admin).
class RoleAccessBanner extends StatelessWidget {
  final String role;
  final String? email;

  const RoleAccessBanner({
    super.key,
    required this.role,
    this.email,
  });

  @override
  Widget build(BuildContext context) {
    if (role == 'admin') return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFC2410C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Signed in as $role',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9A3412),
                    fontSize: 13,
                  ),
                ),
                if (email != null && email!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email!,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'Staff can use Property only (sites, plots, customers). '
                  'For dashboard, ledger & reports, log out and sign in with your admin account.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9A3412)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
