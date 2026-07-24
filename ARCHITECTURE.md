# Zabmin Architecture

## Overview

Zabmin is a local, offline-first Windows system monitoring dashboard. It consists of two components that run together: a Python WebSocket agent that collects real-time system metrics, and a Flutter Windows desktop app that displays them in a live dashboard.

```
┌─────────────────────────────────────────────────────────┐
│                    Zabmin App (Flutter)                  │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ Sidebar  │  │ Metric Cards │  │ 4 Charts (2x2)    │  │
│  │ Nav      │  │ CPU/RAM/Disk │  │ CPU  RAM          │  │
│  │          │  │ /Net         │  │ Net  Disk          │  │
│  │          │  ├──────────────┤  ├───────────────────┤  │
│  │          │  │ Alert Bell   │  │ Process Table     │  │
│  │          │  │ Badge/Panel  │  │                   │  │
│  └──────────┘  └──────────────┘  └───────────────────┘  │
└────────────────────────┬────────────────────────────────┘
                         │ WebSocket (ws://127.0.0.1:<OS-port>/?token=<session-token>)
                         │ JSON every 1 second
                         ▼
┌─────────────────────────────────────────────────────────┐
│                   Zabmin Agent (Python)                  │
│  ┌──────────────────┐  ┌─────────────────────────────┐  │
│  │ CPU Monitor Thread│  │ Async Broadcast Loop (1s)   │  │
│  │ (blocking psutil) │  │ collect + broadcast JSON    │  │
│  │ interval=1        │  │ DB insert every 5s          │  │
│  └────────┬─────────┘  └──────────────┬──────────────┘  │
│           │                           │                 │
│  ┌────────▼───────────────────────────▼──────────────┐  │
│  │                    Collectors                      │  │
│  │  cpu  │  memory  │  disk  │  network  │ processes  │  │
│  └────────┴──────────┴────────┴───────────┴──────────┘  │
│                           │                             │
│  ┌────────────────────────▼──────────────────────────┐  │
│  │              SQLite Database (5s)                  │  │
│  │         zabmin_history.db                          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## Python Agent

### Process Model

The agent runs two concurrent execution contexts:

1. **CPU Monitor Thread** (`threading.Thread`, daemon) — The only place `psutil.cpu_percent(interval=1)` is called. This is a blocking call that must run in a thread, not in the asyncio event loop. It updates shared state (`cpu_state.py`) every second.

2. **Async Broadcast Loop** (`asyncio` event loop) — Runs the WebSocket server via `websockets.serve`. Every second it gathers metrics from all collectors, broadcasts JSON to connected clients, and inserts into SQLite every 5 seconds.

### Data Flow

```
psutil.cpu_percent(interval=1) [thread]
        │
        ▼
  cpu_state.py (shared, thread-safe)
        │
        ▼
  collectors/cpu.py → reads from cpu_state (no psutil calls)
  collectors/memory.py → psutil.virtual_memory()
  collectors/disk.py → psutil.disk_usage() + disk_io_counters() (delta with real elapsed time)
  collectors/network.py → psutil.net_io_counters() (delta with real elapsed time)
  collectors/processes.py → psutil.process_iter() (warmup at import, divided by logical cores)
        │
        ▼
  agent.py gather_metrics() → JSON dict
        │
        ├──▶ WebSocket broadcast (all clients, every 1s)
        ├──▶ SQLite insert (every 5s)
        └──▶ History query (on client request: {"type":"get_history"})
```

### Key Design Decisions

- **CPU in a thread**: `psutil.cpu_percent(interval=1)` is unreliable with `interval=None` inside asyncio loops on Windows. A dedicated blocking thread with `interval=1` produces accurate readings that match Task Manager.
- **Memory uses `total - available`**: psutil's `used` field includes cache/buffers that Windows Task Manager excludes. We calculate `used = total - available` to match.
- **Process CPU divided by core count**: psutil returns per-total-CPU percentage. Task Manager shows per-process as a fraction of total CPU, so we divide by `cpu_count(logical=True)`.
- **Delta with real elapsed time**: Network and disk I/O speed is calculated as `(current - previous) / elapsed_seconds` using `time.monotonic()`, not assuming exactly 1-second intervals.
- **Warmup calls**: CPU and process collectors call `cpu_percent()` once at import time to initialize psutil's internal state, avoiding the first-call-zero problem.
- **SQLite every 5 seconds**: The database table stores one row per 5-second interval to keep the database small while maintaining sufficient granularity for history charts.

### WebSocket Security

The agent uses a session-token authentication scheme:

1. **Bind**: `websockets.serve(handler, "127.0.0.1", 0)` — loopback only, OS-assigned port
2. **Token**: Generated at startup via `secrets.token_urlsafe(32)`, never logged or re-read from disk
3. **Runtime file**: Written to `%LOCALAPPDATA%\Zabmin\runtime.json` atomically (temp file + fsync + rename)
   ```json
   {"pid": 1234, "port": 56789, "token": "abc...", "started_at": 1718000000}
   ```
4. **Validation**: Every WebSocket connection is checked for `?token=` query param. Missing or wrong token → closed with code 4401 (unauthorized). Comparison uses `secrets.compare_digest` (constant-time).

### WebSocket Message Validation

All incoming WebSocket messages go through a three-layer validation pipeline:

1. **Server-level limits** — `max_size=65536` (64 KB max message), `max_queue=32` (unbounded queue protection), `ping_interval=20`, `ping_timeout=20` (connection health)
2. **Host/Origin check** — Host header must start with `127.0.0.1:` or `localhost:`, Origin header must be local or absent (native Flutter desktop may not send Origin). Invalid → closed with code 4403 (forbidden)
3. **JSON structure validation** — Payload must parse as JSON, must be a dict/object, must contain a string `type` field. Malformed → closed with code 4400 (invalid_message)
4. **Message field validation** — Each known message type requires specific fields with correct types:
   - `kill_process`: int pid (>0), int request_id (1..2³¹-1)
   - `set_priority`: int pid, int priority (one of `IDLE`/`BELOW_NORMAL`/`NORMAL`/`ABOVE_NORMAL`/`HIGH` priority class, REALTIME rejected), int request_id
   - `get_process_connections`: int pid, int request_id
   - `get_priority`: int pid, int request_id
   - `get_history`: int duration_minutes (1..10080), int request_id
   - `shutdown`: no required fields
5. **Rate limiting** — Sliding window per action (60s window):
   - `kill_process`: 5/60s
   - `set_priority`: 10/60s
   - `get_process_connections`: 10/60s
   - `get_priority`: 20/60s
   - `get_history`: 20/60s
   - `shutdown`: 3/60s
   - Rate-limited commands return a safe error response (e.g. `kill_result` with `success: false, error: "rate_limited"`). Rate-limited shutdowns are silently ignored.
6. **Unknown message types** — Ignored with a minimal debug log. The connection is not closed.

### WebSocket Close Codes

| Code | Reason | When |
|------|--------|------|
| 4400 | invalid_message | Malformed JSON, non-object, missing or non-string type field |
| 4401 | unauthorized | Missing or incorrect session token |
| 4403 | forbidden | Invalid Host or Origin header |

### WebSocket Protocol

**Server → Client (broadcast, every 1 second):**
```json
{
  "version": 1,
  "timestamp": 1718000000,
  "cpu": { "percent_total": 23.4, "percent_per_core": [...], "freq_mhz": 3200, "core_count": 4, "thread_count": 8 },
  "memory": { "total_gb": 16.0, "used_gb": 8.4, "percent": 52.3 },
  "disk": { "total_gb": 512.0, "used_gb": 210.0, "percent": 41.0, "read_mb_s": 0.4, "write_mb_s": 1.2 },
  "network": { "sent_mb_s": 0.1, "recv_mb_s": 2.3, "total_sent_gb": 10.2, "total_recv_gb": 44.1 },
  "processes": [{ "pid": 1234, "name": "chrome.exe", "cpu_percent": 5.2, "memory_mb": 312.4, "status": "running", "connections": 12 }]
}
```

**Client → Server:**
```json
{"type": "get_history", "duration_minutes": 60, "request_id": 1}
{"type": "kill_process", "pid": 1234, "request_id": 2}
{"type": "shutdown"}
{"type": "get_process_connections", "pid": 1234, "request_id": 3}
{"type": "set_priority", "pid": 1234, "priority": 128, "request_id": 4}
{"type": "get_priority", "pid": 1234, "request_id": 5}
```

**Server → Client (response):**
```json
{"type": "history", "request_id": 1, "data": [...]}
{"type": "kill_result", "pid": 1234, "request_id": 2, "success": true}
{"type": "process_connections", "pid": 1234, "request_id": 3, "connections": [...]}
{"type": "priority_result", "pid": 1234, "request_id": 4, "success": true, "priority": 128}
{"type": "priority_info", "pid": 1234, "request_id": 5, "priority": 32}
```

Error responses include `success: false` (for kill/priority commands) or an `error` field on all response types:
```json
{"type": "kill_result", "pid": 1234, "request_id": 2, "success": false, "error": "rate_limited"}
{"type": "history", "request_id": 1, "data": [], "error": "invalid_duration"}
{"type": "process_connections", "pid": 1234, "request_id": 3, "connections": [], "error": "invalid_pid"}
```

## Flutter App

### State Management

Uses `provider` with two `ChangeNotifier` services:

```
ZabminApp
├── ChangeNotifierProvider(WebSocketService)
├── ChangeNotifierProvider(AlertsService)
└── MaterialApp
    └── AppShell (WindowListener)
        └── DashboardScreen
            └── Consumer2<WebSocketService, AlertsService>
```

### WebSocketService

- Discovers the agent by polling `%LOCALAPPDATA%\Zabmin\runtime.json` every 100ms (5s timeout)
- Connects to `ws://127.0.0.1:<port>/?token=<token>` using `Uri.queryParameters`
- Parses incoming JSON into `SystemMetrics` objects for untyped broadcasts
- Recognizes typed responses (`history`, `process_connections`, `priority_info`, `priority_result`, `kill_result`) and dispatches them to pending request completers
- Ignores unknown typed messages instead of attempting to parse them as metrics
- Maintains a rolling history of the last 60 entries for charts
- Exposes a `ValueNotifier<SystemMetrics?>` (`metricsNotifier`) for the alerts service to observe
- Auto-reconnects every 3 seconds on disconnect (but NOT after closeCode 4401 / unauthorized)
- Connection status: `connecting` / `connected` / `disconnected`
- Auth errors (4401) and rapid-empty disconnects surface as clear `agentError` messages

### AlertsService

Listens to `WebSocketService.metricsNotifier` and evaluates rules on each new reading:

| Rule | Condition | Severity | Cooldown |
|------|-----------|----------|----------|
| CPU sustained | >85% for 30 consecutive seconds | critical | fires once per sustained period |
| RAM high | >90% | warning | 60 seconds |
| Disk high | >95% | critical | 60 seconds |
| Network high | recv >10 MB/s | info | 60 seconds |

- Max 50 alerts, newest first
- Each alert: `id`, `timestamp`, `severity`, `message`, `isRead`
- Bell icon in dashboard header with red badge showing unread count
- Side panel lists all alerts with severity icons and timestamps

### Process Launch

On app startup, `main.dart` deletes any stale `%LOCALAPPDATA%\Zabmin\runtime.json` (from a previous crashed/killed agent), then launches the Python agent as a subprocess using `Process.start`. The agent script path is resolved relative to the Dart script location. The agent writes a fresh `runtime.json` with the dynamically-assigned port and session token. The Flutter WebSocketService polls for this file and connects once it appears. On window close, the subprocess is killed.

## Color Palette

| Role | Color |
|------|-------|
| Background | `#0D1117` |
| Surface | `#161B22` |
| Border | `#30363D` |
| Accent | `#58A6FF` |
| CPU chart | `#58A6FF` |
| RAM chart | `#BC8CFF` |
| Network recv | `#58A6FF` |
| Network sent | `#3FB950` |
| Disk chart | `#D29922` |
| Green (ok) | `#3FB950` |
| Orange (warn) | `#D29922` |
| Red (critical) | `#F85149` |
| Text primary | `#FFFFFF` |
| Text secondary | `#8B949E` |

Font: **Inter** (Google Fonts)

## Dependencies

**Python:** psutil, websockets, wmi, sqlite3 (stdlib)

**Flutter:** web_socket_channel, fl_chart, provider, window_manager, google_fonts
