# Zabmin

A local system monitoring dashboard for Windows, built with **Flutter** and **Python**. Think of it as a lightweight, open-source alternative to Task Manager — with a clean dark UI and real-time charts.

![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-blue)
![Python](https://img.shields.io/badge/Python-3.13-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.41-blue)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Real-time CPU monitoring** — uses Windows Performance Counters (same as Task Manager)
- **Memory tracking** — committed bytes in use, matching Task Manager's "In Use" metric
- **Disk monitoring** — storage usage, read/write speeds
- **Network monitoring** — upload/download speeds, total data transferred
- **Process list** — top 30 processes sorted by CPU usage
- **4 live charts** — CPU, RAM, Network, Disk (last 60 seconds)
- **Smart alerts** — CPU high, RAM high, disk full, network spike
- **Multi-screen navigation** — Dashboard, Processes, Network, Disk views
- **Fully offline** — no cloud, no telemetry, no internet calls

## Architecture

```
Zabmin (two-process Windows desktop app)

  Flutter App (zabmin.exe)
  ├── WebSocketService — connects to agent via ws://localhost:8765
  ├── AlertsService — monitors thresholds and fires alerts
  └── Dashboard — charts, cards, process table, sidebar navigation
          │
          │ WebSocket (localhost:8765)
          ▼
  Python Agent (subprocess, auto-started by app)
  ├── Windows Performance Counters — CPU & RAM (matches Task Manager)
  ├── psutil collectors — Disk, Network, Processes
  └── Broadcasts JSON metrics every 1 second
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full technical design.

## Screenshots

| Dashboard | Processes |
|-----------|-----------|
| Main dashboard with CPU, RAM, Disk, Network cards and live charts | Detailed process list with CPU/RAM/status |

| Network | Disk |
|---------|------|
| Upload/download speeds, total transferred, speed bars | Storage usage, read/write speeds, progress bar |

## Quick Start

### Prerequisites

- **Windows 10/11** (x64)
- **Python 3.13+** — [Download](https://www.python.org/downloads/)
- **Flutter 3.41+** — [Install](https://docs.flutter.dev/get-started/install/windows)

### Setup

1. **Clone the repo**
   ```bash
   git clone https://github.com/YOUR_USERNAME/zabmin.git
   cd zabmin
   ```

2. **Set up the Python agent**
   ```bash
   cd agent
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Run the Flutter app**
   ```bash
   cd ../app
   flutter pub get
   flutter run -d windows
   ```

The app automatically starts the Python agent on launch. No need to run them separately.

## Project Structure

```
zabmin/
├── agent/                    # Python WebSocket server
│   ├── agent.py              # Main entry point
│   ├── cpu_state.py          # Windows Performance Counters (CPU & RAM)
│   ├── collectors/           # psutil-based metric collectors
│   │   ├── disk.py
│   │   ├── memory.py
│   │   ├── network.py
│   │   └── processes.py
│   └── requirements.txt
│
├── app/                      # Flutter desktop app
│   ├── lib/
│   │   ├── main.dart         # App entry point, agent auto-start
│   │   ├── core/
│   │   │   ├── models/       # SystemMetrics data classes
│   │   │   └── services/     # WebSocket & Alerts services
│   │   ├── screens/          # Dashboard, Processes, Network, Disk
│   │   └── widgets/          # Charts, cards, tables
│   └── pubspec.yaml
│
├── ARCHITECTURE.md           # Full technical design doc
├── LICENSE
└── README.md
```

## Alert Rules

| Rule | Condition | Severity | Cooldown |
|------|-----------|----------|----------|
| CPU High | > 85% for 30 consecutive seconds | Critical | One-shot |
| RAM High | > 90% | Warning | 60 seconds |
| Disk Full | > 95% | Critical | 60 seconds |
| Network Spike | Download > 10 MB/s | Info | 60 seconds |

## Tech Stack

| Component | Technology |
|-----------|------------|
| Agent | Python 3.13, websockets, psutil, ctypes (Windows PDH) |
| App | Flutter 3.41, Dart 3.11 |
| Charts | fl_chart |
| State | Provider |
| Window | window_manager |
| Fonts | Google Fonts (Inter) |

## Contributing

Contributions are welcome! Here are some ideas:

- **GPU monitoring** — add NVIDIA/AMD GPU stats
- **Temperature sensors** — CPU/GPU temps
- **Battery monitoring** — for laptops
- **Dark/light themes** — toggle between modes
- **Historical data** — SQLite storage with time-range queries
- **Export/reporting** — save metrics to CSV/PDF
- **Multi-disk support** — monitor all drives, not just C:
- **System info panel** — OS version, hardware specs
- **Keyboard shortcuts** — quick navigation
- **Settings page** — customizable alert thresholds

### How to contribute

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [psutil](https://github.com/giampaolo/psutil) — cross-platform system monitoring
- [fl_chart](https://pub.dev/packages/fl_chart) — beautiful Flutter charts
- [websockets](https://websockets.readthedocs.io/) — Python WebSocket library
