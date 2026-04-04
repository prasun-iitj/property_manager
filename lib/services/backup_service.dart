import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {

  static Future<void> exportLedgerBackup() async {

    List<List<String>> rows = [];

    rows.add([
      "Type",
      "Name",
      "Principal",
      "Interest Rate",
      "Remaining Principal"
    ]);

    var lending = await FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('lending')
        .get();

    for (var loan in lending.docs) {

      var data = loan.data();

      rows.add([
        "Lending",
        data['name'].toString(),
        data['principal'].toString(),
        data['interestRate'].toString(),
        data['remainingPrincipal'].toString(),
      ]);

    }

    var borrowing = await FirebaseFirestore.instance
        .collection('ledger')
        .doc('data')
        .collection('borrowing')
        .get();

    for (var loan in borrowing.docs) {

      var data = loan.data();

      rows.add([
        "Borrowing",
        data['name'].toString(),
        data['principal'].toString(),
        data['interestRate'].toString(),
        data['remainingPrincipal'].toString(),
      ]);

    }

    String csv = rows.map((e) => e.join(",")).join("\n");

    final directory = await getApplicationDocumentsDirectory();

    final date = DateFormat('yyyy_MM_dd').format(DateTime.now());

    final file = File("${directory.path}/ledger_backup_$date.csv");

    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], text: "Ledger Backup");

  }

}