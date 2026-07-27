import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import lifecycle


class TestIsPidAlive:
    def test_none_returns_false(self):
        assert lifecycle.is_pid_alive(0) is False

    def test_negative_returns_false(self):
        assert lifecycle.is_pid_alive(-1) is False

    def test_non_int_returns_false(self):
        assert lifecycle.is_pid_alive(0.5) is False

    def test_max_pid_returns_false(self):
        assert lifecycle.is_pid_alive(999999999) is False


class TestIsZabminAgentProcess:
    def test_invalid_pid_returns_false(self):
        assert lifecycle.is_zabmin_agent_process(999999999) is False

    def test_negative_pid_returns_false(self):
        assert lifecycle.is_zabmin_agent_process(-1) is False


class TestGetProcessCommandLine:
    def test_invalid_pid_returns_empty(self):
        assert lifecycle.get_process_command_line(999999999) == ""


class TestIsRuntimeValid:
    def test_none_returns_false(self):
        assert lifecycle.is_runtime_valid(None) is False

    def test_empty_dict_returns_false(self):
        assert lifecycle.is_runtime_valid({}) is False

    def test_missing_pid_returns_false(self):
        assert lifecycle.is_runtime_valid({"port": 1234, "token": "abc"}) is False

    def test_missing_port_returns_false(self):
        assert lifecycle.is_runtime_valid({"pid": 12345, "token": "abc"}) is False

    def test_missing_token_returns_false(self):
        assert lifecycle.is_runtime_valid({"pid": 12345, "port": 9999}) is False

    def test_string_pid_returns_false(self):
        assert (
            lifecycle.is_runtime_valid(
                {"pid": "abc", "port": 9999, "token": "long-enough-token"}
            )
            is False
        )

    def test_zero_pid_returns_false(self):
        assert (
            lifecycle.is_runtime_valid(
                {"pid": 0, "port": 9999, "token": "long-enough-token"}
            )
            is False
        )

    def test_invalid_port_returns_false(self):
        assert (
            lifecycle.is_runtime_valid(
                {"pid": 12345, "port": 99999, "token": "long-enough-token"}
            )
            is False
        )

    def test_short_token_returns_false(self):
        assert (
            lifecycle.is_runtime_valid({"pid": 12345, "port": 9999, "token": "short"})
            is False
        )

    def test_dead_pid_returns_false(self):
        assert (
            lifecycle.is_runtime_valid(
                {"pid": 999999999, "port": 9999, "token": "long-enough-token"}
            )
            is False
        )


class TestAcquireMutex:
    def test_does_not_crash(self):
        result = lifecycle.acquire_agent_mutex()
        lifecycle.release_agent_mutex(result[0] if result else None)
