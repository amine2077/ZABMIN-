import psutil

_ALLOWED_PRIORITIES = frozenset(
    {
        psutil.IDLE_PRIORITY_CLASS,
        psutil.BELOW_NORMAL_PRIORITY_CLASS,
        psutil.NORMAL_PRIORITY_CLASS,
        psutil.ABOVE_NORMAL_PRIORITY_CLASS,
        psutil.HIGH_PRIORITY_CLASS,
    }
)

REALTIME_PRIORITY = psutil.REALTIME_PRIORITY_CLASS

MAX_REQUEST_ID = 2147483647
MAX_DURATION_MINUTES = 10080


def _is_int_not_bool(value) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def is_valid_request_id(value) -> bool:
    return _is_int_not_bool(value) and 1 <= value <= MAX_REQUEST_ID


def is_valid_pid(value) -> bool:
    return _is_int_not_bool(value) and value > 0


def is_valid_priority(value) -> bool:
    return _is_int_not_bool(value) and value in _ALLOWED_PRIORITIES


def is_valid_duration_minutes(value) -> bool:
    return _is_int_not_bool(value) and 1 <= value <= MAX_DURATION_MINUTES


_MESSAGE_RULES: dict[str, tuple[tuple[str, str], ...]] = {
    "kill_process": (
        ("pid", "pid"),
        ("request_id", "request_id"),
    ),
    "get_process_connections": (
        ("pid", "pid"),
        ("request_id", "request_id"),
    ),
    "set_priority": (
        ("pid", "pid"),
        ("priority", "priority"),
        ("request_id", "request_id"),
    ),
    "get_priority": (
        ("pid", "pid"),
        ("request_id", "request_id"),
    ),
    "get_history": (
        ("duration_minutes", "duration_minutes"),
        ("request_id", "request_id"),
    ),
    "shutdown": (),
}

_VALIDATORS = {
    "pid": is_valid_pid,
    "request_id": is_valid_request_id,
    "priority": is_valid_priority,
    "duration_minutes": is_valid_duration_minutes,
}

_KNOWN_TYPES = frozenset(_MESSAGE_RULES.keys())


def is_known_type(msg_type: str) -> bool:
    return msg_type in _KNOWN_TYPES


def validate_message(msg) -> tuple[bool, str | None]:
    if not isinstance(msg, dict):
        return False, "invalid_message"

    msg_type = msg.get("type")
    if not isinstance(msg_type, str):
        return False, "invalid_message"

    if msg_type not in _MESSAGE_RULES:
        return False, "unknown_type"

    rules = _MESSAGE_RULES[msg_type]
    for field_name, validator_key in rules:
        if field_name not in msg:
            return False, f"missing_{field_name}"
        validator = _VALIDATORS.get(validator_key)
        if validator is not None and not validator(msg[field_name]):
            return False, f"invalid_{field_name}"

    return True, None
