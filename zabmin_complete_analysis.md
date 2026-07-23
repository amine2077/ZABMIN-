# Zabmin — Complete Application Analysis

## Overview

**Zabmin** is a local, offline-first Windows system monitoring dashboard — a lightweight, open-source alternative to Task Manager. It uses a **two-process architecture**: a Python WebSocket agent that collects real-time system metrics, and a Flutter Windows desktop app that displays them in a live dashboard with dark UI and real-time charts.

---

## 1. Project Structure

```
D:\zabmin\zabmin\
├── agent/                          # Python 3.13 WebSocket server (metrics collection)
│   ├── agent.py                    # Main entry point — WebSocket server, broadcast loop
│   ├── cpu_state.py                # Windows Performance Counters (CPU & RAM) via PDH + psutil
│   ├── database.py                 # SQLite history storage (5s intervals, WAL mode)
│   ├── requirements.txt            # Python dependencies
│   ├── run_agent.vbs              # VBScript to launch agent hidden (no console window)
│   ├── collectors/                 # psutil/WMI-based metric collectors
│   │   ├── __init__.py             # Re-exports all collect() functions
│   │   ├── cpu.py                  # CPU usage, per-core, frequency, temperature, throttling
│   │   ├── memory.py               # RAM total/used/available/cached/speed (Task Manager match)
│   │   ├── disk.py                 # Per-partition disk usage + I/O speed (real elapsed time delta)
│   │   ├── network.py              # Network upload/download speed + total transferred
│   │   ├── processes.py            # Top 30 processes by CPU (divided by logical cores)
│   │   ├── gpu.py                  # GPU via NVML (NVIDIA) + WMI (Intel/AMD) + DXGI VRAM correction
│   │   └── battery.py             # Battery percentage, plugged-in status, time remaining
│   ├── tests/                      # pytest test suite (unit tests with mocks)
│   │   ├── conftest.py             # Test path configuration
│   │   ├── test_collectors_cpu.py
│   │   ├── test_collectors_memory.py
│   │   ├── test_collectors_disk.py
│   │   ├── test_collectors_network.py
│   │   ├── test_collectors_processes.py
│   │   ├── test_collectors_gpu.py
│   │   └── test_collectors_battery.py
│   └── logs/                       # Rotating log files (5 MB each, 3 backups)
│       └── agent.log
│
├── app/                            # Flutter 3.41 Windows desktop app
│   ├── lib/
│   │   ├── main.dart               # App entry, agent subprocess start, tray, window management
│   │   ├── core/
│   │   │   ├── models/
│   │   │   │   └── system_metrics.dart  # All data models: SystemMetrics, CPUStats, MemoryStats,
│   │   │   │                            # DiskStats, DiskPartition, NetworkStats, GPUStats,
│   │   │   │                            # ProcessInfo, BatteryStats
│   │   │   ├── services/
│   │   │   │   ├── websocket_service.dart  # WebSocket client, auto-reconnect, request/response
│   │   │   │   ├── alerts_service.dart     # Alert rules engine with cooldowns & toast notifications
│   │   │   │   ├── history_service.dart    # Local SQLite history (5s write interval, 5y retention)
│   │   │   │   ├── settings_service.dart   # SharedPreferences-based settings + launch-at-startup
│   │   │   │   └── report_exporter.dart    # CSV/JSON export of historical metrics
│   │   │   ├── theme/
│   │   │   │   ├── zcolors.dart            # Color palette, semantic helpers, shadows, radii
│   │   │   │   └── app_theme.dart          # ZText styles, ZTheme dark, ZPaints glass/gradient
│   │   │   └── nav_items.dart              # Navigation item definitions
│   │   ├── screens/
│   │   │   ├── dashboard_screen.dart       # Main landing — 4 metric cards, 2×1 chart grid, process table
│   │   │   ├── processes_screen.dart       # Full process list, tree/flat mode, kill, priority, connections panel
│   │   │   ├── network_screen.dart         # Download/upload throughput, totals, speed bars, chart
│   │   │   ├── disk_screen.dart            # Storage usage by disk group, partitions, I/O chips, chart
│   │   │   ├── ram_screen.dart             # Memory arc, used/free/total/available/cached/speed, chart
│   │   │   ├── gpu_screen.dart             # GPU cards (util, VRAM, temp, fan), search, charts
│   │   │   └── settings_screen.dart        # Alert thresholds (sliders), behavior toggles
│   │   └── widgets/
│   │       ├── app_rail.dart               # Compact icon-only navigation rail (narrow windows)
│   │       ├── glass_card.dart             # Crisp minimal glass card with hover lift effect
│   │       ├── screen_shell.dart           # Page shell with accent bar, title, scrollable content
│   │       ├── metric_grid.dart            # Responsive metric card grid (2/3/4 columns)
│   │       ├── metric_card.dart            # Metric card with value, arc, gradient bar
│   │       ├── metric_chart.dart           # fl_chart wrapper with time range selector + history fetch
│   │       ├── chart_chrome.dart           # Chart container, grid/title helpers, gradient line config
│   │       ├── circular_progress_arc.dart  # Custom painter arc with gradient + glow edge
│   │       ├── core_bar_grid.dart          # Per-core CPU usage bars
│   │       ├── process_table.dart          # Top processes table with sort, CPU bar, status pill, kill
│   │       ├── animated_metric.dart        # TweenAnimationBuilder numeric display
│   │       ├── search_field.dart           # Search input with result count badge
│   │       ├── time_range_selector.dart    # 1m / 15m / 1h range toggle pills
│   │       └── export_dialog.dart          # Export report dialog with range picker + format choice
│   ├── windows/
│   │   └── runner/                         # C++ Windows runner (WinMain, FlutterWindow, CMake)
│   ├── assets/
│   │   └── tray_icon.png                   # System tray icon
│   ├── pubspec.yaml                        # Dart dependencies
│   ├── analysis_options.yaml               # flutter_lints rules
│   └── .metadata                           # Flutter project metadata
│
├── scripts/
│   └── debug/                              # Debug/test scripts (various WebSocket tests)
│       ├── test_ws.py ~ test_ws5.py
│       ├── test_thread.py
│       ├── test_slow.py
│       ├── test_hang.py / test_hang2.py
│       └── test_async_collectors.py
│
├── .github/workflows/
│   └── ci.yml                              # CI: Python ruff+pytest, Flutter analyze+test
│
├── .qoder/                                 # Qoder AI coding agent config
│   ├── settings.json                       # PostToolUse format hook
│   ├── settings.local.json                 # Permission allowlist
│   └── hooks/format.py                     # Auto-format .dart and .py files
│
├── README.md                               # Project readme
├── ARCHITECTURE.md                         # Technical architecture document
├── AGENTS.md                               # AI agent guidance
├── LICENSE                                 # MIT License
└── .gitignore
```

---

## 2. Technology Stack

### 2.1 Python Agent

| Technology | Version | Purpose |
|---|---|---|
| Python | 3.13 | Agent runtime |
| websockets | 15.0.1 | WebSocket server for real-time metric broadcast |
| psutil | 7.0.0 | Cross-process system metrics (CPU, memory, disk, network, processes) |
| wmi | 1.5.1 | Windows Management Instrumentation — GPU info, CPU temperature, RAM speed |
| pynvml | 12.0.0 | NVIDIA Management Library — GPU metrics for NVIDIA cards |
| sqlite3 | stdlib | Local metrics history database |
| ctypes | stdlib | Windows PDH performance counters for CPU/RAM |
| asyncio | stdlib | Async event loop for WebSocket server |
| threading | stdlib | Dedicated thread for CPU monitoring |
| logging | stdlib | Rotating file + console logging |
| pytest | 9.1.1 | Unit testing |
| pytest-mock | 3.15.1 | Mocking for tests |
| pythoncom | (pywin32) | COM initialization for WMI calls in threads |
| ruff | (dev) | Python linter and formatter |

### 2.2 Flutter App

| Technology | Version | Purpose |
|---|---|---|
| Flutter | 3.41 | UI framework |
| Dart SDK | ^3.11.0 | Programming language |
| web_socket_channel | ^3.0.3 | WebSocket client to agent |
| fl_chart | ^1.0.0 | Real-time line charts |
| provider | ^6.1.5 | State management (ChangeNotifier) |
| window_manager | ^0.4.3 | Custom window chrome, maximize, draggable titlebar |
| google_fonts | ^6.3.0 | Inter + JetBrains Mono fonts |
| sqflite_common_ffi | ^2.3.3 | Local SQLite history database |
| path_provider | ^2.1.4 | App support directory for SQLite |
| file_picker | ^8.1.4 | Save-file dialog for report export |
| shared_preferences | ^2.3.0 | Persistent settings storage |
| launch_at_startup | ^0.5.0 | Auto-start on Windows login |
| tray_manager | ^0.5.0 | System tray icon + context menu |
| local_notifier | ^0.1.6 | Windows toast notifications for critical alerts |
| flutter_lints | ^6.0.0 | Lint rules (dev dependency) |

---

## 3. Architecture — In Detail

### 3.1 Two-Process Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Flutter App (zabmin.exe)                         │
│                                                                     │
│  main()                                                             │
│    ├── _startAgent() → Process.start('wscript', 'run_agent.vbs')   │
│    ├── window_manager setup (1280×800, hidden titlebar)             │
│    ├── tray_manager setup (icon + context menu)                     │
│    ├── local_notifier setup                                         │
│    ├── HistoryService.init() → FFI SQLite                           │
│    ├── SettingsService.load() → SharedPreferences                   │
│    ├── launchAtStartup.setup()                                      │
│    └── runApp() → MultiProvider                                     │
│         ├── ChangeNotifierProvider(WebSocketService)                │
│         ├── ChangeNotifierProvider(AlertsService)                   │
│         ├── ChangeNotifierProvider(HistoryService)                  │
│         └── ChangeNotifierProvider(SettingsService)                 │
│                                                                     │
│  AppShell (StatefulWidget + WindowListener + TrayListener)          │
│    ├── _buildTitleBar() → custom drag-to-move + min/max/close      │
│    ├── Connection status → loading / error / dashboard              │
│    ├── onWindowClose → minimize-to-tray or kill agent + exit        │
│    └── trayMenuClick → show / exit                                  │
│                                                                     │
│  DashboardScreen (StatefulWidget)                                   │
│    ├── AppRail (compact, <1100px) OR _Sidebar (full)                │
│    ├── _buildContent() routes to 7 sub-screens by nav selection      │
│    └── _DashboardHome → Consumer2<WebSocketService, AlertsService>  │
│         ├── MetricGrid (4 responsive cards: CPU, RAM, Disk, Net)    │
│         ├── MetricChart (CPU & RAM dual-line, 60s rolling)          │
│         ├── CoreBarGrid (per-core CPU bars)                         │
│         └── ProcessTable (top 9 processes, inline kill)             │
│                                                                     │
└─────────────────────────┬───────────────────────────────────────────┘
                          │ WebSocket ws://localhost:8765
                          │ JSON every 1 second (protocol v3)
                          ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Python Agent (python agent.py)                    │
│                                                                     │
│  main()                                                             │
│    ├── Writes PID to agent.pid                                      │
│    ├── Starts perf_monitor_loop (threading.Thread, daemon)          │
│    │   └── Windows PDH counters for CPU + RAM                       │
│    ├── Starts WebSocket server on localhost:8765                    │
│    └── Starts broadcast_loop (async, every 1s)                      │
│         ├── gather_metrics() → 7 collectors in parallel threads     │
│         └── Broadcast JSON to all connected clients                 │
│              └── Every 5th iteration → database.insert_metrics()    │
│                                                                     │
│  Handler — per-client WebSocket message handler                     │
│    ├── "kill_process" → psutil.Process(pid).kill()                 │
│    ├── "get_process_connections" → net_connections()               │
│    ├── "set_priority" → p.nice(priority)                           │
│    ├── "get_priority" → p.nice()                                   │
│    ├── "get_history" → database.get_history(minutes)               │
│    └── "shutdown" → sets _shutdown_event → graceful exit           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Data Flow (Agent Side)

```
┌─────────────────────────────────────────────────────────────────┐
│                        Every 1 Second                            │
│                                                                  │
│  perf_monitor_loop (thread)                                      │
│  ├── PDH.PdhCollectQueryData() (CPU %)                          │
│  ├── psutil.cpu_percent(interval=None, percpu=True)              │
│  └── psutil.virtual_memory() → total - available                 │
│      ↓                                                           │
│  cpu_state.py (thread-safe shared state via Lock)                │
│  - _cpu_percent_total: float                                     │
│  - _cpu_percent_per_core: list[float]                            │
│  - _ram_percent / _ram_used_gb / _ram_total_gb                  │
│      ↓                                                           │
│  broadcast_loop (async, every 1s via _shutdown_event.wait)       │
│  └── gather_metrics()                                            │
│      ├── _run_in_thread(cpu.collect, with_com=True)              │
│      │   └── Reads cpu_state.read_state()                        │
│      ├── _run_in_thread(memory.collect, with_com=True)           │
│      │   └── psutil.virtual_memory() + WMI RAM speed            │
│      ├── _run_in_thread(disk.collect)                            │
│      │   ├── psutil.disk_partitions() + disk_usage()            │
│      │   ├── _get_volume_label() via Win32 API                   │
│      │   ├── _get_physical_drive_number() via IOCTL              │
│      │   └── psutil.disk_io_counters(perdisk=True) → delta/s     │
│      ├── _run_in_thread(network.collect)                         │
│      │   └── psutil.net_io_counters() → delta/s                  │
│      ├── _run_in_thread(processes.collect)                       │
│      │   └── psutil.process_iter() → sorted top 30               │
│      ├── _run_in_thread(gpu.collect, with_com=True)              │
│      │   ├── NVML (NVIDIA GPU metrics)                           │
│      │   ├── WMI Win32_VideoController (non-NVIDIA)              │
│      │   └── DXGI dedicated VRAM correction (>4GB fix)           │
│      └── _run_in_thread(battery.collect)                         │
│          └── psutil.sensors_battery()                            │
│      ↓                                                           │
│  Single JSON dict broadcast to all clients                       │
│  ↓ (every 5th iteration)                                         │
│  database.insert_metrics()                                       │
│  └── SQLite WAL mode INSERT INTO metrics                         │
│      (timestamp, cpu_percent, ram_percent, ram_used_gb,          │
│       disk_percent, disk_read_mb_s, disk_write_mb_s,             │
│       net_sent_mb_s, net_recv_mb_s)                              │
│  ↓ (every 1000 inserts)                                          │
│  cleanup_old_data(7 days)                                        │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Data Flow (Flutter Side)

```
WebSocketService (ChangeNotifier)
├── connect() → WebSocketChannel('ws://localhost:8765')
├── Stream listen → parse JSON → SystemMetrics.fromJson()
│   ├── _latest = metrics
│   ├── _history.add(metrics) [max 60 entries → rolling window]
│   └── metricsNotifier.value = metrics
│
├── Protocol version assertion (v3 required)
│
├── Request/Response system (Completer-based):
│   ├── killProcess(pid) → sends {"type":"kill_process"}
│   ├── fetchConnections(pid) → sends {"type":"get_process_connections"}
│   ├── fetchHistory(minutes) → sends {"type":"get_history"}
│   ├── setPriority(pid, priority) → sends {"type":"set_priority"}
│   └── fetchPriority(pid) → sends {"type":"get_priority"}
│
├── Auto-reconnect every 3s on disconnect
├── After 3 failed attempts → check agent_status.json for error
└── retryConnection() → resets error, reconnects

AlertsService (ChangeNotifier)
├── Listens to WebSocketService.metricsNotifier
├── Evaluates 4 rules on each metric tick:
│   ├── CPU > 85% for 30 consecutive seconds → CRITICAL (one-shot)
│   ├── RAM > 90% → WARNING (60s cooldown)
│   ├── Disk > 95% → CRITICAL (60s cooldown)
│   └── Network recv > 10 MB/s → INFO (60s cooldown)
├── Max 50 alerts, newest-first
├── Bell icon with red unread count badge
├── Toast notification for CRITICAL alerts
└── All configurable from Settings screen (thresholds + cooldowns)

HistoryService (ChangeNotifier)
├── FFI SQLite database (zabmin_history.db in app support dir)
├── Records MetricSnapshot every 5 seconds
├── 5-year retention (auto-prune)
├── fetchRange(from, to) → List<MetricSnapshot>
├── summarize(from, to) → MetricSummary (min/avg/max per field)
└── Used by ExportDialog for CSV/JSON report generation

SettingsService (ChangeNotifier)
├── SharedPreferences backend
├── Configurable: CPU threshold, RAM threshold, Disk threshold
│   Net threshold, CPU consecutive seconds
├── Minimize to tray, toast notifications, launch at startup
└── launch_at_startup uses package, toggled via SharedPreferences
```

---

## 4. WebSocket Protocol (v3)

### 4.1 Server → Client (broadcast every 1s)

```json
{
  "version": 3,
  "timestamp": 1718000000,
  "cpu": {
    "percent_total": 23.4,
    "percent_per_core": [12.5, 34.1, 18.9, 28.0],
    "freq_mhz": 3200,
    "core_count": 4,
    "thread_count": 8,
    "temperature_c": 52.3,
    "throttled": false
  },
  "memory": {
    "total_gb": 16.0,
    "used_gb": 8.4,
    "percent": 52.3,
    "available_gb": 7.6,
    "cached_gb": 3.2,
    "speed_mhz": 3200
  },
  "disk": {
    "total_gb": 512.0,
    "used_gb": 210.0,
    "percent": 41.0,
    "read_mb_s": 0.4,
    "write_mb_s": 1.2,
    "partitions": [
      {
        "device": "C:\\",
        "mountpoint": "C:\\",
        "label": "OS",
        "filesystem": "NTFS",
        "total_gb": 512.0,
        "used_gb": 210.0,
        "free_gb": 302.0,
        "percent": 41.0,
        "physical_drive": "PhysicalDrive0",
        "read_mb_s": 0.2,
        "write_mb_s": 0.8
      }
    ]
  },
  "network": {
    "sent_mb_s": 0.1,
    "recv_mb_s": 2.3,
    "total_sent_gb": 10.2,
    "total_recv_gb": 44.1
  },
  "processes": [
    {
      "pid": 1234,
      "ppid": 5678,
      "name": "chrome.exe",
      "cpu_percent": 5.2,
      "memory_mb": 312.4,
      "status": "running",
      "connections": 12
    }
  ],
  "gpu": [
    {
      "name": "NVIDIA GeForce RTX 4090",
      "vram_total_mb": 24576.0,
      "vram_used_mb": 12288.0,
      "vram_percent": 50.0,
      "temperature_c": 65.0,
      "fan_percent": 40.0,
      "utilization_percent": 45.0,
      "driver_version": "535.98"
    }
  ],
  "battery": {
    "percent": 85.5,
    "power_plugged": true,
    "secs_left": null
  }
}
```

### 4.2 Client → Server Messages

| Type | Purpose | Parameters |
|---|---|---|
| `kill_process` | Terminate a process | `pid`, `request_id` |
| `get_process_connections` | Get network connections for a PID | `pid`, `request_id` |
| `set_priority` | Change process priority class | `pid`, `priority`, `request_id` |
| `get_priority` | Get current process priority | `pid`, `request_id` |
| `get_history` | Fetch SQLite history for charts | `duration_minutes`, `request_id` |
| `shutdown` | Gracefully shut down the agent | (none) |

### 4.3 Server Response Types

| Type | Purpose | Content |
|---|---|---|
| `kill_result` | Result of kill attempt | `pid`, `request_id`, `success`, `error?` |
| `process_connections` | Network connections list | `pid`, `request_id`, `connections[]`, `error?` |
| `priority_result` | Result of priority change | `pid`, `request_id`, `success`, `priority`, `error?` |
| `priority_info` | Current priority value | `pid`, `request_id`, `priority`, `error?` |
| `history` | Historical metric rows | `request_id`, `data[]` (SQLite rows) |

---

## 5. Key Design Decisions

### 5.1 CPU Monitoring in a Thread
`psutil.cpu_percent(interval=1)` is a blocking call. Inside the asyncio event loop on Windows, using `interval=None` produces unreliable readings. A dedicated `threading.Thread` with `interval=1` produces accurate readings matching Task Manager.

### 5.2 Windows PDH Counters (Primary) with psutil Fallback
- **Primary**: Windows Performance Data Helper (PDH) via `ctypes.windll.pdh` — `\Processor Information(_Total)\% Processor Utility` counter
- **Fallback**: psutil's `cpu_percent()` if PDH initialization fails
- This matches Task Manager's CPU values exactly when PDH works

### 5.3 Memory = total - available
psutil's `used` field includes cache/buffers that Windows Task Manager excludes. Zabmin calculates `used = total - available` to match Task Manager's "In Use" metric.

### 5.4 Process CPU Divided by Core Count
psutil returns per-total-CPU percentage. Task Manager shows per-process as a fraction of total CPU. Zabmin divides by `cpu_count(logical=True)` to match.

### 5.5 I/O Speed Uses Real Elapsed Time
Network and disk I/O speed is calculated as `(current - previous) / elapsed_seconds` using `time.monotonic()`, not assuming exactly 1-second intervals. This handles timing drift correctly.

### 5.6 Warmup Calls
CPU and process collectors call `cpu_percent()` once at import time to initialize psutil's internal state, avoiding the first-call-zero problem.

### 5.7 SQLite Every 5 Seconds
Database stores one row per 5-second interval — balances granularity with database size. WAL mode for better concurrent read performance.

### 5.8 GPU Multi-Source Merge
GPU data is merged from up to 3 sources:
1. **NVML** (NVIDIA-only) — utilization, temperature, fan, VRAM, driver version
2. **WMI** `Win32_VideoController` — covers Intel/AMD GPUs, but `AdapterRAM` is 32-bit DWORD (truncates >4GB VRAM)
3. **DXGI** via hand-rolled COM vtable walking — correct dedicated VRAM for AMD/Intel GPUs (>4GB fix)

If no source has utilization data, returns 0.0 to prevent blocking (WMI GPUEngine perf counters take 15+ seconds on Windows).

### 5.9 Agent Auto-Start & Shutdown
The Flutter app launches the Python agent as a hidden subprocess via VBScript on startup. On window close, it attempts graceful shutdown via WebSocket shutdown message, falls back to reading PID file + `taskkill`, then WMIC process search.

### 5.10 Protocol Version Assertion
The Flutter app asserts that the agent's protocol version matches `kZabminProtocolVersion` (currently 3). Mismatch throws an assertion error to prevent silent data corruption.

---

## 6. UI Architecture

### 6.1 Navigation
- **Full sidebar** (≥1100px width): 210px wide, brand header, 7 nav items (Dashboard, Processes, Network, Disk, RAM, GPU, Settings), connection badge at bottom
- **Compact rail** (<1100px width): 64px icon-only rail with tooltips
- Navigation state managed by `_selectedNav` in `DashboardScreen`

### 6.2 State Management (Provider)
```
ZabminApp
├── ChangeNotifierProvider<WebSocketService>
│   ├── latest: SystemMetrics?
│   ├── history: List<SystemMetrics> (rolling 60 entries)
│   ├── metricsNotifier: ValueNotifier<SystemMetrics?>
│   └── connectionStatus: 'connecting' | 'connected' | 'disconnected'
│
├── ChangeNotifierProvider<AlertsService>
│   ├── alerts: List<Alert>
│   ├── unreadCount: int
│   └── panelVisibleNotifier: ValueNotifier<bool>
│
├── ChangeNotifierProvider<HistoryService>
│   └── Local SQLite database for historical metrics
│
└── ChangeNotifierProvider<SettingsService>
    └── SharedPreferences-backed settings
```

### 6.3 Screen Structure

| Screen | Route | Key Widgets |
|---|---|---|
| Dashboard | Default | MetricGrid(4 cards), MetricChart(CPU+RAM dual), CoreBarGrid, ProcessTable(top 9) |
| Processes | `'Processes'` | 3 summary stats, SearchField, tree/flat toggle, _ProcessRow list, kill confirmation, _ConnectionPanel (priority + network connections) |
| Network | `'Network'` | _ThroughputCard(download/upload), DetailStatCard(totals), MetricChart(net dual), _SpeedBar |
| Disk | `'Disk'` | 3 summary stats, SearchField, grouped by physical drive, _DiskGroupCard, _PartitionRow, MetricChart |
| RAM | `'RAM'` | CircularProgressArc, InlineStat(used/free/total), DetailStatCard(available/cached/speed), MetricChart |
| GPU | `'GPU'` | SearchField, _GpuCard(util arc, VRAM, temp, fan, bars), MetricChart(utilization+VRAM dual) |
| Settings | `'Settings'` | _ThresholdSection(5 sliders), _BehaviorSection(3 toggles) |

### 6.4 Custom UI Components

- **GlassCard**: Container with surface background, border, optional gradient, hover lift animation (translateY -2px, glow shadow)
- **CircularProgressArc**: Custom `CustomPainter` with `SweepGradient`, background arc, progress arc with glowing leading edge
- **AnimatedMetric**: `TweenAnimationBuilder<double>` with easeOutCubic curve for smooth number transitions
- **TimeRangeSelector**: Pill buttons for chart time range (1m / 15m / 1h)
- **ChartChrome**: Chart container with title, subtitle, range selector, loading state
- **ScreenShell**: Each screen's wrapper with accent bar, icon badge, title, subtitle, scrollable content
- **AppRail**: Compact icon rail for narrow windows

### 6.5 Color Palette (Theme: "Minimalist Executive Pro")

| Role | Hex | Usage |
|---|---|---|
| Background | `#0F131C` | Main app background |
| Background Deep | `#0B0E15` | Deeper surfaces, stats |
| Surface | `#161B26` | Cards, sidebar |
| Surface Elevated | `#1E2536` | Hovered/glass surfaces |
| Border | `#262F40` | Card borders |
| Border Strong | `#334057` | Stronger borders |
| Accent | `#3B82F6` | Primary accent (blue) |
| Green | `#10B981` | OK status |
| Orange | `#F59E0B` | Warning |
| Red | `#EF4444` | Critical/errors |
| Purple | `#8B5CF6` | RAM chart |
| Text Primary | `#F8FAFC` | Headings |
| Text Secondary | `#94A3B8` | Body text |
| Text Tertiary | `#64748B` | Captions/labels |

**Gradient pairs:**
- CPU: cyan → blue (`#22D3EE` → `#3B82F6`)
- RAM: purple → pink (`#A855F7` → `#EC4899`)
- Disk: orange → red (`#F59E0B` → `#EF4444`)
- Network: teal → cyan (`#14B8A6` → `#22D3EE`)
- GPU: green → teal (`#10B981` → `#14B8A6`)
- Accent: cyan → indigo (`#22D3EE` → `#6366F1`)

**Typography:** Inter (headings/body) + JetBrains Mono (mono/metrics) via Google Fonts.

---

## 7. Process Lifecycle

### 7.1 Startup
1. `main()` in Flutter → `WidgetsFlutterBinding.ensureInitialized()`
2. Initialize FFI SQLite (`sqfliteFfiInit`)
3. Initialize `HistoryService` + `SettingsService`
4. Setup `launchAtStartup`
5. Setup `window_manager` (1280×800, hidden titlebar)
6. Setup `tray_manager` (icon + context menu)
7. Setup `local_notifier`
8. Call `_startAgent()`:
   - Traverse directory tree from `Platform.script` up to find `../agent/` directory
   - Launch `wscript run_agent.vbs` as detached process
9. `runApp()` → `ZabminApp` with `MultiProvider`
10. `WebSocketService.connect()` → tries to connect to `ws://localhost:8765`

### 7.2 Steady State
- Agent broadcasts metrics every 1 second
- Flutter receives, parses, updates UI via Provider
- AlertsService evaluates rules on each tick
- HistoryService writes to SQLite every 5 seconds
- Tray tooltip updates with current CPU/RAM
- Agent rotates logs at 5MB, cleans up old SQLite data after 7 days

### 7.3 Shutdown
1. User closes window → `onWindowClose()` in `AppShell`
2. If `minimizeToTray` is enabled → hide window (return)
3. `_killAgent()`:
   a. Try graceful shutdown: send WebSocket `shutdown` message, wait for PID file deletion
   b. Read `agent/agent.pid` → `taskkill /F /PID`
   c. Fallback: `wmic process where name='python.exe' and CommandLine like '%agent.py%'` → `taskkill /F`
4. `trayManager.destroy()`
5. `windowManager.destroy()`

---

## 8. Agent Lifecycle (Python Side)

### 8.1 Startup
1. Write PID to `agent.pid`
2. Start `perf_monitor_loop` thread:
   - Initialize PDH counters (CPU utility) + psutil warmup
   - Falls back to psutil-only if PDH fails
   - Loop: sleep 1s, collect PDH data, sleep 50ms, read counter, collect RAM via psutil
   - Update thread-safe shared state
3. Start WebSocket server on `localhost:8765`
4. If port is already in use (error 10048): write error status to `agent_status.json`, exit
5. Write success status to `agent_status.json`
6. Start `broadcast_loop`:
   - Loop: `gather_metrics()` (all 7 collectors in parallel threads), broadcast JSON
   - Every 5th iteration: `database.insert_metrics()`
   - Wait with timeout for shutdown event

### 8.2 Shutdown
- WebSocket `shutdown` message → sets `_shutdown_event`
- Broadcast loop exits → server closes
- `agent.pid` and `agent_status.json` cleaned up

---

## 9. Collectors Deep-Dive

### 9.1 CPU (`collectors/cpu.py`)
- **Source**: `cpu_state.read_state()` (PDH thread), `psutil.cpu_freq()`, `psutil.cpu_count()`
- **Temperature**: WMI `MSAcpi_ThermalZoneTemperature` (cached 60s)
- **Throttling**: `current_freq / max_freq < 0.5`
- **Frequency**: Cached 30s (call is slow on some systems, logged if >500ms)
- **Fields**: `percent_total`, `percent_per_core[]`, `freq_mhz`, `core_count`, `thread_count`, `temperature_c`, `throttled`

### 9.2 Memory (`collectors/memory.py`)
- **Source**: `psutil.virtual_memory()`
- **Key formula**: `used = total - available` (matches Task Manager)
- **RAM Speed**: WMI `Win32_PhysicalMemory.ConfiguredClockSpeed` (queried once, cached)
- **Fields**: `total_gb`, `used_gb`, `percent`, `available_gb`, `cached_gb`, `speed_mhz`

### 9.3 Disk (`collectors/disk.py`)
- **Source**: `psutil.disk_partitions()`, `psutil.disk_usage()`, `psutil.disk_io_counters(perdisk=True)`
- **Filters non-real partitions**: skips CD-ROM, UDF, CDFS, DRIVE_UNKNOWN, DRIVE_NO_ROOT_DIR, DRIVE_CDROM
- **Volume labels**: `kernel32.GetVolumeInformationW()`
- **Physical drive mapping**: `kernel32.CreateFileW()` + `DeviceIoControl(IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS)` — maps mountpoints to `PhysicalDriveN`
- **I/O speed**: delta-based with real elapsed time (`time.monotonic()`)
- **Aggregation**: totals across all partitions, per-physical-disk I/O grouping
- **Fields (top-level)**: `total_gb`, `used_gb`, `percent`, `read_mb_s`, `write_mb_s`, `partitions[]`
- **Per-partition**: `device`, `mountpoint`, `label`, `filesystem`, `total_gb`, `used_gb`, `free_gb`, `percent`, `physical_drive`, `read_mb_s`, `write_mb_s`

### 9.4 Network (`collectors/network.py`)
- **Source**: `psutil.net_io_counters()`
- **Speed calculation**: `(current - previous) / dt` using `time.monotonic()`
- **Fields**: `sent_mb_s`, `recv_mb_s`, `total_sent_gb`, `total_recv_gb`

### 9.5 Processes (`collectors/processes.py`)
- **Source**: `psutil.process_iter()` with fields `pid`, `ppid`, `name`, `cpu_percent`, `memory_info`, `status`
- **Filters**: excludes zero-CPU processes, excludes "System Idle Process"
- **CPU normalization**: `raw_cpu / logical_core_count` (matches Task Manager)
- **Warmup**: calls `p.cpu_percent()` at import for all processes
- **Sort**: descending by CPU
- **Limit**: top 30
- **Fields per process**: `pid`, `ppid`, `name`, `cpu_percent`, `memory_mb`, `status`, `connections`

### 9.6 GPU (`collectors/gpu.py`)
- **Multi-source merge (priority order)**:
  1. **NVML** (NVIDIA): full data (utilization, VRAM, temp, fan, driver) via `pynvml`
  2. **WMI** `Win32_VideoController`: GPU name, VRAM (32-bit truncation), driver version
  3. **DXGI**: corrects VRAM for Intel/AMD GPUs where WMI truncates >4GB
- **De-duplication**: loose name matching between sources
- **Intel utilization**: returns 0.0 (WMI GPUEngine perf counters are too slow on Windows — 15+ seconds)
- **Temperature fallback**: uses CPU package temp if GPU temp is 0
- **Caching**: WMI static data (30s TTL), DXGI data (30s TTL)
- **Fields**: `name`, `vram_total_mb`, `vram_used_mb`, `vram_percent`, `temperature_c`, `fan_percent`, `utilization_percent`, `driver_version`

### 9.7 Battery (`collectors/battery.py`)
- **Source**: `psutil.sensors_battery()`
- **Returns `None`** if no battery detected (not included in broadcast)
- **Fields**: `percent`, `power_plugged`, `secs_left` (null if on AC or <= 0)

---

## 10. Alert Rules

| Rule | Condition | Severity | Cooldown | Configurable |
|---|---|---|---|---|
| CPU sustained high | >85% for 30 consecutive seconds | Critical | One-shot per sustained period | Threshold + consecutive seconds |
| RAM high | >90% | Warning | 60 seconds | Threshold |
| Disk full | >95% | Critical | 60 seconds | Threshold |
| Network spike | Download >10 MB/s | Info | 60 seconds | Threshold |

### 10.1 Cooldown Mechanism
- **CPU**: Resets counter when drops below threshold; only fires once per sustained period
- **RAM/Disk/Net**: 60-second cooldown timer per alert type
- Max 50 alerts stored (newest first)

### 10.2 Toast Notifications
Critical alerts trigger Windows toast notifications via `local_notifier`, can be disabled in settings.

---

## 11. SQLite Databases

### 11.1 Agent Database (`agent/zabmin_history.db`)
| Column | Type | Description |
|---|---|---|
| id | INTEGER PK | Auto-increment |
| timestamp | INTEGER | Unix seconds |
| cpu_percent | REAL | CPU total % |
| ram_percent | REAL | RAM % |
| ram_used_gb | REAL | RAM used in GB |
| disk_percent | REAL | Disk % |
| disk_read_mb_s | REAL | Disk read MB/s |
| disk_write_mb_s | REAL | Disk write MB/s |
| net_sent_mb_s | REAL | Network sent MB/s |
| net_recv_mb_s | REAL | Network recv MB/s |

- Mode: WAL
- Insert: every 5 seconds by agent
- Cleanup: rows older than 7 days (every 1000 inserts)
- Access: `get_history(duration_minutes)` via WebSocket

### 11.2 App Database (`<app_support_dir>/zabmin_history.db`)
| Column | Type | Description |
|---|---|---|
| id | INTEGER PK | Auto-increment |
| ts | INTEGER | Unix seconds |
| cpu_pct | REAL | CPU total % |
| ram_used_gb | REAL | RAM used GB |
| ram_total_gb | REAL | RAM total GB |
| ram_pct | REAL | RAM % |
| disk_used_gb | REAL | Disk used GB |
| disk_total_gb | REAL | Disk total GB |
| disk_pct | REAL | Disk % |
| net_recv_mbs | REAL | Network recv MB/s |
| net_sent_mbs | REAL | Network sent MB/s |
| gpu_pct | REAL | GPU utilization % |
| gpu_vram_pct | REAL | GPU VRAM % |
| gpu_temp_c | REAL | GPU temperature °C |

- Engine: FFI SQLite (sqflite_common_ffi)
- Insert: every 5 seconds via HistoryService
- Retention: 5 years (with hourly prune)
- Additional: `fetchRange()` + `summarize()` (min/avg/max per field)
- Primary consumer: Export dialog (CSV/JSON reports)

---

## 12. Export System

### 12.1 Format Options
- **CSV**: Time series rows as comma-separated values
- **JSON**: Nested structure with `generated_at`, `from_ts`, `to_ts`, `sample_count`, `summary` (min/avg/max per field), `rows[]`

### 12.2 Time Range Options
| Group | Options |
|---|---|
| Recent | 1h, 6h, 24h (default) |
| Days | 7d, 30d, 60d, 90d |
| Months & Years | 6mo, 1y, 5y |

### 12.3 Export Flow
1. Open dialog from titlebar button
2. Select time range + format (CSV/JSON)
3. `HistoryService.fetchRange(from, to)` → `List<MetricSnapshot>`
4. `HistoryService.summarize(from, to)` → `MetricSummary`
5. `ReportExporter.export(rows, summary, format)` → `Uint8List`
6. `FilePicker.platform.saveFile()` → save to user's chosen location
7. Saved with filename `zabmin-report-<ISO8601 timestamp>.csv|json`

---

## 13. CI/CD Pipeline

### 13.1 GitHub Actions (`.github/workflows/ci.yml`)
Triggered on push/PR to `main`.

**Python Job** (windows-latest):
1. Checkout
2. Setup Python 3.13
3. `pip install -r requirements.txt`
4. `ruff check .` + `ruff format --check .`
5. `pytest tests/ -v --tb=short`

**Flutter Job** (windows-latest):
1. Checkout
2. Setup Flutter 3.41
3. `flutter pub get`
4. `flutter analyze`
5. `flutter test`

---

## 14. Configuration Files

### 14.1 `.gitignore`
Ignores: `__pycache__/`, `*.pyc`, `venv/`, `*.db`, `*.db-shm`, `*.db-wal`, `agent/logs/`, `.dart_tool/`, `build/`, `.idea/`, `.flutter-plugins`, `.pub-cache/`, `.env`, etc.

### 14.2 `.qoder/settings.json`
PostToolUse hook: automatically runs `py .qoder/hooks/format.py` after any Write/Edit tool use.

### 14.3 `.qoder/hooks/format.py`
- `.dart` files → `dart format <file>`
- `.py` files → `ruff format <file>`

### 14.4 `AGENTS.md`
AI agent guidance file documenting project layout, run commands, architecture gotchas, code style, and platform info.

---

## 15. Windows-Specific Details

### 15.1 PDH Performance Counters (`cpu_state.py`)
- Uses `ctypes.windll.pdh` for Windows Performance Data Helper
- Counter: `\Processor Information(_Total)\% Processor Utility`
- Double precision format (0x00000200)
- Also called: `PdhOpenQueryW`, `PdhAddEnglishCounterW`, `PdhCollectQueryData`, `PdhGetFormattedCounterValue`

### 15.2 Win32 API Calls

| API | Used In | Purpose |
|---|---|---|
| `kernel32.GetVolumeInformationW` | `disk.py` | Get volume label |
| `kernel32.GetDriveTypeW` | `disk.py` | Filter out CD-ROM/removable |
| `kernel32.CreateFileW` | `disk.py` | Open volume for IOCTL |
| `kernel32.DeviceIoControl` | `disk.py` | `IOCTL_VOLUME_GET_VOLUME_DISK_EXTENTS` → physical drive mapping |
| `kernel32.CloseHandle` | `disk.py` | Cleanup handle |
| `kernel32.GetDiskFreeSpaceExW` | (via psutil) | Disk free space |
| `dxgi.CreateDXGIFactory` | `gpu.py` | DXGI adapter enumeration for VRAM |
| COM `CoInitializeEx` / `CoUninitialize` | `agent.py`, `cpu.py`, `gpu.py` | Required for WMI in threads |

### 15.3 WMI Queries

| Query | Used In | Purpose |
|---|---|---|
| `MSAcpi_ThermalZoneTemperature` | `cpu.py` | CPU temperature |
| `Win32_PhysicalMemory` | `memory.py` | RAM speed (ConfiguredClockSpeed) |
| `Win32_VideoController` | `gpu.py` | GPU name, VRAM, driver version |

### 15.4 Process Management
- Process kill via `psutil.Process(pid).kill()`
- Priority management via `psutil.Process(pid).nice(priority)`
- Network connections via `psutil.Process(pid).net_connections()`
- Process enumeration via `psutil.process_iter()`

### 15.5 Agent Launch
- **VBScript** (`run_agent.vbs`): runs Python agent without console window
- Uses `WScript.Shell.Run` with window style 0 (hidden)
- Falls back to `py` launcher if venv not found
- Flutter app launches via `Process.start('wscript', ['run_agent.vbs'], detached)`

### 15.6 Agent Discovery
Flutter app traverses up from `Platform.script` directory to find the `../agent/` directory, with fallback to relative path.

---

## 16. File-by-File Breakdown

### 16.1 Python Agent (14 source files + tests)

| File | Lines | Purpose |
|---|---|---|
| `agent/agent.py` | 400 | WebSocket server, broadcast loop, 7 collectors orchestration, COM init, handler for 6 message types |
| `agent/cpu_state.py` | 125 | PDH counters + psutil CPU/RAM thread, thread-safe state with Lock |
| `agent/database.py` | 119 | SQLite WAL-mode metrics table, insert every 5s, cleanup after 7 days, get_history query |
| `agent/requirements.txt` | 6 | Dependency list |
| `agent/run_agent.vbs` | 13 | Hidden VBScript launcher |
| `agent/collectors/__init__.py` | 15 | Re-exports |
| `agent/collectors/cpu.py` | 112 | CPU from shared state + freq + temp + throttling |
| `agent/collectors/memory.py` | 50 | RAM total-available formula + speed |
| `agent/collectors/disk.py` | 206 | Multi-partition, physical drive mapping, I/O delta |
| `agent/collectors/network.py` | 50 | Network I/O delta |
| `agent/collectors/processes.py` | 54 | Top-30 sorted, CPU/core-count division |
| `agent/collectors/gpu.py` | 292 | NVML + WMI + DXGI merge |
| `agent/collectors/battery.py` | 15 | Battery sensor polling |
| `agent/tests/conftest.py` | 4 | sys.path setup |
| `agent/tests/test_collectors_cpu.py` | 106 | CPU collector tests |
| `agent/tests/test_collectors_memory.py` | 76 | Memory collector tests |
| `agent/tests/test_collectors_disk.py` | 206 | Disk collector tests |
| `agent/tests/test_collectors_network.py` | 103 | Network collector tests |
| `agent/tests/test_collectors_processes.py` | 106 | Processes collector tests |
| `agent/tests/test_collectors_gpu.py` | 176 | GPU collector tests |
| `agent/tests/test_collectors_battery.py` | 48 | Battery collector tests |

### 16.2 Flutter App (30 source files)

| File | Lines | Purpose |
|---|---|---|
| `app/lib/main.dart` | 604 | App entry, agent lifecycle, custom titlebar, window/tray management |
| `app/lib/core/models/system_metrics.dart` | 306 | 9 model classes with JSON deserialization |
| `app/lib/core/nav_items.dart` | 20 | 7 nav items with icons + gradients |
| `app/lib/core/services/websocket_service.dart` | 358 | WebSocket client with auto-reconnect, request/response system |
| `app/lib/core/services/alerts_service.dart` | 152 | 4 alert rules, cooldowns, toasts, max 50 alerts |
| `app/lib/core/services/history_service.dart` | 312 | FFI SQLite, 5s writes, 5y retention, fetchRange + summarize |
| `app/lib/core/services/settings_service.dart` | 77 | 8 settings via SharedPreferences |
| `app/lib/core/services/report_exporter.dart` | 87 | CSV + JSON export with summary |
| `app/lib/core/theme/zcolors.dart` | 121 | 34 colors, 6 gradients, 3 shadow types, 4 radii, 3 helper functions |
| `app/lib/core/theme/app_theme.dart` | 128 | 7 ZText styles, ZTheme dark, ZPaints helpers |
| `app/lib/screens/dashboard_screen.dart` | 729 | Main dashboard with sidebar, metric cards, charts, process table |
| `app/lib/screens/processes_screen.dart` | 1327 | Full process list with tree/flat, kill, priority, connections panel |
| `app/lib/screens/network_screen.dart` | 277 | Network throughput display |
| `app/lib/screens/disk_screen.dart` | 568 | Disk storage with partition details |
| `app/lib/screens/ram_screen.dart` | 143 | RAM detailed view |
| `app/lib/screens/gpu_screen.dart` | 414 | GPU monitoring cards |
| `app/lib/screens/settings_screen.dart` | 308 | Settings with sliders + toggles |
| `app/lib/widgets/app_rail.dart` | 137 | Compact nav rail |
| `app/lib/widgets/glass_card.dart` | 93 | Card with hover animation |
| `app/lib/widgets/screen_shell.dart` | 232 | Page shell + DetailStatCard + InlineStat |
| `app/lib/widgets/metric_grid.dart` | 73 | Responsive grid |
| `app/lib/widgets/metric_card.dart` | 182 | Metric card with arc |
| `app/lib/widgets/metric_chart.dart` | 243 | Chart with time ranges |
| `app/lib/widgets/chart_chrome.dart` | 177 | Chart container + grid/title helpers |
| `app/lib/widgets/circular_progress_arc.dart` | 101 | Custom arc painter |
| `app/lib/widgets/core_bar_grid.dart` | 126 | Per-core CPU bars |
| `app/lib/widgets/process_table.dart` | 530 | Top processes table |
| `app/lib/widgets/animated_metric.dart` | 69 | Animated number display |
| `app/lib/widgets/search_field.dart` | 94 | Search input |
| `app/lib/widgets/time_range_selector.dart` | 73 | Range toggle pills |
| `app/lib/widgets/export_dialog.dart` | 303 | Export dialog |

### 16.3 C++ Runner

| File | Purpose |
|---|---|
| `windows/runner/main.cpp` | WinMain, COM init, FlutterWindow creation |
| `windows/runner/flutter_window.cpp` | Flutter window handler |
| `windows/runner/win32_window.cpp` | Win32 window base |
| `windows/runner/utils.cpp` | Command-line argument helper |
| `windows/runner/CMakeLists.txt` | CMake build config |

---

## 17. Total Line Count

| Component | Files | Lines (approx) |
|---|---|---|
| Python agent source | 14 | ~1,958 |
| Python agent tests | 8 | ~825 |
| Flutter Dart source | 30 | ~8,100 |
| C++ runner | 5 | ~200 |
| Other (scripts, config, docs) | ~15 | ~1,200 |
| **Total** | **~72** | **~12,300** |

---

## 18. License

MIT License — Copyright (c) 2025 Zabmin Contributors.
