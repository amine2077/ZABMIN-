# AGENTS.md

This file provides guidance to the AI agent when working with code in this repository.

## Project Layout

- **Git repo root**: `zabmin/` subdirectory (not the workspace root `D:\zabmin`)
- `zabmin/agent/` — Python 3.13 WebSocket server (metrics collection)
- `zabmin/app/` — Flutter 3.41 Windows desktop app (UI)
- Two-process architecture: the Flutter app auto-starts the Python agent as a subprocess on launch

## Run Commands

```bash
# Python agent (from zabmin/agent/)
cd zabmin/agent
python -m venv venv && venv/Scripts/activate
pip install -r requirements.txt
python agent.py

# Flutter app (from zabmin/app/)
cd zabmin/app
flutter pub get
flutter run -d windows

# Quick smoke test (requires agent running on port 8765)
python test_agent.py
```

## Architecture Gotchas

- **CPU monitoring must run in a dedicated `threading.Thread`**, not in the asyncio event loop. `psutil.cpu_percent(interval=1)` blocks; inside asyncio on Windows it produces unreliable readings. See `agent/cpu_state.py`.
- **Windows PDH counters** (`ctypes.windll.pdh`) are used for CPU and RAM to match Task Manager values. Falls back to psutil if PDH init fails.
- **Memory uses `total - available`**, not psutil's `used` field (which includes cache/buffers that Task Manager excludes).
- **Process CPU % is divided by `cpu_count(logical=True)`** — psutil returns per-total-CPU percentage, Task Manager shows per-core fraction.
- **I/O speed uses real elapsed time** (`time.monotonic()` delta), not assumed 1-second intervals.
- **SQLite history**: one row per 5 seconds via `agent/database.py`, WAL mode.

## Code Style

- Dart: uses `flutter_lints/flutter.yaml` (standard Flutter lint set). Run `dart format` for formatting.
- Python: uses `ruff` for linting and formatting (`py -m ruff check`, `py -m ruff format`). Follow PEP 8.

## Platform

Windows-only (10/11, x64). Agent uses Windows Performance Counters via `ctypes.windll.pdh`. WebSocket server binds to `localhost:8765`.

## GStack Decision (2026-07-24)

Not installed. All gstack skills (review, spec, investigate, document-release, diagram) depend on the shared `bin/` directory (~70 binaries), `scripts/`, `docs/`, `ETHOS.md`, and cross-references to other skills — not portable standalone. Full `./setup --host opencode` is the only clean path. Revisit if multi-repo need arises.

Built instead: `.opencode/skills/doc-audit/SKILL.md` — a zero-dep skill that audits README/ARCHITECTURE/AGENTS.md against the current diff, auto-fixes obvious mismatches, asks before judgment calls. Triggers automatically on feature completion or before commit/release. Also invoke via "run doc-audit" / "check if the docs are stale".
