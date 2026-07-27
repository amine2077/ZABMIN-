# Session Checkpoint — Day 3 Complete

## Two-Process Architecture

```
Zabmin/
├── agent/ (Python 3.13 WebSocket server)
│   ├── agent.py              — main entrypoint, WebSocket handler, broadcast loop
│   ├── lifecycle.py          — [NEW Day 5] Windows mutex, PID alive, process verification
│   ├── collector_runner.py   — [NEW Day 6] parallel collector runner (timeouts, cache, stale fallback, health)
│   ├── message_validation.py — [Day 3] pure field validation helpers
│   ├── rate_limit.py         — [Day 3] sliding-window rate limiter
│   ├── runtime.py            — atomic JSON I/O for %LOCALAPPDATA%\Zabmin\runtime.json
│   ├── cpu_state.py          — shared memory for CPU monitor thread
│   ├── database.py           — SQLite history (WAL mode, 5s inserts)
│   ├── collectors/           — psutil/WMI collectors (cpu, memory, disk, network, processes, gpu, battery)
│   ├── logs/agent.log        — rotating log (5MB, 3 backups)
│   ├── tests/                — pytest suite (220 tests)
├── app/ (Flutter 3.41 Windows desktop)
│   ├── lib/
│   │   ├── main.dart         — deletes stale runtime.json, launches agent subprocess
│   │   ├── core/services/
│   │   │   ├── websocket_service.dart — polls runtime.json, connects with ?token=, handles typed responses, exponential backoff
│   │   ├── agent_process_manager.dart — [NEW Day 5] runtime.json lifecycle, agent start/stop with PID verification
│   │   └── alerts_service.dart    — threshold-based alert engine
│   │   ├── screens/          — dashboard, processes, network, disk, ram, gpu, settings
│   │   └── widgets/          — process_table, metric_card, metric_chart, core_bar_grid, etc.
│   └── test/                 — flutter_test suite (57 tests)
└── ARCHITECTURE.md, README.md, AGENTS.md
```

## Completed Work

### Day 1 (baseline)
- Metrics collectors for CPU, memory, disk, network, processes, GPU, battery
- SQLite history database (5s insert interval)
- WebSocket broadcast every 1 second, protocol version 3
- Flutter dashboard with metric cards, charts, process table, alerts
- CPU monitor thread (blocking psutil.cpu_percent in dedicated thread)

### Day 2 (secure WebSocket)
- `requirements.txt`: `websockets==16.1.1`
- Bind: `127.0.0.1` only, OS-assigned port (`0`)
- `runtime.json` written atomically to `%LOCALAPPDATA%\Zabmin\` (temp file + fsync + rename)
- Runtime fields: `pid`, `port`, `token`, `started_at`
- Session token via `secrets.token_urlsafe(32)`, never logged
- Token validation: `?token=` query param, `secrets.compare_digest`, close code 4401
- Flutter deletes stale `runtime.json` before starting agent
- Flutter connects via `Uri(queryParameters: {'token': token})`
- Token extraction helpers: `get_websocket_request_path`, `extract_token_from_request_path`, `token_is_valid`
- `server.sockets[0]` guarded against empty list
- `runtime.py` hardened: `_runtime_path` returns `None` on missing `LOCALAPPDATA`, `write_runtime` raises `RuntimeError`
- Stale `runtime.json` deleted in `main.dart`
- Flutter rapid-drop detection (`_receivedFirstMessage` flag)

### Day 3 (secure message handling) — JUST COMPLETED
- **Server limits**: `max_size=65536`, `max_queue=32`, `ping_interval=20`, `ping_timeout=20`
- **Host/Origin check**: Host must start with `127.0.0.1:` or `localhost:`, Origin must be absent/local, otherwise 4403
- **JSON parsing**: try/except, 4400 "invalid_message" on failure
- **Structure check**: must be dict, must have string `type` field, otherwise 4400
- **Unknown types**: ignored with debug log, connection stays open
- **Field validation**: `message_validation.py` — pure helpers for pid, request_id, priority, duration_minutes
  - pid: int > 0 (not bool)
  - request_id: int 1..2147483647 (not bool)
  - priority: int in allowed psutil constants (not REALTIME)
  - duration_minutes: int 1..10080 (not bool)
- **Rate limiting**: `rate_limit.py` — sliding-window, injectable time for testing, per-action limits
  - kill_process: 5/60s, set_priority: 10/60s, get_process_connections: 10/60s
  - get_priority: 20/60s, get_history: 20/60s, shutdown: 3/60s
- **Safe error responses**: validation failures return existing response types with `error` field (no crash)
- **Flutter resilience**: unknown typed messages ignored (guard before SystemMetrics parsing)
- When sending error kill_result/priority_result for validation failures, the `pid` and `request_id` reflect the raw msg values (may be wrong types). The Flutter side handles these via completer timeouts or by matching on pid.

## Key Design Decisions

- **CPU in thread**: `psutil.cpu_percent(interval=1)` blocks; in asyncio on Windows it's unreliable
- **Memory = total - available**: psutil's `used` includes cache/buffers; Task Manager excludes them
- **Process CPU / core count**: psutil returns per-total-CPU, Task Manager shows per-core fraction
- **I/O speed with real elapsed time**: `time.monotonic()` delta, not assumed 1s intervals
- **`bool` is subclass of `int` in Python**: all numeric field validators use `isinstance(v, int) and not isinstance(v, bool)` to reject `True`/`False`
- **Message validation in `agent.py` handler**: parse JSON → check dict/type → ignore unknown → validate fields → check rate limit → execute
- **Two close codes beyond RFC**: 4400 (invalid_message), 4401 (unauthorized), 4403 (forbidden)
- **Rate limiter prunes before checking**: entries `<= (now - window)` are removed, then count against limit
- **Flutter `WebSocketService`**: uses `web_socket_channel` package, polls runtime.json at 100ms with 5s timeout, auto-reconnects every 3s (except after 4401 and rapid-empty-drop)

## File Inventory (90+ files total)

### New in Day 5 + Day 6
| File | Tests | Description |
|------|-------|-------------|
| `agent/lifecycle.py` | 17 | Windows mutex, PID alive/process verification, runtime validity |
| `agent/collector_runner.py` | 13 | Parallel collector framework (timeout, cache, stale, health, in-flight dedup) |
| `app/lib/core/services/agent_process_manager.dart` | — | Runtime.json lifecycle, agent start/stop with PID safety checks |

### Key Existing Files
| File | What it does |
|------|-------------|
| `agent/agent.py` | Main entrypoint (~700 lines). Imports lifecycle, collector_runner, message_validation, rate_limit. WebSocket handler with orphan detection and parallel collector broadcast. |
| `agent/runtime.py` | Atomic runtime.json I/O. Fields: pid, port, token, started_at. |
| `agent/cpu_state.py` | Thread-safe CPU state (shared between perf_monitor_loop and async collector). |
| `agent/database.py` | SQLite history (get_history, insert_metrics). |
| `agent/collectors/cpu.py` | Reads from cpu_state (psutil called in thread only). |
| `app/lib/core/services/websocket_service.dart` | Flutter WebSocket client (~480 lines). Maps typed responses to completers, ignores unknown typed messages, exponential backoff reconnection. |
| `app/lib/core/services/agent_process_manager.dart` | Flutter-side agent lifecycle: read/validate/delete runtime.json, start hidden VBS agent, stop with graceful→taskkill fallback. |
| `app/lib/widgets/process_table.dart` | Responsive process table (LayoutBuilder, columns hide at <430px or <540px). |

## Test Suite

| Suite | Count | How to run |
|-------|-------|-----------|
| Python (pytest) | 220 | `cd agent && python -m pytest tests -v` |
| Flutter | 57 | `cd app && flutter test` |
| Ruff | — | `cd agent && ruff check . && ruff format --check .` |
| Flutter analyze | — | `cd app && flutter analyze` |

## Day 3 Smoke Test Results

```
NO TOKEN:         CloseStatus=4401 unauthorized
WRONG TOKEN:      CloseStatus=4401 unauthorized
CORRECT TOKEN:    {"version": 3, ...} metrics received
MALFORMED JSON:   CloseStatus=4400 invalid_message
INVALID PID STR:  kill_result {success:false, error:"invalid_pid"}
UNKNOWN TYPE:     ignored (no response, connection stays open)
VALID HISTORY:    history response with data
KILL#200-204:     kill_result executed (PID 99999 not found)
KILL#205:         kill_result {success:false, error:"rate_limited"}
TOKEN IN LOG:     Not found
```

## Day 4 (Command Safety and Audit) — COMPLETED

### Completed Work

- **process_policy.py**: Protected PID blocking (0, 4), protected process names (System, Registry, smss.exe, csrss.exe, wininit.exe, services.exe, lsass.exe, winlogon.exe), agent self-protection, safe process name reading, fail-closed when name unavailable
- **audit.py**: Rotating audit logger (`agent/logs/audit.log`, 1MB x 3), logs action/pid/process_name/request_id/result/error for all privileged outcomes (success, denied, failed, rate_limited)
- **agent.py refactored**: Command handlers extracted into testable sync helpers (`_handle_kill_process`, `_handle_set_priority`, `_handle_get_priority`, `_handle_get_process_connections`). All responses guaranteed to include pid + request_id. All psutil errors mapped to safe strings (`process_not_found`, `access_denied`, `internal_error`). Rate-limited commands now audited. `_psutil_error_to_string()` maps exceptions to safe error strings.
- **Flutter error messages**: Shared `userFacingAgentError()` in `core/utils/error_messages.dart`, used by both processes_screen.dart and process_table.dart. Covers `internal_error` and all Day 4 error strings.
- **Flutter request_id matching**: Kill and priority completers now match by request_id first (with pid fallback), preventing timeouts when response identifiers vary.
- **Tests**: 189 Python tests (+25 new: 2 fail-closed, 4 error mapping, 23 command response shape tests). 52 Flutter tests (+12 new: error message tests).

### Day 4 Smoke Test Results

```
PID 0 KILL:       kill_result {success:false, error:"protected_process"}
PID 4 KILL:       kill_result {success:false, error:"protected_process"}
AGENT SELF-KILL:  kill_result {success:false, error:"agent_process"}
MISSING PID:      kill_result {success:false, error:"process_not_found"}
ACCESS DENIED:    kill_result {success:false, error:"access_denied"}
UNEXPECTED ERR:   kill_result {success:false, error:"internal_error"}
RATE-LIMITED:     kill_result {success:false, error:"rate_limited"} + audited
SUCCESS KILL:     kill_result {pid, request_id, success:true}
NORMAL PROCESS:   priority_result {success:true, priority} (no timeout)
CONNECTIONS:      process_connections {pid, request_id, connections} (no timeout)
AUDIT LOG:        Contains success, denied, failed, rate_limited events
TOKEN IN LOG:     Not found
```

### Day 5 (Agent Lifecycle Hardening) — COMPLETED

- **lifecycle.py**: `acquire_agent_mutex()` (Windows `Local\ZabminAgent`, proper ctypes restype/argtypes), `release_agent_mutex()`, `is_pid_alive()` (tasklist), `is_zabmin_agent_process()` (tasklist then wmic), `is_runtime_valid()`
- **agent.py**: `_should_shutdown_orphan()` pure helper, 30s grace + 60s idle window, `_start_time` tracking, `_last_client_activity` updated on disconnect
- **agent_process_manager.dart**: `stopAgent()` — graceful via WebSocket shutdown, fallback to `taskkill` only after PID verification, `isPidZabminAgent()` public method
- **main.dart**: Updated `_killAgent()` to use new `stopAgent()`, already reads runtime.json before deleting
- **websocket_service.dart**: Made `backoffDelay` public (`@visibleForTesting`), removed duplicate `_agentError = null`
- **Tests**: 17 new Python tests for lifecycle helpers

### Day 6 (Collector Resilience) — COMPLETED

- **collector_runner.py**: `CollectorRunner` with `ThreadPoolExecutor`, parallel submission of all collectors, sequential result collection with per-collector timeouts bound by `TOTAL_BROADCAST_BUDGET` (1.5s), thread-safe in-flight dedup (`_in_flight` dict under `threading.Lock`), TTL cache for expensive collectors, stale fallback when a collector times out, health tracking every 10 broadcasts
- **collectors/gpu.py**: Removed CPU temperature fallback for GPU temperature
- **collectors/disk.py**: Added 300s TTL caches for volume labels and physical drive mapping to avoid repeated `CreateFileW`/`DeviceIoControl` per tick
- **agent.py**: Raised per-collector timeouts (cpu/memory/network 0.25→0.5, disk 0.6→1.0, processes 0.7→1.5, gpu 0.8→1.5, battery 0.25→0.5) to match real-world PDH initialization and process enumeration times
- **Tests**: 13 new Python tests for collector runner (parallel execution, in-flight dedup, cache TTL, timeout/stale fallback, non-blocking shutdown, health tracking)

### What's Next

- Agent packaging as Windows executable (PyInstaller/Nuitka)
- Protected process configuration or extended blocklist
- Manual smoke test on target hardware

## Day 5 + Day 6 Smoke Test Results

```
COLLECTOR HEALTH (stabilized):
  cpu=ok/62ms memory=ok/62ms disk=ok/62ms network=ok/62ms
  processes=ok/1290ms gpu=ok/1290ms battery=ok/1290ms

FIRST TICK:
  All collectors time out (PDH/WMI init). No stale available.
  ~4 ticks before any collector produces data.

STALE FALLBACK:
  After first successful run, timed-out collectors return stale data.
  cpu, memory, disk, network stabilize within 3-5 ticks.
  processes, gpu take ~8-12 ticks before completing within budget.

ORPHAN SHUTDOWN:
  Agent shuts down ~90s after last client disconnects (30s grace + 60s idle).

WMI IUnknown LEAK:
  "Win32 exception occurred releasing IUnknown" on shutdown — pre-existing,
  does not affect runtime operation.

TOKEN IN LOG:     Not found
```

## Important Gotchas

1. **websockets 16 API**: `websocket.request.path` (not `websocket.path`). `websocket.request.headers` is case-insensitive.
2. **Python bool/int**: `True` passes `isinstance(x, int)` — all numeric validators must check `isinstance(x, bool)` too.
3. **COM init for WMI**: GPU and CPU/memory collectors need `pythoncom.CoInitializeEx` in their thread.
4. **`psutil.cpu_percent(interval=1)` blocks**: Must run in `threading.Thread`, never in asyncio.
5. **Runtime file path**: `_runtime_path()` returns `None` if `LOCALAPPDATA` env var is missing — caller must handle.
6. **Format**: Run `ruff format .` from `agent/` before committing — it touches many files.
7. **`_get_safe_error_response`**: Sends raw `msg.get("pid")` which may be a string if validation failed for type reason. Flutter completers handle via timeout if type mismatch.
8. **collector_runner elapsed time**: `elapsed` is measured from submission to result retrieval, not actual execution time. Slow collectors show inflated elapsed ms because they include time spent waiting for earlier collectors in the sequential result loop.
9. **First tick timeout**: All collectors time out on the very first broadcast because PDH counters and WMI need initialization. The `TOTAL_BROADCAST_BUDGET` (1.5s) handles this via stale fallback — subsequent ticks produce real data.