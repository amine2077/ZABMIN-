---
name: verify
description: Run static analysis and syntax checks on both the Flutter app and Python agent before marking changes as done. Use after editing code to catch issues early.
---

Run these checks in order and report all failures:

1. **Flutter analysis** (Dart static analysis):
   ```bash
   cd zabmin/app && flutter analyze
   ```

2. **Python lint** (ruff check on agent code):
   ```bash
   cd zabmin/agent && py -m ruff check .
   ```

3. If the agent is running on port 8765, optionally run the smoke test:
   ```bash
   python test_agent.py
   ```

Report results clearly: which check passed, which failed, and what errors were found. Do not mark the task as complete until all checks pass.
