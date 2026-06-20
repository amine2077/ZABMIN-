"""SQLite database for storing metrics history."""

import sqlite3
import os
import time
import threading
import logging
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

DB_PATH = os.path.join(os.path.dirname(__file__), "zabmin_history.db")

_conn = None
_insert_counter = 0
_lock = threading.Lock()


def _get_conn():
    """Get or create the module-level database connection."""
    global _conn
    if _conn is not None:
        return _conn
    _conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    _conn.execute("PRAGMA journal_mode=WAL")
    return _conn


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


def cleanup_old_data(days=7):
    """Delete rows older than the specified number of days."""
    try:
        cutoff = int(time.time()) - (days * 86400)
        conn = _get_conn()
        cursor = conn.execute("DELETE FROM metrics WHERE timestamp < ?", (cutoff,))
        conn.commit()
        deleted = cursor.rowcount
        if deleted > 0:
            logger.info(f"Cleaned up {deleted} metrics rows older than {days} days")
    except Exception as e:
        logger.warning(f"Failed to cleanup old data: {e}")


def insert_metrics(metrics):
    """Insert a metrics row into the database."""
    global _insert_counter
    try:
        with _lock:
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

            _insert_counter += 1
            if _insert_counter >= 1000:
                _insert_counter = 0
                cleanup_old_data()
    except Exception as e:
        logger.warning(f"Failed to insert metrics: {e}")


def get_history(duration_minutes=60):
    """Return all rows from the last N minutes as a list of dicts."""
    try:
        with _lock:
            cutoff = int(datetime.now(timezone.utc).timestamp()) - (
                duration_minutes * 60
            )
            conn = _get_conn()
            conn.row_factory = sqlite3.Row
            cursor = conn.execute(
                "SELECT * FROM metrics WHERE timestamp >= ? ORDER BY timestamp ASC",
                (cutoff,),
            )
            rows = [dict(row) for row in cursor.fetchall()]
            conn.row_factory = None
            return rows
    except Exception as e:
        logger.warning(f"Failed to get history: {e}")
        return []


# Initialize on import
init_db()
