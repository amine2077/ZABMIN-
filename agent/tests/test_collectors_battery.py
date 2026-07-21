from unittest.mock import patch

import pytest


class FakeBattery:
    def __init__(self, percent, power_plugged, secsleft):
        self.percent = percent
        self.power_plugged = power_plugged
        self.secsleft = secsleft


def test_battery_collect_returns_data():
    with patch("collectors.battery.psutil.sensors_battery") as mock:
        mock.return_value = FakeBattery(75.5, True, 3600)
        from collectors.battery import collect

        result = collect()
        assert result["percent"] == 75.5
        assert result["power_plugged"] is True
        assert result["secs_left"] == 3600


def test_battery_null_when_no_sensor():
    with patch("collectors.battery.psutil.sensors_battery") as mock:
        mock.return_value = None
        from collectors.battery import collect

        result = collect()
        assert result is None


def test_battery_secs_left_null_when_on_ac():
    with patch("collectors.battery.psutil.sensors_battery") as mock:
        mock.return_value = FakeBattery(100.0, True, -1)
        from collectors.battery import collect

        result = collect()
        assert result["secs_left"] is None


def test_fallback_on_exception():
    with patch("collectors.battery.psutil.sensors_battery") as mock:
        mock.side_effect = RuntimeError("battery fail")
        from collectors.battery import collect

        result = collect()
        assert result is None
