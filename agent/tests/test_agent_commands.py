import os
from unittest.mock import patch

import psutil

from agent import (
    _handle_get_priority,
    _handle_get_process_connections,
    _handle_kill_process,
    _handle_set_priority,
    _psutil_error_to_string,
)


def _make_msg(msg_type: str, **kwargs) -> dict:
    return {"type": msg_type, "pid": 1234, "request_id": 7, **kwargs}


class TestPsutilErrorToString:
    def test_no_such_process(self):
        assert _psutil_error_to_string(psutil.NoSuchProcess(1)) == "process_not_found"

    def test_zombie_process(self):
        assert _psutil_error_to_string(psutil.ZombieProcess(1)) == "process_not_found"

    def test_access_denied(self):
        assert _psutil_error_to_string(psutil.AccessDenied(1)) == "access_denied"

    def test_unexpected_error(self):
        assert _psutil_error_to_string(ValueError("bad")) == "internal_error"
        assert _psutil_error_to_string(RuntimeError("fail")) == "internal_error"


class TestKillProcess:
    @patch("agent.process_policy.check_kill_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_success_response_has_all_fields(self, mock_proc, mock_check):
        result = _handle_kill_process(_make_msg("kill_process"))
        assert result["type"] == "kill_result"
        assert result["pid"] == 1234
        assert result["request_id"] == 7
        assert result["success"] is True

    @patch("agent.process_policy.check_kill_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_success_when_psutil_succeeds(self, mock_proc, mock_check):
        result = _handle_kill_process(_make_msg("kill_process"))
        assert result["success"] is True

    @patch(
        "agent.process_policy.check_kill_allowed",
        return_value=(False, "protected_process"),
    )
    def test_protected_pid_returns_protected_process(self, mock_check):
        result = _handle_kill_process(_make_msg("kill_process"))
        assert result["success"] is False
        assert result["error"] == "protected_process"
        assert result["pid"] == 1234
        assert result["request_id"] == 7

    @patch(
        "agent.process_policy.check_kill_allowed", return_value=(False, "agent_process")
    )
    def test_agent_pid_returns_agent_process(self, mock_check):
        result = _handle_kill_process(_make_msg("kill_process"))
        assert result["success"] is False
        assert result["error"] == "agent_process"

    @patch("agent.process_policy.check_kill_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_no_such_process_returns_process_not_found(self, mock_proc, mock_check):
        mock_proc.side_effect = psutil.NoSuchProcess(99999)
        result = _handle_kill_process(_make_msg("kill_process"))
        assert result["success"] is False
        assert result["error"] == "process_not_found"

    @patch("agent.process_policy.check_kill_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_access_denied_returns_access_denied(self, mock_proc, mock_check):
        mock_proc.side_effect = psutil.AccessDenied(99999)
        result = _handle_kill_process(_make_msg("kill_process"))
        assert result["success"] is False
        assert result["error"] == "access_denied"

    @patch("agent.process_policy.check_kill_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_unexpected_error_returns_internal_error(self, mock_proc, mock_check):
        mock_proc.side_effect = RuntimeError("something broke")
        result = _handle_kill_process(_make_msg("kill_process"))
        assert result["success"] is False
        assert result["error"] == "internal_error"

    @patch("agent.process_policy.check_kill_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_success_audit_logged(self, mock_proc, mock_check):
        mock_proc.return_value = psutil.Process(os.getpid())
        with patch("agent._audit.audit_event") as mock_audit:
            _handle_kill_process(_make_msg("kill_process"))
            mock_audit.assert_called_once_with(
                "kill_process", 1234, mock_proc.return_value.name(), 7, "success"
            )


class TestSetPriority:
    @patch("agent.process_policy.check_priority_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_success_response_has_all_fields(self, mock_proc, mock_check):
        mock_instance = mock_proc.return_value
        mock_instance.nice.return_value = 32
        result = _handle_set_priority(_make_msg("set_priority", priority=32))
        assert result["type"] == "priority_result"
        assert result["pid"] == 1234
        assert result["request_id"] == 7
        assert result["success"] is True
        assert result["priority"] == 32

    @patch("agent.process_policy.check_priority_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_no_such_process_returns_process_not_found(self, mock_proc, mock_check):
        mock_proc.side_effect = psutil.NoSuchProcess(99999)
        result = _handle_set_priority(_make_msg("set_priority", priority=32))
        assert result["success"] is False
        assert result["error"] == "process_not_found"

    @patch("agent.process_policy.check_priority_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_access_denied_returns_access_denied(self, mock_proc, mock_check):
        mock_proc.side_effect = psutil.AccessDenied(99999)
        result = _handle_set_priority(_make_msg("set_priority", priority=32))
        assert result["success"] is False
        assert result["error"] == "access_denied"

    @patch("agent.process_policy.check_priority_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_internal_error_on_value_error(self, mock_proc, mock_check):
        mock_instance = mock_proc.return_value
        mock_instance.nice.side_effect = ValueError("bad priority")
        result = _handle_set_priority(_make_msg("set_priority", priority=32))
        assert result["success"] is False
        assert result["error"] == "internal_error"

    @patch(
        "agent.process_policy.check_priority_allowed",
        return_value=(False, "protected_process"),
    )
    def test_protected_returns_protected_process(self, mock_check):
        result = _handle_set_priority(_make_msg("set_priority", priority=32))
        assert result["success"] is False
        assert result["error"] == "protected_process"


class TestGetPriority:
    @patch("agent.process_policy.check_priority_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_success_response_has_all_fields(self, mock_proc, mock_check):
        mock_proc.return_value.nice.return_value = 32
        result = _handle_get_priority(_make_msg("get_priority"))
        assert result["type"] == "priority_info"
        assert result["pid"] == 1234
        assert result["request_id"] == 7
        assert result["priority"] == 32

    @patch("agent.process_policy.check_priority_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_missing_process_returns_process_not_found(self, mock_proc, mock_check):
        mock_proc.side_effect = psutil.NoSuchProcess(99999)
        result = _handle_get_priority(_make_msg("get_priority"))
        assert result["priority"] is None
        assert result["error"] == "process_not_found"

    @patch(
        "agent.process_policy.check_priority_allowed",
        return_value=(False, "agent_process"),
    )
    def test_agent_pid_denied(self, mock_check):
        result = _handle_get_priority(_make_msg("get_priority"))
        assert result["priority"] is None
        assert result["error"] == "agent_process"


class TestGetProcessConnections:
    @patch("agent.process_policy.check_connections_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_success_response_has_all_fields(self, mock_proc, mock_check):
        mock_proc.return_value.net_connections.return_value = []
        result = _handle_get_process_connections(_make_msg("get_process_connections"))
        assert result["type"] == "process_connections"
        assert result["pid"] == 1234
        assert result["request_id"] == 7
        assert isinstance(result["connections"], list)

    @patch("agent.process_policy.check_connections_allowed", return_value=(True, None))
    @patch("agent.psutil.Process")
    def test_no_such_process_returns_process_not_found(self, mock_proc, mock_check):
        mock_proc.side_effect = psutil.NoSuchProcess(99999)
        result = _handle_get_process_connections(_make_msg("get_process_connections"))
        assert result["connections"] == []
        assert result["error"] == "process_not_found"

    @patch(
        "agent.process_policy.check_connections_allowed",
        return_value=(False, "agent_process"),
    )
    def test_agent_pid_returns_error(self, mock_check):
        result = _handle_get_process_connections(_make_msg("get_process_connections"))
        assert result["connections"] == []
        assert result["error"] == "agent_process"
