#!/usr/bin/env python3
"""Hook script: format .dart and .py files after edit/write."""
import sys
import json
import subprocess

data = json.load(sys.stdin)
f = data.get("tool_input", {}).get("file_path", "") or data.get("tool_response", {}).get("filePath", "")
if f.endswith(".dart"):
    subprocess.run(["dart", "format", f], check=False)
elif f.endswith(".py"):
    subprocess.run(["py", "-m", "ruff", "format", f], check=False)
