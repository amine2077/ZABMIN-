from .cpu import collect as collect_cpu
from .disk import collect as collect_disk
from .gpu import collect as collect_gpu
from .memory import collect as collect_memory
from .network import collect as collect_network
from .processes import collect as collect_processes

__all__ = [
    "collect_cpu",
    "collect_disk",
    "collect_gpu",
    "collect_memory",
    "collect_network",
    "collect_processes",
]
