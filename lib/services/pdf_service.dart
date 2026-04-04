import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {

  static Future<void> generateLedgerPdf(
      String name,
      double principal,
      double interestRate,
      List installments,
  ) async {

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.Text(
                "Loan Ledger",
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Text("Customer: $name"),
              pw.Text("Principal: ₹$principal"),
              pw.Text("Interest Rate: $interestRate %"),

              pw.SizedBox(height: 20),

              pw.Text("Installments",
                  style: pw.TextStyle(fontSize: 18)),

              pw.Table.fromTextArray(
                headers: [
                  "Date",
                  "Amount",
                  "Principal Paid",
                  "Interest Paid"
                ],
                data: installments.map((e) {
                  return [
                    e['date'],
                    e['amount'].toString(),
                    e['principalPaid'].toString(),
                    e['interestPaid'].toString(),
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}