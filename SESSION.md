# Session Checkpoint — Day 3 Complete

## Two-Process Architecture

```
Zabmin/
├── agent/ (Python 3.13 WebSocket server)
│   ├── agent.py              — main entrypoint, WebSocket handler, broadcast loop
│   ├── message_validation.py — [NEW Day 3] pure field validation helpers
│   ├── rate_limit.py         — [NEW Day 3] sliding-window rate limiter
│   ├── runtime.py            — atomic JSON I/O for %LOCALAPPDATA%\Zabmin\runtime.json
│   ├── cpu_state.py          — shared memory for CPU monitor thread
│   ├── database.py           — SQLite history (WAL mode, 5s inserts)
│   ├── collectors/           — psutil/WMI collectors (cpu, memory, disk, network, processes, gpu, battery)
│   ├── logs/agent.log        — rotating log (5MB, 3 backups)
│   └── tests/                — pytest suite (117 tests)
├── app/ (Flutter 3.41 Windows desktop)
│   ├── lib/
│   │   ├── main.dart         — deletes stale runtime.json, launches agent subprocess
│   │   ├── core/services/
│   │   │   ├── websocket_service.dart — polls runtime.json, connects with ?token=, handles typed responses
│   │   │   └── alerts_service.dart    — threshold-based alert engine
│   │   ├── screens/          — dashboard, processes, network, disk, ram, gpu, settings
│   │   └── widgets/          — process_table, metric_card, metric_chart, core_bar_grid, etc.
│   └── test/                 — flutter_test suite (40 tests)
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

### New in Day 3
| File | Tests | Description |
|------|-------|-------------|
| `agent/message_validation.py` | 33 | Pure field validators + message rules |
| `agent/rate_limit.py` | 10 | Sliding-window rate limiter (injectable time) |
| `agent/tests/test_message_validation.py` | — | 33 tests for all validation paths |
| `agent/tests/test_rate_limit.py` | — | 10 tests for rate limit behavior |

### Key Existing Files
| File | What it does |
|------|-------------|
| `agent/agent.py` | Main entrypoint (~550 lines). Imports message_validation, rate_limit. WebSocket handler with 3-layer validation pipeline. |
| `agent/runtime.py` | Atomic runtime.json I/O. Fields: pid, port, token, started_at. |
| `agent/cpu_state.py` | Thread-safe CPU state (shared between perf_monitor_loop and async collector). |
| `agent/database.py` | SQLite history (get_history, insert_metrics). |
| `agent/collectors/cpu.py` | Reads from cpu_state (psutil called in thread only). |
| `app/lib/core/services/websocket_service.dart` | Flutter WebSocket client (~423 lines). Maps typed responses to completers, ignores unknown typed messages. |
| `app/lib/widgets/process_table.dart` | Responsive process table (LayoutBuilder, columns hide at <430px or <540px). |

## Test Suite

| Suite | Count | How to run |
|-------|-------|-----------|
| Python (pytest) | 117 | `cd agent && python -m pytest tests -v` |
| Flutter | 40 | `cd app && flutter test` |
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

## What's Next (Day 4+)

Potential Day 4 tasks:
- Protected-process blocking (prevent kill/set_priority on system-critical PIDs)
- Audit logging (log all kill/set_priority operations to a file)
- Collector runner framework (timing/timeout/retry per collector)
- Agent packaging as Windows executable (PyInstaller/Nuitka)

## Important Gotchas

1. **websockets 16 API**: `websocket.request.path` (not `websocket.path`). `websocket.request.headers` is case-insensitive.
2. **Python bool/int**: `True` passes `isinstance(x, int)` — all numeric validators must check `isinstance(x, bool)` too.
3. **COM init for WMI**: GPU and CPU/memory collectors need `pythoncom.CoInitializeEx` in their thread.
4. **`psutil.cpu_percent(interval=1)` blocks**: Must run in `threading.Thread`, never in asyncio.
5. **Runtime file path**: `_runtime_path()` returns `None` if `LOCALAPPDATA` env var is missing — caller must handle.
6. **Format**: Run `ruff format .` from `agent/` before committing — it touches many files.
7. **`_get_safe_error_response`**: Sends raw `msg.get("pid")` which may be a string if validation failed for type reason. Flutter completers handle via timeout if type mismatch.