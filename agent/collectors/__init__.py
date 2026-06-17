from .disk import collect as collect_disk
from .network import collect as collect_network
from .processes import collect as collect_processes
from .gpu import collect as collect_gpu

__all__ = ["collect_disk", "collect_network", "collect_processes", "collect_gpu"]
