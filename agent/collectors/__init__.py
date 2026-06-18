from .cpu import collect as collect_cpu
from .memory import collect as collect_memory
from .disk import collect as collect_disk
from .network import collect as collect_network
from .processes import collect as collect_processes
from .gpu import collect as collect_gpu

__all__ = [
    "collect_cpu",
    "collect_memory",
    "collect_disk",
    "collect_network",
    "collect_processes",
    "collect_gpu",
]
