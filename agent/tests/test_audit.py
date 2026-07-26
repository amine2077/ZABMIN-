import logging
import re

from audit import _audit_logger, audit_event


class _ListHandler(logging.Handler):
    def __init__(self):
        super().__init__()
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord):
        self.records.append(record)


class TestAuditEvent:
    def setup_method(self):
        self._handler = _ListHandler()
        self._handler.setFormatter(logging.Formatter("%(message)s"))
        _audit_logger.addHandler(self._handler)

    def teardown_method(self):
        _audit_logger.removeHandler(self._handler)

    def test_audit_event_writes_expected_fields(self):
        audit_event("kill_process", 1234, "chrome.exe", 7, "success")

        assert len(self._handler.records) >= 1
        msg = self._handler.records[-1].getMessage()
        assert "action=kill_process" in msg
        assert "pid=1234" in msg
        assert "process_name=chrome.exe" in msg
        assert "request_id=7" in msg
        assert "result=success" in msg

    def test_audit_event_with_error(self):
        audit_event("kill_process", 4, "System", 8, "denied", "protected_process")

        assert len(self._handler.records) >= 1
        msg = self._handler.records[-1].getMessage()
        assert "action=kill_process" in msg
        assert "pid=4" in msg
        assert "process_name=System" in msg
        assert "request_id=8" in msg
        assert "result=denied" in msg
        assert "error=protected_process" in msg

    def test_audit_event_does_not_write_token(self):
        audit_event("shutdown", None, None, 9, "success")

        assert len(self._handler.records) >= 1
        msg = self._handler.records[-1].getMessage()
        assert "token" not in msg.lower()

    def test_audit_event_shutdown(self):
        audit_event("shutdown", None, None, 10, "success")

        assert len(self._handler.records) >= 1
        msg = self._handler.records[-1].getMessage()
        assert "action=shutdown" in msg
        assert "result=success" in msg

    def test_audit_event_priority(self):
        audit_event("set_priority", 5678, "notepad.exe", 11, "success")

        assert len(self._handler.records) >= 1
        msg = self._handler.records[-1].getMessage()
        assert "action=set_priority" in msg
        assert "pid=5678" in msg
        assert "process_name=notepad.exe" in msg
        assert "request_id=11" in msg
        assert "result=success" in msg

    def test_audit_event_rate_limited(self):
        audit_event("get_process_connections", 9999, "code.exe", 12, "rate_limited")

        assert len(self._handler.records) >= 1
        msg = self._handler.records[-1].getMessage()
        assert "action=get_process_connections" in msg
        assert "result=rate_limited" in msg

    def test_audit_failure_does_not_raise(self):
        _audit_logger.removeHandler(self._handler)

        broken_handler = logging.Handler()
        broken_handler.setFormatter(logging.Formatter("%(message)s"))

        def broken_emit(record):
            raise RuntimeError("simulated write failure")

        broken_handler.emit = broken_emit
        _audit_logger.addHandler(broken_handler)

        try:
            audit_event("kill_process", 1, "test.exe", 13, "success")
        except Exception:
            assert False, "audit_event should not raise on handler failure"
        finally:
            _audit_logger.removeHandler(broken_handler)
            _audit_logger.addHandler(self._handler)

    def test_audit_includes_timestamp(self):
        audit_event("kill_process", 100, "test.exe", 14, "success")

        assert len(self._handler.records) >= 1
        msg = self._handler.records[-1].getMessage()
        assert re.search(r"timestamp=\d+", msg) is not None
