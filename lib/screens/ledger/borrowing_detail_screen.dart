import 'ledger_detail_screen.dart';

class BorrowingDetailScreen extends LedgerDetailScreen {
  const BorrowingDetailScreen({super.key, required String borrowId})
      : super(
          loanId: borrowId,
          ledgerType: 'borrowing',
          title: 'Borrowing Details',
          listLabel: 'Borrowing',
        );
}
