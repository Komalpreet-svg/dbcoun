enum ServerEnvironment { dev, qa, prod }

enum ServerStatus { online, offline, degraded }

enum SqlJobStatus { running, failed, succeeded, disabled }

enum AgRole { primary, secondary, none }

enum AgSyncState { healthy, lagging, notSynchronizing, none }

enum LogReuseWait {
  nothing,
  logBackup,
  activeTransaction,
  checkpoint,
  other,
}

class SqlJob {
  final String name;
  final SqlJobStatus status;
  final String lastRun;
  final String nextRun;
  final String duration;

  const SqlJob({
    required this.name,
    required this.status,
    required this.lastRun,
    required this.nextRun,
    required this.duration,
  });
}

class DiskVolume {
  final String mount;
  final double totalGb;
  final double usedGb;

  const DiskVolume({
    required this.mount,
    required this.totalGb,
    required this.usedGb,
  });

  double get usedPercent => totalGb > 0 ? (usedGb / totalGb) * 100 : 0;
  double get freeGb => totalGb - usedGb;
  double get freePercent => totalGb > 0 ? (freeGb / totalGb) * 100 : 0;
}

class DatabaseInfo {
  final String name;
  final bool isOffline;
  final bool isRestoring;
  final bool isSuspect;
  final double dataFreePercent;
  final double logFreePercent;
  final LogReuseWait logReuseWait;

  const DatabaseInfo({
    required this.name,
    this.isOffline = false,
    this.isRestoring = false,
    this.isSuspect = false,
    this.dataFreePercent = 30,
    this.logFreePercent = 40,
    this.logReuseWait = LogReuseWait.nothing,
  });
}

class Server {
  final String id;
  final String name;
  final String host;
  final int port;
  final ServerEnvironment environment;
  final ServerStatus status;
  final String region;
  final double cpuUsage;
  final double memoryUsage;
  final double lowestDiskFreePercent;
  final String version;
  final DateTime lastChecked;
  final bool sqlServiceRunning;
  final String lastReboot; // e.g. "14d ago"

  // SQL Agent
  final bool sqlAgentRunning;
  final String? lastFailedJobName;
  final String? lastFailedJobTime;

  // Backup status
  final bool fullBackupWithin24h;
  final bool logBackupWithinThreshold;
  final String logBackupThresholdLabel; // e.g. "< 15 min"

  // DB health
  final List<DatabaseInfo> databases;

  // AG / HA
  final AgRole agRole;
  final AgSyncState agSyncState;
  final bool agHealthy;
  final String replicaLag; // e.g. "0s", "4.2s"
  final bool failoverReady;

  // Performance signals
  final bool blockingPresent;
  final int longRunningQueriesCount;
  final bool requestQueueHigh;
  final bool tempDbPressure;

  // Security
  final bool loginFailureSpike;
  final bool sqlAuditRunning;
  final int expiredCertCount;

  // Jobs
  final List<SqlJob> sqlJobs;
  final List<DiskVolume> diskVolumes;

  const Server({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.environment,
    required this.status,
    required this.region,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.version,
    required this.lastChecked,
    this.lowestDiskFreePercent = 30,
    this.sqlServiceRunning = true,
    this.lastReboot = '7d ago',
    this.sqlAgentRunning = true,
    this.lastFailedJobName,
    this.lastFailedJobTime,
    this.fullBackupWithin24h = true,
    this.logBackupWithinThreshold = true,
    this.logBackupThresholdLabel = '< 15 min',
    this.databases = const [],
    this.agRole = AgRole.none,
    this.agSyncState = AgSyncState.none,
    this.agHealthy = true,
    this.replicaLag = '0s',
    this.failoverReady = true,
    this.blockingPresent = false,
    this.longRunningQueriesCount = 0,
    this.requestQueueHigh = false,
    this.tempDbPressure = false,
    this.loginFailureSpike = false,
    this.sqlAuditRunning = true,
    this.expiredCertCount = 0,
    this.sqlJobs = const [],
    this.diskVolumes = const [],
  });
}
