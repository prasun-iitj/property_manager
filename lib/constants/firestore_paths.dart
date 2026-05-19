/// Canonical Firestore paths used by the app (V1 implementation).
class FirestorePaths {
  static const users = 'users';
  static const sites = 'sites';

  static const ledgerRoot = 'ledger';
  static const ledgerDataDoc = 'data';
  /// Legacy ledger container (pre-v1.1); still read for existing production data.
  static const legacyLedgerDataDoc = 'master';

  static const ledgerContainerDocIds = [ledgerDataDoc, legacyLedgerDataDoc];
  static const lending = 'lending';
  static const borrowing = 'borrowing';
  static const installments = 'installments';

  static const plots = 'plots';
  static const customer = 'customer';
  static const customerDetailsId = 'details';
  static const payments = 'payments';
  static const documents = 'documents';

  /// Legacy document storage path (still read for migration).
  static const legacyCustomers = 'customers';

  static const config = 'config';
  static const systemConfigDoc = 'system';
  static const backupHistory = 'backupHistory';
}
