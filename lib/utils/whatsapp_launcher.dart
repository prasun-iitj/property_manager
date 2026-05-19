import 'package:flutter/foundation.dart';
import 'ledger_calculator.dart';
import 'external_url.dart';

/// WhatsApp receipt footer for plot payment messages.
const String kPaymentWhatsAppSignature = 'Thanks from Mayur@RealEstate';

/// Normalizes an Indian mobile number for `wa.me` (digits only, 91XXXXXXXXXX).
String? normalizeIndianPhone(String raw) {
  var digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return null;
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length == 10) {
    digits = '91$digits';
  }
  if (digits.length == 12 && digits.startsWith('91')) {
    return digits;
  }
  if (digits.length >= 10) return digits;
  return null;
}

String buildPaymentReceiptMessage({
  required int amount,
  required int totalPaid,
  required int remaining,
}) {
  final balanceLine = remaining < 0
      ? 'Overpaid: ${LedgerMoneyFormat.rupees(-remaining)} (credit)'
      : 'Remaining Amount: ${LedgerMoneyFormat.rupees(remaining)}';

  return '''
Payment Received Successfully

Amount Paid: ₹$amount
Total Paid: ₹$totalPaid
$balanceLine

$kPaymentWhatsAppSignature''';
}

List<String> whatsAppLaunchUrls({
  required String phone,
  required String message,
}) {
  final normalized = normalizeIndianPhone(phone);
  final encoded = Uri.encodeComponent(message);

  return [
    if (normalized != null)
      'https://wa.me/$normalized?text=$encoded',
    if (normalized != null)
      'https://api.whatsapp.com/send?phone=$normalized&text=$encoded',
    if (normalized != null && !kIsWeb)
      'whatsapp://send?phone=$normalized&text=$encoded',
    'https://wa.me/?text=$encoded',
    if (!kIsWeb) 'whatsapp://send?text=$encoded',
  ];
}

/// Opens WhatsApp with [message]. On web/iPhone, call from a button tap (not after long async).
Future<bool> launchPaymentWhatsApp({
  required String phone,
  required String message,
}) async {
  for (final url in whatsAppLaunchUrls(phone: phone, message: message)) {
    if (await openExternalUrl(url)) {
      return true;
    }
  }
  return false;
}
