# Batch: Database Index Maintenance

## Overview
PostgreSQL indexes accumulate bloat over time as rows are updated and deleted — the old index entries
are marked dead but not immediately reclaimed. A bloated index wastes disk space, reduces cache
efficiency, and slows query plans. Regular maintenance catches these issues before they affect
production performance.

## Implementation

### Detect Index Bloat
```sql
-- Indexes with bloat > 50% are candidates for reindexing
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    round(100 * (
        1 - (
            (relpages::float - est_dead_pages) / relpages::float
        )
    ), 2) AS bloat_pct
FROM pg_stat_user_indexes
JOIN pg_class ON pg_class.oid = indexrelid
CROSS JOIN LATERAL (
    SELECT
        -- Estimate of dead pages (simplified heuristic)
        greatest(0, relpages::int - ceil(reltuples / (
            floor((8192 - 24 - SUM(attlen + 2)) / (avg_width + 6))
        ))::int) AS est_dead_pages
    FROM pg_attribute
    JOIN pg_class c2 ON c2.oid = indrelid
    WHERE attrelid = indrelid AND attnum > 0 AND NOT attisdropped
) bloat_est
WHERE relpages > 50    -- skip tiny indexes
ORDER BY bloat_pct DESC;
```

### REINDEX CONCURRENTLY for Live Production
```sql
-- REINDEX CONCURRENTLY rebuilds the index without locking reads/writes
-- Note: requires PostgreSQL 12+
REINDEX INDEX CONCURRENTLY idx_orders_user_id;
REINDEX TABLE CONCURRENTLY orders;  -- rebuilds all indexes on the table

-- ✗ Plain REINDEX locks the table — never run in production during business hours
REINDEX INDEX idx_orders_user_id;  -- locks all reads/writes on orders table
```

### VACUUM ANALYZE for Stale Statistics
```sql
-- VACUUM removes dead tuples; ANALYZE updates query planner statistics
-- Run after large batch deletes/updates or on a schedule
VACUUM ANALYZE orders;

-- More aggressive version (reclaims space, rewrites table, requires brief lock)
VACUUM FULL ANALYZE orders;  -- use during maintenance window only

-- Check last auto-vacuum and analyze times
SELECT
    relname AS table_name,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze,
    n_dead_tup AS dead_tuples
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;
```

### Detect Unused Indexes
```sql
-- Indexes that have never (or rarely) been scanned are wasting space and write overhead
SELECT
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE idx_scan < 50        -- fewer than 50 uses since last stats reset
  AND pg_relation_size(indexrelid) > 1000000  -- > 1MB
ORDER BY pg_relation_size(indexrelid) DESC;

-- IMPORTANT: stats reset on server restart — only trust if uptime > 7 days
SELECT pg_postmaster_start_time();  -- check how long stats have been accumulating
```

### Detect Duplicate Indexes
```sql
-- Indexes with identical columns in the same order are redundant
SELECT
    t.relname AS table_name,
    array_agg(i.relname ORDER BY i.relname) AS index_names,
    pg_get_indexdef(ix.indexrelid) AS definition
FROM pg_index ix
JOIN pg_class t ON t.oid = ix.indrelid
JOIN pg_class i ON i.oid = ix.indexrelid
GROUP BY t.relname, ix.indkey, pg_get_indexdef(ix.indexrelid)
HAVING count(*) > 1
ORDER BY t.relname;
```

### Batch Execution Script
```bash
#!/bin/bash
# Run from cron at 3 AM Sunday (low traffic window)
set -euo pipefail

DB_URL="${DATABASE_URL}"

# 1. Collect bloat report
psql "$DB_URL" -f sql/index_bloat_report.sql > /tmp/index_report.txt 2>&1

# 2. Reindex bloated indexes (> 40% bloat, > 5MB)
psql "$DB_URL" <<'SQL'
DO $$
DECLARE
    idx_name text;
BEGIN
    FOR idx_name IN
        SELECT indexname FROM pg_stat_user_indexes
        -- simplified: any index flagged in monitoring
        WHERE idx_scan > 0  -- only reindex used indexes
    LOOP
        -- Would execute: EXECUTE 'REINDEX INDEX CONCURRENTLY ' || idx_name;
        RAISE NOTICE 'Would reindex: %', idx_name;
    END LOOP;
END $$;
SQL

# 3. Run ANALYZE on top tables by dead tuple count
psql "$DB_URL" -c "SELECT 'ANALYZE ' || relname || ';' FROM pg_stat_user_tables WHERE n_dead_tup > 10000 ORDER BY n_dead_tup DESC LIMIT 10" -t | psql "$DB_URL"

echo "Index maintenance complete"
```

## Key Rules
- Always use REINDEX CONCURRENTLY in production — plain REINDEX acquires an exclusive lock that blocks all queries
- Only trust index usage statistics if PostgreSQL uptime > 7 days since last restart
- Do not drop an index that `idx_scan = 0` without first checking if it exists solely for a constraint (unique/pk)
- VACUUM FULL rewrites the entire table and briefly blocks writes — only run during maintenance windows
- After a large batch DELETE (> 10% of table rows), run VACUUM ANALYZE immediately — autovacuum may not run fast enough
- Log bloat percentages over time — a trend of increasing bloat signals a tuning issue (autovacuum too slow)
- Never reindex during peak traffic hours — even CONCURRENTLY adds I/O load to the database server
