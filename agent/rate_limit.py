import time as _time


class RateLimiter:
    def __init__(self, limits: dict[str, int] | None = None, window: float = 60.0):
        self._limits = limits or {}
        self._window = window
        self._history: dict[str, list[float]] = {}
        self._clock = _time.monotonic

    def allow(self, action: str, now: float | None = None) -> bool:
        max_reqs = self._limits.get(action)
        if max_reqs is None:
            return True

        current = now if now is not None else self._clock()
        if action not in self._history:
            self._history[action] = []

        cutoff = current - self._window
        self._history[action] = [t for t in self._history[action] if t > cutoff]

        if len(self._history[action]) >= max_reqs:
            return False

        self._history[action].append(current)
        return True
