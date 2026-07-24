import json
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import runtime


class TestWriteRuntime:
    def test_creates_json_with_all_fields(self, monkeypatch, tmp_path):
        monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
        start = int(time.time())
        runtime.write_runtime(12345, 9999, "test-token-secret")
        end = int(time.time())

        path = tmp_path / "Zabmin" / "runtime.json"
        assert path.exists()
        data = json.loads(path.read_text(encoding="utf-8"))
        assert data["pid"] == 12345
        assert data["port"] == 9999
        assert data["token"] == "test-token-secret"
        assert isinstance(data["started_at"], int)
        assert start <= data["started_at"] <= end

    def test_no_tmp_file_remains(self, monkeypatch, tmp_path):
        monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
        runtime.write_runtime(1, 2, "abc")
        tmp_files = list(tmp_path.rglob("*.tmp"))
        assert tmp_files == []

    def test_overwrite_does_not_leak_tmp(self, monkeypatch, tmp_path):
        monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
        runtime.write_runtime(1, 2, "first")
        runtime.write_runtime(3, 4, "second")
        tmp_files = list(tmp_path.rglob("*.tmp"))
        assert tmp_files == []
        data = json.loads(
            (tmp_path / "Zabmin" / "runtime.json").read_text(encoding="utf-8")
        )
        assert data["token"] == "second"

    def test_creates_zabmin_directory(self, monkeypatch, tmp_path):
        monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
        assert not (tmp_path / "Zabmin").exists()
        runtime.write_runtime(1, 2, "t")
        assert (tmp_path / "Zabmin").is_dir()


class TestCleanupRuntime:
    def test_removes_file(self, monkeypatch, tmp_path):
        monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
        runtime.write_runtime(1, 2, "token")
        runtime.cleanup_runtime()
        assert not (tmp_path / "Zabmin" / "runtime.json").exists()

    def test_no_error_when_file_missing(self, monkeypatch, tmp_path):
        monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
        runtime.cleanup_runtime()

    def test_no_error_when_dir_missing(self, monkeypatch, tmp_path):
        monkeypatch.setenv("LOCALAPPDATA", str(tmp_path))
        assert not (tmp_path / "Zabmin").exists()
        runtime.cleanup_runtime()


class TestGenerateToken:
    def test_returns_string(self):
        token = runtime.generate_token()
        assert isinstance(token, str)
        assert len(token) > 0

    def test_unique_across_calls(self):
        assert runtime.generate_token() != runtime.generate_token()

    def test_urlsafe_no_padding(self):
        token = runtime.generate_token()
        assert "+" not in token
        assert "/" not in token
