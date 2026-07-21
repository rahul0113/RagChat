"""
Database migration helper for schema changes.
Run once after pulling new code to add columns/tables.
"""
import sqlite3
import os
import logging

logger = logging.getLogger(__name__)


def run_migrations(db_path: str = None):
    """Apply pending schema migrations."""
    if db_path is None:
        from config import get_settings
        db_path = get_settings().SQLALCHEMY_DATABASE_URI.replace("sqlite:///", "")

    if not os.path.exists(db_path):
        logger.info(f"Database {db_path} does not exist yet, skipping migrations.")
        return

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Migration 1: Add ingestion status columns to documents table
    _add_column_if_missing(cursor, "documents", "ingestion_status",
                           "TEXT DEFAULT 'completed'")
    _add_column_if_missing(cursor, "documents", "failure_reason",
                           "TEXT")
    _add_column_if_missing(cursor, "documents", "processing_started_at",
                           "DATETIME")
    _add_column_if_missing(cursor, "documents", "processing_completed_at",
                           "DATETIME")

    # Migration 2: Create unanswered_questions table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS unanswered_questions (
            id TEXT PRIMARY KEY,
            tenant_id TEXT NOT NULL,
            question TEXT NOT NULL,
            fallback_reason TEXT NOT NULL,
            source_chunks_found INTEGER DEFAULT 0,
            top_score REAL DEFAULT 0.0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_unanswered_tenant
        ON unanswered_questions (tenant_id)
    """)
    cursor.execute("""
        CREATE INDEX IF NOT EXISTS idx_unanswered_created
        ON unanswered_questions (created_at)
    """)

    conn.commit()
    conn.close()
    logger.info("Migrations completed successfully.")


def _add_column_if_missing(cursor, table: str, column: str, col_type: str):
    """Add a column to a table if it doesn't already exist."""
    cursor.execute(f"PRAGMA table_info({table})")
    existing = [row[1] for row in cursor.fetchall()]
    if column not in existing:
        cursor.execute(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}")
        logger.info(f"Added column {column} to {table}")
    else:
        logger.debug(f"Column {column} already exists in {table}")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run_migrations()
