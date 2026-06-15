"""SQLite database for storing metrics history."""
import sqlite3
import os
from datetime import datetime, timezone

DB_PATH = os.path.join(os.path.dirname(__file__), "zabmin_history.db")


def _get_conn():
    """Get or create a database connection."""
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    """Create the metrics table if it doesn't exist."""
    conn = _get_conn()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS metrics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp INTEGER NOT NULL,
            cpu_percent REAL,
            ram_percent REAL,
            ram_used_gb REAL,
            disk_percent REAL,
            disk_read_mb_s REAL,
            disk_write_mb_s REAL,
            net_sent_mb_s REAL,
            net_recv_mb_s REAL
        )
    """)
    conn.commit()
    conn.close()


def insert_metrics(metrics):
    """Insert a metrics row into the database."""
    try:
        conn = _get_conn()
        conn.execute(
            """INSERT INTO metrics
               (timestamp, cpu_percent, ram_percent, ram_used_gb,
                disk_percent, disk_read_mb_s, disk_write_mb_s,
                net_sent_mb_s, net_recv_mb_s)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                metrics["timestamp"],
                metrics["cpu"]["percent_total"],
                metrics["memory"]["percent"],
                metrics["memory"]["used_gb"],
                metrics["disk"]["percent"],
                metrics["disk"]["read_mb_s"],
                metrics["disk"]["write_mb_s"],
                metrics["network"]["sent_mb_s"],
                metrics["network"]["recv_mb_s"],
            ),
        )
        conn.commit()
        conn.close()
    except Exception:
        pass


def get_history(duration_minutes=60):
    """Return all rows from the last N minutes as a list of dicts."""
    try:
        cutoff = int(datetime.now(timezone.utc).timestamp()) - (duration_minutes * 60)
        conn = _get_conn()
        conn.row_factory = sqlite3.Row
        cursor = conn.execute(
            "SELECT * FROM metrics WHERE timestamp >= ? ORDER BY timestamp ASC",
            (cutoff,),
        )
        rows = [dict(row) for row in cursor.fetchall()]
        conn.close()
        return rows
    except Exception:
        return []


# Initialize on import
init_db()
