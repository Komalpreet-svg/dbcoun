import 'package:flutter/material.dart';
import '../models/server.dart';
import '../data/server_data.dart';
import '../theme/app_theme.dart';
import '../widgets/server_card.dart';

class ServerListScreen extends StatefulWidget {
  const ServerListScreen({super.key});

  @override
  State<ServerListScreen> createState() => _ServerListScreenState();
}

class _ServerListScreenState extends State<ServerListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _refreshing = false;

  final _envs = [
    ServerEnvironment.dev,
    ServerEnvironment.qa,
    ServerEnvironment.prod,
  ];

  final _labels = ['DEV', 'QA', 'PROD'];
  final _colors = [AppTheme.devColor, AppTheme.qaColor, AppTheme.prodColor];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Server> _serversFor(ServerEnvironment env) =>
      sampleServers.where((s) => s.environment == env).toList();

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentEnv = _envs[_tabController.index];
    final servers = _serversFor(currentEnv);
    final onlineCount =
        servers.where((s) => s.status == ServerStatus.online).length;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Server Manager'),
            Text(
              '$onlineCount / ${servers.length} online',
              style: TextStyle(
                color: _colors[_tabController.index].withValues(alpha: 0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _refreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _refresh,
                    tooltip: 'Refresh',
                  ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: List.generate(3, (i) {
                final isSelected = _tabController.index == i;
                final count = _serversFor(_envs[i]).length;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _labels[i],
                        style: TextStyle(
                          color: isSelected ? _colors[i] : AppTheme.textMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _colors[i].withValues(alpha: 0.2)
                              : AppTheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? _colors[i] : AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              indicatorColor: _colors[_tabController.index],
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _envs
            .map((env) => _EnvTab(env: env, onRefresh: _refresh))
            .toList(),
      ),
    );
  }
}

class _EnvTab extends StatelessWidget {
  final ServerEnvironment env;
  final Future<void> Function() onRefresh;
  const _EnvTab({required this.env, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final servers =
        sampleServers.where((s) => s.environment == env).toList();
    final envColor = AppTheme.envColor(env);

    if (servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dns_outlined, size: 48, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'No servers found',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Stats header
    final total = servers.length;
    final online =
        servers.where((s) => s.status == ServerStatus.online).length;
    final degraded =
        servers.where((s) => s.status == ServerStatus.degraded).length;
    final offline =
        servers.where((s) => s.status == ServerStatus.offline).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: envColor,
      backgroundColor: AppTheme.surface,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  _StatChip(
                      count: online,
                      label: 'Online',
                      color: AppTheme.statusOnline),
                  const SizedBox(width: 8),
                  _StatChip(
                      count: degraded,
                      label: 'Degraded',
                      color: AppTheme.statusDegraded),
                  const SizedBox(width: 8),
                  _StatChip(
                      count: offline,
                      label: 'Offline',
                      color: AppTheme.statusOffline),
                  const Spacer(),
                  Text(
                    '$total total',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => ServerCard(server: servers[index]),
                childCount: servers.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _StatChip(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
