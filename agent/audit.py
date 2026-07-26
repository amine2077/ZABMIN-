import logging
import logging.handlers
import os
import time

AGENT_DIR = os.path.dirname(os.path.abspath(__file__))
_LOGS_DIR = os.path.join(AGENT_DIR, "logs")
os.makedirs(_LOGS_DIR, exist_ok=True)

_audit_logger = logging.getLogger("zabmin.audit")
_audit_logger.setLevel(logging.INFO)
_audit_logger.propagate = False

_handler = logging.handlers.RotatingFileHandler(
    os.path.join(_LOGS_DIR, "audit.log"),
    maxBytes=1 * 1024 * 1024,
    backupCount=3,
)
_handler.setFormatter(logging.Formatter("%(message)s"))
_audit_logger.addHandler(_handler)


def audit_event(
    action: str,
    pid: int | None,
    process_name: str | None,
    request_id: int | None,
    result: str,
    error: str | None = None,
) -> None:
    try:
        parts = [
            f"timestamp={int(time.time())}",
            f"action={action}",
            f"pid={pid}" if pid is not None else "pid=None",
            f"process_name={process_name or 'unknown'}",
            f"request_id={request_id}" if request_id is not None else "request_id=None",
            f"result={result}",
        ]
        if error:
            parts.append(f"error={error}")
        _audit_logger.info(" ".join(parts))
    except Exception:
        logger = logging.getLogger(__name__)
        logger.warning("Audit log write failed", exc_info=True)
