import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dialog to enter OTP sent to the super admin's phone.
class AdminOtpDialog extends StatefulWidget {
  final String sentToMasked;
  final int expiresInSeconds;

  const AdminOtpDialog({
    super.key,
    required this.sentToMasked,
    required this.expiresInSeconds,
  });

  static Future<String?> show(
    BuildContext context, {
    required String sentToMasked,
    required int expiresInSeconds,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdminOtpDialog(
        sentToMasked: sentToMasked,
        expiresInSeconds: expiresInSeconds,
      ),
    );
  }

  @override
  State<AdminOtpDialog> createState() => _AdminOtpDialogState();
}

class _AdminOtpDialogState extends State<AdminOtpDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Super admin verification'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A 6-digit code was emailed to ${widget.sentToMasked}. '
            'Check your inbox (and spam folder), then enter the code below.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'OTP code',
              counterText: '',
              prefixIcon: Icon(Icons.mark_email_read_outlined),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Expires in ${widget.expiresInSeconds ~/ 60} minutes',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final code = _controller.text.trim();
            if (code.length != 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Enter the 6-digit code')),
              );
              return;
            }
            Navigator.pop(context, code);
          },
          child: const Text('Verify'),
        ),
      ],
    );
  }
}
