import 'package:flutter/material.dart';
import '../models/server.dart';
import '../theme/app_theme.dart';

class ServerDetailScreen extends StatefulWidget {
  final Server server;
  const ServerDetailScreen({super.key, required this.server});

  @override
  State<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends State<ServerDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _cpuAnim;
  late Animation<double> _memAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cpuAnim = Tween<double>(begin: 0, end: widget.server.cpuUsage / 100)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _memAnim = Tween<double>(begin: 0, end: widget.server.memoryUsage / 100)
        .animate(CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.15, 1.0, curve: Curves.easeOut)));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.server;
    final envColor = AppTheme.envColor(server.environment);
    final statusColor = AppTheme.statusColor(server.status);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          server.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: envColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: envColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              AppTheme.envLabel(server.environment),
              style: TextStyle(
                color: envColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Hero ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  // Glowing status dot
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: statusColor.withValues(alpha: 0.4), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: statusColor.withValues(alpha: 0.25),
                          blurRadius: 16,
                        )
                      ],
                    ),
                    child:
                        Center(child: Icon(Icons.circle, color: statusColor, size: 20)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTheme.statusLabel(server.status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last checked ${_elapsed(server.lastChecked)}',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Connection Info ───────────────────────────────
            _Section(
              title: 'Connection',
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.dns_outlined,
                    label: 'Host',
                    value: server.host,
                    mono: true,
                  ),
                  _InfoRow(
                    icon: Icons.settings_ethernet,
                    label: 'Port',
                    value: '${server.port}',
                    mono: true,
                  ),
                  _InfoRow(
                    icon: Icons.public,
                    label: 'Region',
                    value: server.region,
                  ),
                  _InfoRow(
                    icon: Icons.code,
                    label: 'Version',
                    value: server.version,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Performance ───────────────────────────────────
            _Section(
              title: 'Performance',
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _AnimatedMetric(
                    label: 'CPU Usage',
                    value: server.cpuUsage,
                    animation: _cpuAnim,
                    color: _cpuColor(server.cpuUsage),
                    icon: Icons.memory,
                  ),
                  const SizedBox(height: 20),
                  _AnimatedMetric(
                    label: 'Memory Usage',
                    value: server.memoryUsage,
                    animation: _memAnim,
                    color: _memColor(server.memoryUsage),
                    icon: Icons.storage,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── SQL Jobs ──────────────────────────────────────
            if (server.sqlJobs.isNotEmpty)
              _Section(
                title: 'SQL Agent Jobs',
                child: Column(
                  children: server.sqlJobs
                      .map((job) => _SqlJobRow(job: job))
                      .toList(),
                ),
              ),
            if (server.sqlJobs.isNotEmpty) const SizedBox(height: 16),

            // ── Disk Space ────────────────────────────────────
            if (server.diskVolumes.isNotEmpty)
              _Section(
                title: 'Disk Space',
                child: Column(
                  children: server.diskVolumes
                      .map((vol) => _DiskVolumeRow(volume: vol))
                      .toList(),
                ),
              ),
            if (server.diskVolumes.isNotEmpty) const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _elapsed(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Color _cpuColor(double v) {
    if (v > 80) return AppTheme.statusOffline;
    if (v > 60) return AppTheme.statusDegraded;
    return AppTheme.statusOnline;
  }

  Color _memColor(double v) {
    if (v > 85) return AppTheme.statusOffline;
    if (v > 70) return AppTheme.statusDegraded;
    return AppTheme.statusOnline;
  }
}

// ── Helper Widgets ────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool mono;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.mono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: mono ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMetric extends StatelessWidget {
  final String label;
  final double value;
  final Animation<double> animation;
  final Color color;
  final IconData icon;

  const _AnimatedMetric({
    required this.label,
    required this.value,
    required this.animation,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: animation,
              builder: (_, a) => Text(
                '${(animation.value * 100).toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: AnimatedBuilder(
            animation: animation,
            builder: (_, b) => LinearProgressIndicator(
              value: animation.value,
              minHeight: 10,
              backgroundColor: AppTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }
}

// ── SQL Job Row ───────────────────────────────────────────────

class _SqlJobRow extends StatelessWidget {
  final SqlJob job;
  const _SqlJobRow({required this.job});

  Color get _statusColor {
    switch (job.status) {
      case SqlJobStatus.running:
        return const Color(0xFF3B9EFF);
      case SqlJobStatus.succeeded:
        return AppTheme.statusOnline;
      case SqlJobStatus.failed:
        return AppTheme.statusOffline;
      case SqlJobStatus.disabled:
        return AppTheme.textMuted;
    }
  }

  IconData get _statusIcon {
    switch (job.status) {
      case SqlJobStatus.running:
        return Icons.repeat_rounded;
      case SqlJobStatus.succeeded:
        return Icons.check_circle_outline_rounded;
      case SqlJobStatus.failed:
        return Icons.error_outline_rounded;
      case SqlJobStatus.disabled:
        return Icons.block_rounded;
    }
  }

  String get _statusLabel {
    switch (job.status) {
      case SqlJobStatus.running:
        return 'Running';
      case SqlJobStatus.succeeded:
        return 'Succeeded';
      case SqlJobStatus.failed:
        return 'Failed';
      case SqlJobStatus.disabled:
        return 'Disabled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Job name + status badge
          Row(
            children: [
              Icon(_statusIcon, size: 16, color: _statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _statusColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Meta row: last run / next run / duration
          Row(
            children: [
              Flexible(
                child: _JobMeta(
                  icon: Icons.history_rounded,
                  label: 'Last',
                  value: job.lastRun,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _JobMeta(
                  icon: Icons.schedule_rounded,
                  label: 'Next',
                  value: job.nextRun,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _JobMeta(
                  icon: Icons.timer_outlined,
                  label: 'Duration',
                  value: job.duration,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
        ],
      ),
    );
  }
}

class _JobMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _JobMeta({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$label: ',
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Disk Volume Row ───────────────────────────────────────────

class _DiskVolumeRow extends StatelessWidget {
  final DiskVolume volume;
  const _DiskVolumeRow({required this.volume});

  Color _diskColor(double pct) {
    if (pct > 90) return AppTheme.statusOffline;
    if (pct > 75) return AppTheme.statusDegraded;
    return AppTheme.statusOnline;
  }

  String _fmt(double gb) {
    if (gb >= 1000) return '${(gb / 1000).toStringAsFixed(1)} TB';
    return '${gb.toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final pct = volume.usedPercent;
    final color = _diskColor(pct);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mount + usage summary
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 15, color: AppTheme.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  volume.mount,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                '${pct.toStringAsFixed(1)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 8,
              backgroundColor: AppTheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          // Used / Free / Total
          Row(
            children: [
              Text(
                '${_fmt(volume.usedGb)} used',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '${_fmt(volume.freeGb)} free  •  ${_fmt(volume.totalGb)} total',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, height: 1),
        ],
      ),
    );
  }
}
