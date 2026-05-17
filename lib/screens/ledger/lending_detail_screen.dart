import 'ledger_detail_screen.dart';

class LendingDetailScreen extends LedgerDetailScreen {
  const LendingDetailScreen({super.key, required super.loanId})
      : super(
          ledgerType: 'lending',
          title: 'Lending Details',
          listLabel: 'Lending',
        );
}
