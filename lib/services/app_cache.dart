import 'dashboard_service.dart';
import 'property_analytics_service.dart';

/// Short-lived in-memory cache so back navigation feels instant on mobile web.
class AppCache {
  AppCache._();
  static final AppCache instance = AppCache._();

  static const Duration ttl = Duration(seconds: 60);

  DateTime? _propertyGlobalAt;
  PropertyGlobalStats? _propertyGlobal;

  DateTime? _siteSummariesAt;
  List<SiteSummary>? _siteSummaries;

  final Map<String, DateTime> _plotSummariesAt = {};
  final Map<String, List<PlotSummary>> _plotSummaries = {};

  DateTime? _dashboardPropertyAt;
  PropertyCollectionStats? _dashboardProperty;

  DateTime? _dashboardLedgerAt;
  LedgerOverviewStats? _dashboardLedger;

  final Map<int, DateTime> _ledgerMonthlyAt = {};
  final Map<int, Map<int, LedgerMonthBucket>> _ledgerMonthly = {};

  final Map<int, DateTime> _propertyMonthlyAt = {};
  final Map<int, Map<int, PropertyMonthBucket>> _propertyMonthly = {};

  bool _isFresh(DateTime? at) =>
      at != null && DateTime.now().difference(at) < ttl;

  PropertyGlobalStats? get propertyGlobal =>
      _isFresh(_propertyGlobalAt) ? _propertyGlobal : null;

  List<SiteSummary>? get siteSummaries =>
      _isFresh(_siteSummariesAt) ? _siteSummaries : null;

  List<PlotSummary>? plotSummaries(String siteId) {
    final at = _plotSummariesAt[siteId];
    if (!_isFresh(at)) return null;
    return _plotSummaries[siteId];
  }

  PropertyCollectionStats? get dashboardProperty =>
      _isFresh(_dashboardPropertyAt) ? _dashboardProperty : null;

  LedgerOverviewStats? get dashboardLedger =>
      _isFresh(_dashboardLedgerAt) ? _dashboardLedger : null;

  Map<int, LedgerMonthBucket>? ledgerMonthly(int year) {
    final at = _ledgerMonthlyAt[year];
    if (!_isFresh(at)) return null;
    return _ledgerMonthly[year];
  }

  Map<int, PropertyMonthBucket>? propertyMonthly(int year) {
    final at = _propertyMonthlyAt[year];
    if (!_isFresh(at)) return null;
    return _propertyMonthly[year];
  }

  void putPropertyGlobal(PropertyGlobalStats stats) {
    _propertyGlobal = stats;
    _propertyGlobalAt = DateTime.now();
  }

  void putSiteSummaries(List<SiteSummary> sites) {
    _siteSummaries = sites;
    _siteSummariesAt = DateTime.now();
  }

  void putPlotSummaries(String siteId, List<PlotSummary> plots) {
    _plotSummaries[siteId] = plots;
    _plotSummariesAt[siteId] = DateTime.now();
  }

  void putDashboardProperty(PropertyCollectionStats stats) {
    _dashboardProperty = stats;
    _dashboardPropertyAt = DateTime.now();
  }

  void putDashboardLedger(LedgerOverviewStats stats) {
    _dashboardLedger = stats;
    _dashboardLedgerAt = DateTime.now();
  }

  void putLedgerMonthly(int year, Map<int, LedgerMonthBucket> buckets) {
    _ledgerMonthly[year] = buckets;
    _ledgerMonthlyAt[year] = DateTime.now();
  }

  void putPropertyMonthly(int year, Map<int, PropertyMonthBucket> buckets) {
    _propertyMonthly[year] = buckets;
    _propertyMonthlyAt[year] = DateTime.now();
  }

  /// Call after payments, customers, sites, plots change.
  void invalidateProperty() {
    _propertyGlobalAt = null;
    _propertyGlobal = null;
    _siteSummariesAt = null;
    _siteSummaries = null;
    _plotSummariesAt.clear();
    _plotSummaries.clear();
    _dashboardPropertyAt = null;
    _dashboardProperty = null;
    _propertyMonthlyAt.clear();
    _propertyMonthly.clear();
  }

  void invalidatePlotSite(String siteId) {
    _plotSummariesAt.remove(siteId);
    _plotSummaries.remove(siteId);
    _siteSummariesAt = null;
    _siteSummaries = null;
    _propertyGlobalAt = null;
    _propertyGlobal = null;
    _dashboardPropertyAt = null;
    _dashboardProperty = null;
  }

  void invalidateLedger() {
    _dashboardLedgerAt = null;
    _dashboardLedger = null;
    _ledgerMonthlyAt.clear();
    _ledgerMonthly.clear();
  }

  void invalidateAll() {
    invalidateProperty();
    invalidateLedger();
  }
}
