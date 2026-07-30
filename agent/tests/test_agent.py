import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agent import _SAFE_DEFAULTS


class TestSafeDefaults:
    def test_memory_has_speed_mhz(self):
        mem = _SAFE_DEFAULTS["memory"]
        assert "speed_mhz" in mem
        assert mem["speed_mhz"] == 0

    def test_disk_has_partitions(self):
        disk = _SAFE_DEFAULTS["disk"]
        assert "partitions" in disk
        assert disk["partitions"] == []

    def test_cpu_has_percent_per_core(self):
        cpu = _SAFE_DEFAULTS["cpu"]
        assert "percent_per_core" in cpu
        assert cpu["percent_per_core"] == []

    def test_network_has_totals(self):
        net = _SAFE_DEFAULTS["network"]
        assert "total_sent_gb" in net
        assert "total_recv_gb" in net
        assert net["total_sent_gb"] == 0.0
        assert net["total_recv_gb"] == 0.0

    def test_processes_is_list(self):
        assert _SAFE_DEFAULTS["processes"] == []

    def test_gpu_is_list(self):
        assert _SAFE_DEFAULTS["gpu"] == []

    def test_all_categories_present(self):
        expected = {"cpu", "memory", "disk", "network", "processes", "gpu"}
        assert set(_SAFE_DEFAULTS.keys()) == expected

    def test_memory_defaults_have_all_required_fields(self):
        mem = _SAFE_DEFAULTS["memory"]
        for field in (
            "total_gb",
            "used_gb",
            "percent",
            "available_gb",
            "cached_gb",
            "speed_mhz",
        ):
            assert field in mem

    def test_disk_defaults_have_all_required_fields(self):
        disk = _SAFE_DEFAULTS["disk"]
        for field in (
            "total_gb",
            "used_gb",
            "percent",
            "read_mb_s",
            "write_mb_s",
            "partitions",
        ):
            assert field in disk

    def test_cpu_defaults_have_all_required_fields(self):
        cpu = _SAFE_DEFAULTS["cpu"]
        for field in (
            "percent_total",
            "percent_per_core",
            "freq_mhz",
            "core_count",
            "thread_count",
            "temperature_c",
            "throttled",
        ):
            assert field in cpu
