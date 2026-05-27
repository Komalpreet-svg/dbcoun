import 'package:flutter/material.dart';
import '../models/server.dart';
import '../data/server_data.dart';
import '../theme/app_theme.dart';
import '../screens/server_list_screen.dart';

class DbaDashboardScreen extends StatefulWidget {
  const DbaDashboardScreen({super.key});

  @override
  State<DbaDashboardScreen> createState() => _DbaDashboardScreenState();
}

class _DbaDashboardScreenState extends State<DbaDashboardScreen>
    with TickerProviderStateMixin {
  bool _refreshing = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _refreshing = false);
  }

  // ── Computed aggregates ─────────────────────────────────────

  List<Server> get _allServers => sampleServers;
  List<Server> get _prodServers =>
      _allServers.where((s) => s.environment == ServerEnvironment.prod).toList();

  int get _totalServers => _allServers.length;

  int get _unhealthyCount => _allServers
      .where((s) =>
          s.status == ServerStatus.offline ||
          s.status == ServerStatus.degraded)
      .length;

  bool get _prodImpact => _prodServers.any(
      (s) => s.status == ServerStatus.offline || s.status == ServerStatus.degraded);

  // Alerts
  int get _criticalAlerts => _prodServers
      .where((s) => s.status == ServerStatus.offline)
      .length +
      _allServers.where((s) => s.loginFailureSpike).length +
      _allServers
          .where((s) => s.databases.any((d) => d.dataFreePercent < 10))
          .length;

  int get _warningAlerts => _allServers
      .where((s) =>
          s.status == ServerStatus.degraded ||
          s.blockingPresent ||
          !s.fullBackupWithin24h ||
          !s.agHealthy)
      .length;

  int get _infoAlerts => _allServers
      .where((s) =>
          s.longRunningQueriesCount > 0 ||
          s.expiredCertCount > 0)
      .length;

  // DB roll-up across all servers
  int get _dbOffline =>
      _allServers.fold<int>(0, (sum, s) => sum + s.databases.where((d) => d.isOffline).length);
  int get _dbRestoring =>
      _allServers.fold<int>(0, (sum, s) => sum + s.databases.where((d) => d.isRestoring).length);
  int get _dbSuspect =>
      _allServers.fold<int>(0, (sum, s) => sum + s.databases.where((d) => d.isSuspect).length);

  double get _lowestDataFree => _allServers
      .expand((s) => s.databases)
      .fold<double>(100, (m, d) => d.dataFreePercent < m ? d.dataFreePercent : m);

  double get _lowestLogFree => _allServers
      .expand((s) => s.databases)
      .fold<double>(100, (m, d) => d.logFreePercent < m ? d.logFreePercent : m);

  // Performance signals across prod
  bool get _anyBlocking => _prodServers.any((s) => s.blockingPresent);
  int get _totalLongRunning =>
      _prodServers.fold<int>(0, (sum, s) => sum + s.longRunningQueriesCount);
  bool get _requestQueueHigh => _prodServers.any((s) => s.requestQueueHigh);
  bool get _tempDbPressure => _prodServers.any((s) => s.tempDbPressure);

  // HA/DR
  bool get _agHealthy => _prodServers.every((s) => s.agHealthy || s.agRole == AgRole.none);
  String get _replicaLag {
    final lagging = _prodServers.where((s) => s.agRole == AgRole.secondary && !s.agHealthy);
    return lagging.isEmpty ? 'OK' : lagging.first.replicaLag;
  }
  bool get _failoverReady =>
      _prodServers.where((s) => s.agRole == AgRole.secondary).every((s) => s.failoverReady);

  // Security
  bool get _loginFailureSpike => _allServers.any((s) => s.loginFailureSpike);
  bool get _sqlAuditRunning => _prodServers.every((s) => s.sqlAuditRunning);
  int get _totalExpiredCerts =>
      _allServers.fold<int>(0, (sum, s) => sum + s.expiredCertCount);

  // Jobs
  bool get _sqlAgentRunning =>
      _prodServers.every((s) => s.sqlAgentRunning);
  Server? get _lastFailedJobServer => _prodServers
      .where((s) => s.lastFailedJobName != null)
      .fold<Server?>(null, (prev, s) => prev == null ? s : s);

  // Overall global health
  _GlobalHealth get _globalHealth {
    if (_criticalAlerts > 0 || _dbOffline > 0 || _dbSuspect > 0) {
      return _GlobalHealth.critical;
    }
    if (_warningAlerts > 0 || _dbRestoring > 0 || !_agHealthy) {
      return _GlobalHealth.degraded;
    }
    return _GlobalHealth.healthy;
  }

  @override
  Widget build(BuildContext context) {
    final health = _globalHealth;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.primary,
          backgroundColor: AppTheme.surface,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              // ── Top App Bar ──────────────────────────────────
              SliverToBoxAdapter(
                child: _buildTopBar(),
              ),

              // ── Global Health Banner ─────────────────────────
              SliverToBoxAdapter(
                child: _buildGlobalHealthBanner(health),
              ),

              // ── Server Overview ──────────────────────────────
              SliverToBoxAdapter(
                child: _DashSection(
                  title: 'SERVER OVERVIEW',
                  trailing: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ServerListScreen()),
                    ),
                    child: const Text('View All',
                        style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ),
                  child: Column(
                    children: _buildServerOverview(),
                  ),
                ),
              ),

              // ── DB Health Roll-up ─────────────────────────────
              SliverToBoxAdapter(
                child: _DashSection(
                  title: 'DATABASE HEALTH',
                  child: _buildDbHealthRollup(),
                ),
              ),

              // ── Performance Indicators ───────────────────────
              SliverToBoxAdapter(
                child: _DashSection(
                  title: 'PERFORMANCE SIGNALS',
                  child: _buildPerformanceSignals(),
                ),
              ),

              // ── Jobs & Maintenance ───────────────────────────
              SliverToBoxAdapter(
                child: _DashSection(
                  title: 'JOBS & MAINTENANCE',
                  child: _buildJobsMaintenance(),
                ),
              ),

              // ── HA / DR ──────────────────────────────────────
              SliverToBoxAdapter(
                child: _DashSection(
                  title: 'HA / DISASTER RECOVERY',
                  child: _buildHaDr(),
                ),
              ),

              // ── Security / Compliance ────────────────────────
              SliverToBoxAdapter(
                child: _DashSection(
                  title: 'SECURITY & COMPLIANCE',
                  child: _buildSecurity(),
                ),
              ),

              // ── Bottom Quick Actions ──────────────────────────
              SliverToBoxAdapter(
                child: _buildQuickActions(context),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top Bar ──────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DBA Control Center',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                _timestampNow(),
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const Spacer(),
          // Alert counters row
          _AlertBadge(count: _criticalAlerts, color: AppTheme.statusOffline, label: 'CRIT'),
          const SizedBox(width: 6),
          _AlertBadge(count: _warningAlerts, color: AppTheme.statusDegraded, label: 'WARN'),
          const SizedBox(width: 6),
          _AlertBadge(count: _infoAlerts, color: AppTheme.primary, label: 'INFO'),
          const SizedBox(width: 8),
          _refreshing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.primary))
              : GestureDetector(
                  onTap: _refresh,
                  child: const Icon(Icons.refresh_rounded,
                      color: AppTheme.textSecondary, size: 22),
                ),
        ],
      ),
    );
  }

  // ── Global Health Banner ─────────────────────────────────────

  Widget _buildGlobalHealthBanner(_GlobalHealth health) {
    final Color color;
    final String icon;
    final String label;
    final Color bg;
    switch (health) {
      case _GlobalHealth.healthy:
        color = AppTheme.statusOnline;
        icon = '✅';
        label = 'HEALTHY';
        bg = const Color(0xFF0F2318);
        break;
      case _GlobalHealth.degraded:
        color = AppTheme.statusDegraded;
        icon = '⚠';
        label = 'DEGRADED';
        bg = const Color(0xFF231C08);
        break;
      case _GlobalHealth.critical:
        color = AppTheme.statusOffline;
        icon = '🔴';
        label = 'CRITICAL';
        bg = const Color(0xFF230E0E);
        break;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status + label row
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Opacity(
                    opacity: health == _GlobalHealth.critical
                        ? _pulseAnim.value
                        : 1.0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2)
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$icon  $label',
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    '$_totalServers SERVERS',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 12),
            // Prod impact + affected
            Row(
              children: [
                _InfoPill(
                  label: 'PROD IMPACT',
                  value: _prodImpact ? 'YES' : 'NO',
                  valueColor:
                      _prodImpact ? AppTheme.statusOffline : AppTheme.statusOnline,
                ),
                const SizedBox(width: 12),
                _InfoPill(
                  label: 'AFFECTED',
                  value: '$_unhealthyCount of $_totalServers',
                  valueColor: _unhealthyCount > 0
                      ? AppTheme.statusDegraded
                      : AppTheme.statusOnline,
                ),
                const Spacer(),
                // Timestamp since last check
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Last Refresh',
                        style: TextStyle(
                            color: AppTheme.textMuted, fontSize: 10)),
                    const Text('Just now',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Server Overview ──────────────────────────────────────────

  List<Widget> _buildServerOverview() {
    // Sort: prod first, then qa, then dev; within each group unhealthy first
    final sorted = [..._allServers];
    sorted.sort((a, b) {
      int envOrder(ServerEnvironment e) {
        switch (e) {
          case ServerEnvironment.prod:
            return 0;
          case ServerEnvironment.qa:
            return 1;
          case ServerEnvironment.dev:
            return 2;
        }
      }

      int statusOrder(ServerStatus s) {
        switch (s) {
          case ServerStatus.offline:
            return 0;
          case ServerStatus.degraded:
            return 1;
          case ServerStatus.online:
            return 2;
        }
      }

      final envCmp = envOrder(a.environment).compareTo(envOrder(b.environment));
      if (envCmp != 0) return envCmp;
      return statusOrder(a.status).compareTo(statusOrder(b.status));
    });

    return sorted.map((s) => _ServerRow(server: s)).toList();
  }

  // ── DB Health Roll-up ────────────────────────────────────────

  Widget _buildDbHealthRollup() {
    final agPrimary = _allServers.firstWhere(
      (s) => s.agRole == AgRole.primary,
      orElse: () => _allServers.first,
    );

    final allDbs = _allServers.expand((s) => s.databases).toList();
    final lowestDataFreeDb = allDbs.isEmpty
        ? null
        : allDbs.reduce((a, b) => a.dataFreePercent < b.dataFreePercent ? a : b);

    final lowestLogFreeDb = allDbs.isEmpty
        ? null
        : allDbs.reduce((a, b) => a.logFreePercent < b.logFreePercent ? a : b);

    final logReuseWaits = allDbs
        .where((d) => d.logReuseWait != LogReuseWait.nothing)
        .map((d) => '${d.name}: ${_logReuseLabel(d.logReuseWait)}')
        .toList();

    return Column(
      children: [
        // DB state counts
        _GridRow(children: [
          _KpiTile(
            label: 'Offline DBs',
            value: '$_dbOffline',
            valueColor: _dbOffline > 0 ? AppTheme.statusOffline : AppTheme.statusOnline,
          ),
          _KpiTile(
            label: 'Restoring',
            value: '$_dbRestoring',
            valueColor: _dbRestoring > 0 ? AppTheme.statusDegraded : AppTheme.statusOnline,
          ),
          _KpiTile(
            label: 'Suspect',
            value: '$_dbSuspect',
            valueColor: _dbSuspect > 0 ? AppTheme.statusOffline : AppTheme.statusOnline,
          ),
        ]),
        const SizedBox(height: 10),

        // AG status
        if (agPrimary.agRole == AgRole.primary) ...[
          _LabelRow(
            label: 'Always On AG',
            leftChild: Row(
              children: [
                _Tag(
                    text: 'PRIMARY',
                    color: const Color(0xFF3B9EFF)),
                const SizedBox(width: 6),
                _Tag(
                  text: agPrimary.agSyncState == AgSyncState.healthy
                      ? 'HEALTHY'
                      : 'LAGGING',
                  color: agPrimary.agSyncState == AgSyncState.healthy
                      ? AppTheme.statusOnline
                      : AppTheme.statusDegraded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Log reuse wait
        if (logReuseWaits.isNotEmpty)
          _LabelRow(
            label: 'Log Reuse Wait',
            rightText: logReuseWaits.first,
            rightColor: AppTheme.statusDegraded,
          ),
        if (logReuseWaits.isNotEmpty) const SizedBox(height: 8),

        // Lowest data free
        _LabelRow(
          label: 'Lowest Data Free',
          rightText: lowestDataFreeDb != null
              ? '${lowestDataFreeDb.dataFreePercent.toStringAsFixed(1)}% (${lowestDataFreeDb.name})'
              : '—',
          rightColor: _lowestDataFree < 15
              ? AppTheme.statusOffline
              : _lowestDataFree < 25
                  ? AppTheme.statusDegraded
                  : AppTheme.statusOnline,
        ),
        const SizedBox(height: 6),

        // Lowest log free
        _LabelRow(
          label: 'Lowest Log Free',
          rightText: lowestLogFreeDb != null
              ? '${lowestLogFreeDb.logFreePercent.toStringAsFixed(1)}% (${lowestLogFreeDb.name})'
              : '—',
          rightColor: _lowestLogFree < 15
              ? AppTheme.statusOffline
              : _lowestLogFree < 25
                  ? AppTheme.statusDegraded
                  : AppTheme.statusOnline,
        ),
      ],
    );
  }

  // ── Performance Signals ──────────────────────────────────────

  Widget _buildPerformanceSignals() {
    return _GridRow(children: [
      _BoolTile(
        label: 'Blocking',
        state: _anyBlocking,
        trueLabel: 'PRESENT',
        falseLabel: 'NONE',
        dangerOnTrue: true,
      ),
      _KpiTile(
        label: 'Long Queries',
        value: '$_totalLongRunning',
        unit: 'active',
        valueColor: _totalLongRunning > 3
            ? AppTheme.statusOffline
            : _totalLongRunning > 0
                ? AppTheme.statusDegraded
                : AppTheme.statusOnline,
      ),
      _BoolTile(
        label: 'Request Queue',
        state: _requestQueueHigh,
        trueLabel: 'HIGH',
        falseLabel: 'NORMAL',
        dangerOnTrue: true,
      ),
      _BoolTile(
        label: 'TempDB',
        state: _tempDbPressure,
        trueLabel: 'PRESSURE',
        falseLabel: 'NORMAL',
        dangerOnTrue: true,
      ),
    ]);
  }

  // ── Jobs & Maintenance ───────────────────────────────────────

  Widget _buildJobsMaintenance() {
    final failedJobServer = _lastFailedJobServer;
    return Column(
      children: [
        _LabelRow(
          label: 'SQL Agent (Prod)',
          rightText: _sqlAgentRunning ? 'RUNNING' : 'STOPPED',
          rightColor: _sqlAgentRunning ? AppTheme.statusOnline : AppTheme.statusOffline,
        ),
        const SizedBox(height: 8),
        if (failedJobServer?.lastFailedJobName != null) ...[
          _LabelRow(
            label: 'Last Failed Job',
            rightText:
                '${failedJobServer!.lastFailedJobName!}  •  ${failedJobServer.lastFailedJobTime!}',
            rightColor: AppTheme.statusOffline,
          ),
          const SizedBox(height: 8),
        ],
        const Divider(color: AppTheme.border, height: 1),
        const SizedBox(height: 10),
        // Backup grid
        _GridRow(children: [
          _BoolTile(
            label: 'Full Backup',
            state: _allServers.where((s) => s.environment == ServerEnvironment.prod).every((s) => s.fullBackupWithin24h),
            trueLabel: '< 24h',
            falseLabel: 'OVERDUE',
            dangerOnFalse: true,
          ),
          _BoolTile(
            label: 'Log Backup',
            state: _allServers.where((s) => s.environment == ServerEnvironment.prod).every((s) => s.logBackupWithinThreshold),
            trueLabel: '< 15 min',
            falseLabel: 'OVERDUE',
            dangerOnFalse: true,
          ),
        ]),
      ],
    );
  }

  // ── HA / DR ──────────────────────────────────────────────────

  Widget _buildHaDr() {
    return _GridRow(children: [
      _BoolTile(
        label: 'AG / Cluster',
        state: _agHealthy,
        trueLabel: 'HEALTHY',
        falseLabel: 'ISSUE',
        dangerOnFalse: true,
      ),
      _KpiTile(
        label: 'Replica Lag',
        value: _replicaLag,
        valueColor: _replicaLag == 'OK' || _replicaLag == '0s'
            ? AppTheme.statusOnline
            : AppTheme.statusDegraded,
      ),
      _BoolTile(
        label: 'Failover',
        state: _failoverReady,
        trueLabel: 'READY',
        falseLabel: 'NOT READY',
        dangerOnFalse: true,
      ),
    ]);
  }

  // ── Security ─────────────────────────────────────────────────

  Widget _buildSecurity() {
    return _GridRow(children: [
      _BoolTile(
        label: 'Login Failures',
        state: _loginFailureSpike,
        trueLabel: 'SPIKE',
        falseLabel: 'NORMAL',
        dangerOnTrue: true,
      ),
      _BoolTile(
        label: 'SQL Audit',
        state: _sqlAuditRunning,
        trueLabel: 'RUNNING',
        falseLabel: 'STOPPED',
        dangerOnFalse: true,
      ),
      _KpiTile(
        label: 'Expired Certs',
        value: '$_totalExpiredCerts',
        valueColor: _totalExpiredCerts > 0
            ? AppTheme.statusDegraded
            : AppTheme.statusOnline,
      ),
    ]);
  }

  // ── Quick Actions ─────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'QUICK ACTIONS',
            style: TextStyle(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(
                icon: Icons.notifications_active_outlined,
                label: 'View Alerts',
                color: AppTheme.statusOffline,
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.dns_outlined,
                label: 'Servers',
                color: AppTheme.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ServerListScreen()),
                ),
              ),
              _ActionButton(
                icon: Icons.refresh_rounded,
                label: 'Refresh',
                color: AppTheme.statusOnline,
                onTap: _refresh,
              ),
              _ActionButton(
                icon: Icons.build_outlined,
                label: 'Maintenance',
                color: AppTheme.statusDegraded,
                onTap: () {},
              ),
              _ActionButton(
                icon: Icons.phone_in_talk_rounded,
                label: 'On-Call',
                color: const Color(0xFFFF6B6B),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _timestampNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final mo = now.month.toString().padLeft(2, '0');
    return '${now.year}-$mo-$d  $h:$m';
  }

  String _logReuseLabel(LogReuseWait w) {
    switch (w) {
      case LogReuseWait.nothing:
        return 'Nothing';
      case LogReuseWait.logBackup:
        return 'Log Backup';
      case LogReuseWait.activeTransaction:
        return 'Active Txn';
      case LogReuseWait.checkpoint:
        return 'Checkpoint';
      case LogReuseWait.other:
        return 'Other';
    }
  }
}

// ── Enums ────────────────────────────────────────────────────────
enum _GlobalHealth { healthy, degraded, critical }

// ─────────────────────────────────────────────────────────────────
// Server Row Widget
// ─────────────────────────────────────────────────────────────────
class _ServerRow extends StatelessWidget {
  final Server server;
  const _ServerRow({required this.server});

  @override
  Widget build(BuildContext context) {
    final statusColor = AppTheme.statusColor(server.status);
    final envColor = AppTheme.envColor(server.environment);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: envColor, width: 3),
          top: BorderSide(color: AppTheme.border, width: 1),
          right: BorderSide(color: AppTheme.border, width: 1),
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Name + env tag + status icon
          Row(
            children: [
              Expanded(
                child: Text(
                  server.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Tag(
                  text: AppTheme.envLabel(server.environment),
                  color: envColor,
                  small: true),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 4)
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                AppTheme.statusLabel(server.status).toUpperCase(),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: Metrics compact row
          Row(
            children: [
              _CompactMetric(
                  label: 'CPU', value: '${server.cpuUsage.toStringAsFixed(0)}%'),
              _vDivider(),
              _CompactMetric(
                  label: 'MEM',
                  value: '${server.memoryUsage.toStringAsFixed(0)}%'),
              _vDivider(),
              _CompactMetric(
                  label: 'DISK FREE',
                  value: '${server.lowestDiskFreePercent.toStringAsFixed(0)}%',
                  color: server.lowestDiskFreePercent < 15
                      ? AppTheme.statusOffline
                      : server.lowestDiskFreePercent < 25
                          ? AppTheme.statusDegraded
                          : null),
              _vDivider(),
              _CompactMetric(
                  label: 'SQL SVC',
                  value: server.sqlServiceRunning ? 'UP' : 'DOWN',
                  color: server.sqlServiceRunning
                      ? AppTheme.statusOnline
                      : AppTheme.statusOffline),
              _vDivider(),
              _CompactMetric(
                  label: 'REBOOT', value: server.lastReboot),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 22,
        color: AppTheme.border,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );
}

// ─────────────────────────────────────────────────────────────────
// Supporting Widgets
// ─────────────────────────────────────────────────────────────────

class _DashSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _DashSection({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: AppTheme.border, height: 1),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _AlertBadge extends StatelessWidget {
  final int count;
  final Color color;
  final String label;
  const _AlertBadge(
      {required this.count, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: count > 0 ? color.withValues(alpha: 0.15) : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: count > 0 ? color.withValues(alpha: 0.4) : AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: count > 0 ? color : AppTheme.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: count > 0 ? color.withValues(alpha: 0.8) : AppTheme.textMuted,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  const _InfoPill(
      {required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  final List<Widget> children;
  const _GridRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 8)])
          .toList()
        ..removeLast(),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? valueColor;
  const _KpiTile(
      {required this.label,
      required this.value,
      this.unit,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          if (unit != null)
            Text(unit!,
                style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _BoolTile extends StatelessWidget {
  final String label;
  final bool state;
  final String trueLabel;
  final String falseLabel;
  final bool dangerOnTrue;
  final bool dangerOnFalse;
  const _BoolTile({
    required this.label,
    required this.state,
    required this.trueLabel,
    required this.falseLabel,
    this.dangerOnTrue = false,
    this.dangerOnFalse = false,
  });

  Color get _color {
    if (state && dangerOnTrue) return AppTheme.statusOffline;
    if (!state && dangerOnFalse) return AppTheme.statusOffline;
    if (state) return AppTheme.statusOnline;
    return AppTheme.statusOnline;
  }

  @override
  Widget build(BuildContext context) {
    return _KpiTile(
      label: label,
      value: state ? trueLabel : falseLabel,
      valueColor: _color,
    );
  }
}

class _LabelRow extends StatelessWidget {
  final String label;
  final String? rightText;
  final Color? rightColor;
  final Widget? leftChild;
  const _LabelRow(
      {required this.label,
      this.rightText,
      this.rightColor,
      this.leftChild});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        if (leftChild != null) leftChild!,
        if (rightText != null)
          Flexible(
            child: Text(
              rightText!,
              style: TextStyle(
                  color: rightColor ?? AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  final bool small;
  const _Tag({required this.text, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: small ? 9 : 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _CompactMetric(
      {required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 8,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
