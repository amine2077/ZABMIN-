from message_validation import (
    _ALLOWED_PRIORITIES,
    is_known_type,
    is_valid_duration_minutes,
    is_valid_pid,
    is_valid_priority,
    is_valid_request_id,
    validate_message,
)


class TestIsValidRequestId:
    def test_valid(self):
        assert is_valid_request_id(1) is True
        assert is_valid_request_id(2147483647) is True
        assert is_valid_request_id(42) is True

    def test_zero(self):
        assert is_valid_request_id(0) is False

    def test_negative(self):
        assert is_valid_request_id(-1) is False

    def test_too_large(self):
        assert is_valid_request_id(2147483648) is False

    def test_string(self):
        assert is_valid_request_id("1") is False

    def test_boolean(self):
        assert is_valid_request_id(True) is False
        assert is_valid_request_id(False) is False


class TestIsValidPid:
    def test_valid(self):
        assert is_valid_pid(1) is True
        assert is_valid_pid(99999) is True

    def test_zero(self):
        assert is_valid_pid(0) is False

    def test_negative(self):
        assert is_valid_pid(-1) is False

    def test_string(self):
        assert is_valid_pid("123") is False

    def test_boolean(self):
        assert is_valid_pid(True) is False
        assert is_valid_pid(False) is False


class TestIsValidPriority:
    def test_allowed_values(self):
        for p in _ALLOWED_PRIORITIES:
            assert is_valid_priority(p) is True

    def test_realtime_rejected(self):
        import psutil

        assert is_valid_priority(psutil.REALTIME_PRIORITY_CLASS) is False

    def test_invalid_int(self):
        assert is_valid_priority(0) is False
        assert is_valid_priority(-1) is False
        assert is_valid_priority(999) is False

    def test_string(self):
        assert is_valid_priority("NORMAL_PRIORITY_CLASS") is False

    def test_boolean(self):
        assert is_valid_priority(True) is False


class TestIsValidDurationMinutes:
    def test_valid(self):
        assert is_valid_duration_minutes(1) is True
        assert is_valid_duration_minutes(60) is True
        assert is_valid_duration_minutes(10080) is True

    def test_zero(self):
        assert is_valid_duration_minutes(0) is False

    def test_negative(self):
        assert is_valid_duration_minutes(-1) is False

    def test_above_max(self):
        assert is_valid_duration_minutes(10081) is False

    def test_string(self):
        assert is_valid_duration_minutes("60") is False

    def test_boolean(self):
        assert is_valid_duration_minutes(True) is False


class TestIsKnownType:
    def test_known(self):
        assert is_known_type("kill_process") is True
        assert is_known_type("get_history") is True
        assert is_known_type("shutdown") is True
        assert is_known_type("get_priority") is True
        assert is_known_type("set_priority") is True
        assert is_known_type("get_process_connections") is True

    def test_unknown(self):
        assert is_known_type("unknown_type") is False
        assert is_known_type("") is False
        assert is_known_type("metrics") is False


class TestValidateMessage:
    def test_valid_kill_process(self):
        ok, err = validate_message(
            {"type": "kill_process", "pid": 1234, "request_id": 1}
        )
        assert ok is True
        assert err is None

    def test_kill_process_missing_pid(self):
        ok, err = validate_message({"type": "kill_process", "request_id": 1})
        assert ok is False
        assert err == "missing_pid"

    def test_kill_process_missing_request_id(self):
        ok, err = validate_message({"type": "kill_process", "pid": 1234})
        assert ok is False
        assert err == "missing_request_id"

    def test_pid_as_string_fails(self):
        ok, err = validate_message(
            {"type": "kill_process", "pid": "123", "request_id": 1}
        )
        assert ok is False
        assert err == "invalid_pid"

    def test_pid_as_boolean_fails(self):
        ok, err = validate_message(
            {"type": "kill_process", "pid": True, "request_id": 1}
        )
        assert ok is False
        assert err == "invalid_pid"

    def test_pid_zero_fails(self):
        ok, err = validate_message({"type": "kill_process", "pid": 0, "request_id": 1})
        assert ok is False
        assert err == "invalid_pid"

    def test_negative_pid_fails(self):
        ok, err = validate_message({"type": "kill_process", "pid": -1, "request_id": 1})
        assert ok is False
        assert err == "invalid_pid"

    def test_request_id_zero_fails(self):
        ok, err = validate_message(
            {"type": "kill_process", "pid": 1234, "request_id": 0}
        )
        assert ok is False
        assert err == "invalid_request_id"

    def test_request_id_as_string_fails(self):
        ok, err = validate_message(
            {"type": "kill_process", "pid": 1234, "request_id": "1"}
        )
        assert ok is False
        assert err == "invalid_request_id"

    def test_request_id_too_large_fails(self):
        ok, err = validate_message(
            {"type": "kill_process", "pid": 1234, "request_id": 2147483648}
        )
        assert ok is False
        assert err == "invalid_request_id"

    def test_unknown_type_returns_unknown(self):
        ok, err = validate_message({"type": "unknown_type", "pid": 1234})
        assert ok is False
        assert err == "unknown_type"

    def test_get_history_duration_zero_fails(self):
        ok, err = validate_message(
            {"type": "get_history", "duration_minutes": 0, "request_id": 1}
        )
        assert ok is False
        assert err == "invalid_duration_minutes"

    def test_get_history_negative_fails(self):
        ok, err = validate_message(
            {"type": "get_history", "duration_minutes": -5, "request_id": 1}
        )
        assert ok is False
        assert err == "invalid_duration_minutes"

    def test_get_history_above_max_fails(self):
        ok, err = validate_message(
            {
                "type": "get_history",
                "duration_minutes": 10081,
                "request_id": 1,
            }
        )
        assert ok is False
        assert err == "invalid_duration_minutes"

    def test_valid_get_history(self):
        ok, err = validate_message(
            {"type": "get_history", "duration_minutes": 60, "request_id": 1}
        )
        assert ok is True
        assert err is None

    def test_set_priority_realtime_fails(self):
        import psutil

        ok, err = validate_message(
            {
                "type": "set_priority",
                "pid": 1234,
                "priority": psutil.REALTIME_PRIORITY_CLASS,
                "request_id": 1,
            }
        )
        assert ok is False
        assert err == "invalid_priority"

    def test_set_priority_normal_passes(self):
        import psutil

        ok, err = validate_message(
            {
                "type": "set_priority",
                "pid": 1234,
                "priority": psutil.NORMAL_PRIORITY_CLASS,
                "request_id": 1,
            }
        )
        assert ok is True
        assert err is None

    def test_shutdown_no_fields_passes(self):
        ok, err = validate_message({"type": "shutdown"})
        assert ok is True
        assert err is None

    def test_non_dict_msg(self):
        ok, err = validate_message("not a dict")
        assert ok is False
        assert err == "invalid_message"

    def test_missing_type(self):
        ok, err = validate_message({"pid": 1234})
        assert ok is False
        assert err == "invalid_message"

    def test_non_string_type(self):
        ok, err = validate_message({"type": 123})
        assert ok is False
        assert err == "invalid_message"

    def test_boolean_as_int_for_pid(self):
        ok, err = validate_message(
            {"type": "kill_process", "pid": False, "request_id": 1}
        )
        assert ok is False
        assert err == "invalid_pid"

    def test_boolean_as_int_for_duration(self):
        ok, err = validate_message(
            {"type": "get_history", "duration_minutes": True, "request_id": 1}
        )
        assert ok is False
        assert err == "invalid_duration_minutes"
