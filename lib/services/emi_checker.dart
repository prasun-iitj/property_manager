import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class EmiChecker {

  static Future checkEmiDue() async {

    var lending = await FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('lending')
        .get();

    DateTime now = DateTime.now();

    for (var loan in lending.docs) {

      var installments = await loan.reference
          .collection('installments')
          .get();

      for (var ins in installments.docs) {

        var data = ins.data();

        if (data['nextDueDate'] != null) {

          DateTime due =
              (data['nextDueDate'] as Timestamp).toDate();

          if (due.year == now.year &&
              due.month == now.month &&
              due.day == now.day) {

            await NotificationService.showNotification(
              1,
              "EMI Reminder",
              "Payment due today from ${loan['name']}",
            );

          }
        }
      }
    }
  }
}