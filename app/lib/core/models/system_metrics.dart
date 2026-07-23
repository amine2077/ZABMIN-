const int kZabminProtocolVersion = 3;

class SystemMetrics {
  final int version;
  final int timestamp;
  final CPUStats cpu;
  final MemoryStats memory;
  final DiskStats disk;
  final NetworkStats network;
  final List<ProcessInfo> processes;
  final List<GPUStats> gpu;
  final BatteryStats? battery;

  SystemMetrics({
    required this.version,
    required this.timestamp,
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.network,
    required this.processes,
    required this.gpu,
    this.battery,
  });

  factory SystemMetrics.fromJson(Map<String, dynamic> json) {
    return SystemMetrics(
      version: json['version'] as int? ?? 0,
      timestamp: json['timestamp'] as int? ?? 0,
      cpu: CPUStats.fromJson(json['cpu'] as Map<String, dynamic>? ?? {}),
      memory: MemoryStats.fromJson(
        json['memory'] as Map<String, dynamic>? ?? {},
      ),
      disk: DiskStats.fromJson(json['disk'] as Map<String, dynamic>? ?? {}),
      network: NetworkStats.fromJson(
        json['network'] as Map<String, dynamic>? ?? {},
      ),
      processes:
          (json['processes'] as List<dynamic>?)
              ?.map((p) => ProcessInfo.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      gpu:
          (json['gpu'] as List<dynamic>?)
              ?.map((g) => GPUStats.fromJson(g as Map<String, dynamic>))
              .toList() ??
          [],
      battery: json['battery'] != null
          ? BatteryStats.fromJson(json['battery'] as Map<String, dynamic>)
          : null,
    );
  }
}

class BatteryStats {
  final double percent;
  final bool powerPlugged;
  final int? secsLeft;

  BatteryStats({
    required this.percent,
    required this.powerPlugged,
    this.secsLeft,
  });

  factory BatteryStats.fromJson(Map<String, dynamic> json) {
    return BatteryStats(
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      powerPlugged: json['power_plugged'] as bool? ?? false,
      secsLeft: json['secs_left'] as int?,
    );
  }
}

class CPUStats {
  final double percentTotal;
  final List<double> percentPerCore;
  final int freqMhz;
  final int coreCount;
  final int threadCount;
  final double? temperatureC;
  final bool throttled;

  CPUStats({
    required this.percentTotal,
    required this.percentPerCore,
    required this.freqMhz,
    required this.coreCount,
    required this.threadCount,
    this.temperatureC,
    this.throttled = false,
  });

  factory CPUStats.fromJson(Map<String, dynamic> json) {
    return CPUStats(
      percentTotal: (json['percent_total'] as num?)?.toDouble() ?? 0.0,
      percentPerCore:
          (json['percent_per_core'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      freqMhz: json['freq_mhz'] as int? ?? 0,
      coreCount: json['core_count'] as int? ?? 0,
      threadCount: json['thread_count'] as int? ?? 0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      throttled: json['throttled'] as bool? ?? false,
    );
  }
}

class MemoryStats {
  final double totalGb;
  final double usedGb;
  final double percent;
  final double availableGb;
  final double cachedGb;
  final int speedMhz;

  MemoryStats({
    required this.totalGb,
    required this.usedGb,
    required this.percent,
    required this.availableGb,
    required this.cachedGb,
    required this.speedMhz,
  });

  factory MemoryStats.fromJson(Map<String, dynamic> json) {
    return MemoryStats(
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      availableGb: (json['available_gb'] as num?)?.toDouble() ?? 0.0,
      cachedGb: (json['cached_gb'] as num?)?.toDouble() ?? 0.0,
      speedMhz: json['speed_mhz'] as int? ?? 0,
    );
  }
}

class DiskPartition {
  final String device;
  final String mountpoint;
  final String label;
  final String filesystem;
  final double totalGb;
  final double usedGb;
  final double freeGb;
  final double percent;
  final String physicalDrive;
  final double readMbS;
  final double writeMbS;

  DiskPartition({
    required this.device,
    required this.mountpoint,
    required this.label,
    required this.filesystem,
    required this.totalGb,
    required this.usedGb,
    required this.freeGb,
    required this.percent,
    required this.physicalDrive,
    required this.readMbS,
    required this.writeMbS,
  });

  factory DiskPartition.fromJson(Map<String, dynamic> json) {
    return DiskPartition(
      device: json['device'] as String? ?? '',
      mountpoint: json['mountpoint'] as String? ?? '',
      label: json['label'] as String? ?? '',
      filesystem: json['filesystem'] as String? ?? '',
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      freeGb: (json['free_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      physicalDrive: json['physical_drive'] as String? ?? '',
      readMbS: (json['read_mb_s'] as num?)?.toDouble() ?? 0.0,
      writeMbS: (json['write_mb_s'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DiskStats {
  final double totalGb;
  final double usedGb;
  final double percent;
  final double readMbS;
  final double writeMbS;
  final List<DiskPartition> partitions;

  DiskStats({
    required this.totalGb,
    required this.usedGb,
    required this.percent,
    required this.readMbS,
    required this.writeMbS,
    required this.partitions,
  });

  factory DiskStats.fromJson(Map<String, dynamic> json) {
    return DiskStats(
      totalGb: (json['total_gb'] as num?)?.toDouble() ?? 0.0,
      usedGb: (json['used_gb'] as num?)?.toDouble() ?? 0.0,
      percent: (json['percent'] as num?)?.toDouble() ?? 0.0,
      readMbS: (json['read_mb_s'] as num?)?.toDouble() ?? 0.0,
      writeMbS: (json['write_mb_s'] as num?)?.toDouble() ?? 0.0,
      partitions:
          (json['partitions'] as List<dynamic>?)
              ?.map((p) => DiskPartition.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
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

class GPUStats {
  final String name;
  final double vramTotalMb;
  final double vramUsedMb;
  final double vramPercent;
  final double temperatureC;
  final double fanPercent;
  final double utilizationPercent;
  final String driverVersion;

  GPUStats({
    required this.name,
    required this.vramTotalMb,
    required this.vramUsedMb,
    required this.vramPercent,
    required this.temperatureC,
    required this.fanPercent,
    required this.utilizationPercent,
    required this.driverVersion,
  });

  factory GPUStats.fromJson(Map<String, dynamic> json) {
    return GPUStats(
      name: json['name'] as String? ?? 'Unknown GPU',
      vramTotalMb: (json['vram_total_mb'] as num?)?.toDouble() ?? 0.0,
      vramUsedMb: (json['vram_used_mb'] as num?)?.toDouble() ?? 0.0,
      vramPercent: (json['vram_percent'] as num?)?.toDouble() ?? 0.0,
      temperatureC: (json['temperature_c'] as num?)?.toDouble() ?? 0.0,
      fanPercent: (json['fan_percent'] as num?)?.toDouble() ?? 0.0,
      utilizationPercent:
          (json['utilization_percent'] as num?)?.toDouble() ?? 0.0,
      driverVersion: json['driver_version'] as String? ?? '',
    );
  }
}

class ProcessInfo {
  final int pid;
  final int ppid;
  final String name;
  final double cpuPercent;
  final double memoryMb;
  final String status;
  final int connections;

  ProcessInfo({
    required this.pid,
    this.ppid = 0,
    required this.name,
    required this.cpuPercent,
    required this.memoryMb,
    required this.status,
    required this.connections,
  });

  factory ProcessInfo.fromJson(Map<String, dynamic> json) {
    return ProcessInfo(
      pid: json['pid'] as int? ?? 0,
      ppid: json['ppid'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      cpuPercent: (json['cpu_percent'] as num?)?.toDouble() ?? 0.0,
      memoryMb: (json['memory_mb'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'unknown',
      connections: json['connections'] as int? ?? 0,
    );
  }
}
