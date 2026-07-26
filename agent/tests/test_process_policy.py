import os
from unittest.mock import patch

import psutil

from process_policy import (
    PROTECTED_PIDS,
    PROTECTED_PROCESS_NAMES,
    check_connections_allowed,
    check_kill_allowed,
    check_priority_allowed,
    get_process_name_safe,
    is_agent_pid,
    is_protected_pid,
    is_protected_process_name,
)


class TestIsProtectedPid:
    def test_pid_zero_protected(self):
        assert is_protected_pid(0) is True

    def test_pid_four_protected(self):
        assert is_protected_pid(4) is True

    def test_other_pid_not_protected(self):
        assert is_protected_pid(1234) is False
        assert is_protected_pid(99999) is False

    def test_all_protected_pids(self):
        for pid in PROTECTED_PIDS:
            assert is_protected_pid(pid) is True


class TestIsProtectedProcessName:
    def test_system_protected(self):
        assert is_protected_process_name("System") is True

    def test_registry_protected(self):
        assert is_protected_process_name("Registry") is True

    def test_csrss_protected(self):
        assert is_protected_process_name("csrss.exe") is True

    def test_services_protected(self):
        assert is_protected_process_name("services.exe") is True

    def test_lsass_protected(self):
        assert is_protected_process_name("lsass.exe") is True

    def test_wininit_protected(self):
        assert is_protected_process_name("wininit.exe") is True

    def test_smss_protected(self):
        assert is_protected_process_name("smss.exe") is True

    def test_winlogon_protected(self):
        assert is_protected_process_name("winlogon.exe") is True

    def test_case_insensitive(self):
        assert is_protected_process_name("SYSTEM") is True
        assert is_protected_process_name("System") is True
        assert is_protected_process_name("CSRSS.EXE") is True
        assert is_protected_process_name("Services.exe") is True

    def test_with_path(self):
        assert is_protected_process_name(r"C:\Windows\System32\csrss.exe") is True
        assert is_protected_process_name(r"c:\windows\system32\services.exe") is True
        assert (
            is_protected_process_name(
                r"\Device\HarddiskVolume1\Windows\System32\lsass.exe"
            )
            is True
        )

    def test_normal_name_not_protected(self):
        assert is_protected_process_name("chrome.exe") is False
        assert is_protected_process_name("notepad.exe") is False
        assert is_protected_process_name("Code.exe") is False

    def test_none_not_protected(self):
        assert is_protected_process_name(None) is False

    def test_empty_string_not_protected(self):
        assert is_protected_process_name("") is False

    def test_all_protected_names(self):
        for name in PROTECTED_PROCESS_NAMES:
            assert is_protected_process_name(name) is True


class TestIsAgentPid:
    def test_current_pid_is_agent(self):
        assert is_agent_pid(os.getpid()) is True

    def test_other_pid_not_agent(self):
        assert is_agent_pid(99999) is False


class TestGetProcessNameSafe:
    def test_returns_name_for_valid_pid(self):
        assert get_process_name_safe(os.getpid()) is not None

    @patch("psutil.Process")
    def test_returns_none_on_no_such_process(self, mock_process):
        mock_process.side_effect = psutil.NoSuchProcess(99999)
        assert get_process_name_safe(99999) is None

    @patch("psutil.Process")
    def test_returns_none_on_access_denied(self, mock_process):
        mock_process.side_effect = psutil.AccessDenied(99999)
        assert get_process_name_safe(99999) is None

    @patch("psutil.Process")
    def test_returns_none_on_zombie_process(self, mock_process):
        mock_process.side_effect = psutil.ZombieProcess(99999)
        assert get_process_name_safe(99999) is None


class TestCheckKillAllowed:
    def test_pid_zero_denied(self):
        allowed, error = check_kill_allowed(0)
        assert allowed is False
        assert error == "protected_process"

    def test_pid_four_denied(self):
        allowed, error = check_kill_allowed(4)
        assert allowed is False
        assert error == "protected_process"

    def test_agent_pid_denied(self):
        allowed, error = check_kill_allowed(os.getpid())
        assert allowed is False
        assert error == "agent_process"

    @patch("process_policy.get_process_name_safe")
    def test_protected_name_denied(self, mock_get_name):
        mock_get_name.return_value = "csrss.exe"
        allowed, error = check_kill_allowed(1234)
        assert allowed is False
        assert error == "protected_process"

    @patch("process_policy.get_process_name_safe")
    def test_normal_process_allowed(self, mock_get_name):
        mock_get_name.return_value = "notepad.exe"
        allowed, error = check_kill_allowed(1234)
        assert allowed is True
        assert error is None

    @patch("process_policy.get_process_name_safe")
    def test_process_not_found_when_name_none_and_no_such_process(self, mock_get_name):
        mock_get_name.return_value = None
        with patch("psutil.Process") as mock_proc:
            mock_proc.side_effect = psutil.NoSuchProcess(99999)
            allowed, error = check_kill_allowed(99999)
            assert allowed is False
            assert error == "process_not_found"

    @patch("process_policy.get_process_name_safe")
    def test_access_denied_when_name_none_and_access_denied(self, mock_get_name):
        mock_get_name.return_value = None
        with patch("psutil.Process") as mock_proc:
            mock_proc.side_effect = psutil.AccessDenied(99999)
            allowed, error = check_kill_allowed(99999)
            assert allowed is False
            assert error == "access_denied"

    @patch("process_policy.get_process_name_safe")
    def test_fail_closed_when_name_none_and_psutil_succeeds(self, mock_get_name):
        mock_get_name.return_value = None
        with patch("psutil.Process") as mock_proc:
            mock_proc.return_value = object()
            allowed, error = check_kill_allowed(99999)
            assert allowed is False
            assert error == "access_denied"

    @patch("process_policy.get_process_name_safe")
    def test_fail_closed_when_name_none_and_psutil_raises_unexpected(
        self, mock_get_name
    ):
        mock_get_name.return_value = None
        with patch("psutil.Process") as mock_proc:
            mock_proc.side_effect = RuntimeError("unexpected")
            allowed, error = check_kill_allowed(99999)
            assert allowed is False
            assert error == "internal_error"


class TestCheckPriorityAllowed:
    def test_pid_zero_denied(self):
        allowed, error = check_priority_allowed(0)
        assert allowed is False
        assert error == "protected_process"

    def test_agent_pid_denied(self):
        allowed, error = check_priority_allowed(os.getpid())
        assert allowed is False
        assert error == "agent_process"

    @patch("process_policy.get_process_name_safe")
    def test_normal_process_allowed(self, mock_get_name):
        mock_get_name.return_value = "notepad.exe"
        allowed, error = check_priority_allowed(1234)
        assert allowed is True
        assert error is None

    @patch("process_policy.get_process_name_safe")
    def test_protected_name_denied(self, mock_get_name):
        mock_get_name.return_value = "lsass.exe"
        allowed, error = check_priority_allowed(5678)
        assert allowed is False
        assert error == "protected_process"


class TestCheckConnectionsAllowed:
    def test_pid_zero_denied(self):
        allowed, error = check_connections_allowed(0)
        assert allowed is False
        assert error == "protected_process"

    def test_agent_pid_denied(self):
        allowed, error = check_connections_allowed(os.getpid())
        assert allowed is False
        assert error == "agent_process"

    @patch("process_policy.get_process_name_safe")
    def test_protected_name_denied(self, mock_get_name):
        mock_get_name.return_value = "services.exe"
        allowed, error = check_connections_allowed(1111)
        assert allowed is False
        assert error == "protected_process"

    @patch("process_policy.get_process_name_safe")
    def test_normal_process_allowed(self, mock_get_name):
        mock_get_name.return_value = "code.exe"
        allowed, error = check_connections_allowed(2222)
        assert allowed is True
        assert error is None
