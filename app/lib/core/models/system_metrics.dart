class SystemMetrics {
  final int timestamp;
  final CPUStats cpu;
  final MemoryStats memory;
  final DiskStats disk;
  final NetworkStats network;
  final List<ProcessInfo> processes;

  SystemMetrics({
    required this.timestamp,
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
    required this.processes,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      timestamp: json['timestamp'] as int? ?? 0,
      cpu: CPUStats.fromJson(json['cpu'] as Map<String, dynamic>? ?? {}),
      memory: MemoryStats.fromJson(json['memory'] as Map<String, dynamic>? ?? {}),
      disk: DiskStats.fromJson(json['disk'] as Map<String, dynamic>? ?? {}),
      network: NetworkStats.fromJson(json['network'] as Map<String, dynamic>? ?? {}),
      processes: (json['processes'] as List<dynamic>?)
              ?.map((p) => ProcessInfo.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class CPUStats {
  final double percentTotal;
  final List<double> percentPerCore;
  final int freqMhz;
  final int coreCount;
  final int threadCount;

  CPUStats({
    required this.percentTotal,
    required this.percentPerCore,
    required this.freqMhz,
    required this.coreCount,
    required this.threadCount,
  });

  factory CPUStats.fromJson(Map<String, dynamic> json) {
    return CPUStats(
      percentTotal: (json['percent_total'] as num?)?.toDouble() ?? 0.0,
      percentPerCore: (json['percent_per_core'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      freqMhz: json['freq_mhz'] as int? ?? 0,
      coreCount: json['core_count'] as int? ?? 0,
      threadCount: json['thread_count'] as int? ?? 0,
    );
  }
}

class MemoryStats {
  final double totalGb;
  final double usedGb;
  final double percent;

  MemoryStats({
    required this.totalGb,
    required this.usedGb,
    required this.percent,
  });

  factory MemoryStats.fromJson(Map<String, dynamic> json) {
    return MemoryStats(
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DiskStats {
  final double totalGb;
  final double usedGb;
  final double percent;
  final double readMbS;
  final double writeMbS;

  DiskStats({
    required this.totalGb,
    required this.usedGb,
    required this.percent,
    required this.readMbS,
    required this.writeMbS,
  });

  factory DiskStats.fromJson(Map<String, dynamic> json) {
    return DiskStats(
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      readMbS: (json['read_mb_s'] as num?)?.toDouble() ?? 0.0,
      writeMbS: (json['write_mb_s'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class NetworkStats {
  final double sentMbS;
  final double recvMbS;
  final double totalSentGb;
  final double totalRecvGb;

  NetworkStats({
    required this.sentMbS,
    required this.recvMbS,
    required this.totalSentGb,
    required this.totalRecvGb,
  });

  factory NetworkStats.fromJson(Map<String, dynamic> json) {
    return NetworkStats(
      sentMbS: (json['sent_mb_s'] as num?)?.toDouble() ?? 0.0,
      recvMbS: (json['recv_mb_s'] as num?)?.toDouble() ?? 0.0,
      totalSentGb: (json['total_sent_gb'] as num?)?.toDouble() ?? 0.0,
      totalRecvGb: (json['total_recv_gb'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProcessInfo {
  final int pid;
  final String name;
  final double cpuPercent;
  final double memoryMb;
  final String status;
  final int connections;

  ProcessInfo({
    required this.pid,
    required this.name,
    required this.cpuPercent,
    required this.memoryMb,
    required this.status,
    required this.connections,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memoryMb: (json['memory_mb'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'unknown',
      connections: json['connections'] as int? ?? 0,
    );
  }
}
