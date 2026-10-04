#!/bin/bash
#
# Dumps the databases into /opt/apps/backrest/dumps, before the Backrest backup.
# Copying the files of a running database gives an inconsistent copy : the dumps are what gets restored, the raw
# database volumes are excluded from the backup plan.
#
# Run on the HOST (it needs docker exec), by the backrest-db-dump systemd timer.
# The credentials are read from the environment of each database container, nothing is stored here.

set -uo pipefail

DUMP_DIR=/opt/apps/backrest/dumps
MARIADB_CONTAINERS=(ccteam-db lychee-db defrag-life-db)
POSTGRES_CONTAINERS=(ghostfolio-db)

# The password goes through MYSQL_PWD rather than the command line, the MYSQL_* names are the legacy aliases used by
# some of the stacks
MARIADB_DUMP='MYSQL_PWD="${MARIADB_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD}" exec mariadb-dump -uroot \
    --single-transaction --routines --events \
    --databases "${MARIADB_DATABASE:-$MYSQL_DATABASE}"'

# Local socket inside the container, trusted by the official image : no password needed.
# --clean --if-exists : the dump drops the existing objects before recreating them, it can be restored over a database
POSTGRES_DUMP='exec pg_dump -U "$POSTGRES_USER" --clean --if-exists "$POSTGRES_DB"'

mkdir -p "$DUMP_DIR"
chmod 700 "$DUMP_DIR"

status=0

# dump <container> <command run inside the container, writing the dump on its standard output>
dump() {
    local container=$1 command=$2

    if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
        echo "$container is not running, skipped" >&2
        status=1
        return
    fi

    # Written to a temporary file first : a failed dump never replaces the previous good one
    if docker exec "$container" sh -c "$command" | gzip > "$DUMP_DIR/$container.sql.gz.tmp"; then
        mv "$DUMP_DIR/$container.sql.gz.tmp" "$DUMP_DIR/$container.sql.gz"
        echo "$container dumped ($(du -h "$DUMP_DIR/$container.sql.gz" | cut -f1))"
    else
        rm -f "$DUMP_DIR/$container.sql.gz.tmp"
        echo "$container dump FAILED" >&2
        status=1
    fi
}

for container in "${MARIADB_CONTAINERS[@]}"; do
    dump "$container" "$MARIADB_DUMP"
done

for container in "${POSTGRES_CONTAINERS[@]}"; do
    dump "$container" "$POSTGRES_DUMP"
done

exit $status
