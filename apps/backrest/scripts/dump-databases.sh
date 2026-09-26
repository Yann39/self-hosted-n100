#!/bin/bash
#
# Dumps the MariaDB databases into /opt/apps/backrest/dumps, before the Backrest backup.
# Copying the files of a running database gives an inconsistent copy : the dumps are what gets restored, the raw
# database volumes are excluded from the backup plan.
#
# Run on the HOST (it needs docker exec), by the backrest-db-dump systemd timer.
# The credentials are read from the environment of each database container, nothing is stored here.

set -uo pipefail

DUMP_DIR=/opt/apps/backrest/dumps
CONTAINERS=(ccteam-db lychee-db defrag-life-db)

mkdir -p "$DUMP_DIR"
chmod 700 "$DUMP_DIR"

status=0
for container in "${CONTAINERS[@]}"; do
    if ! docker ps --format '{{.Names}}' | grep -qx "$container"; then
        echo "$container is not running, skipped" >&2
        status=1
        continue
    fi

    # Written to a temporary file first : a failed dump never replaces the previous good one.
    # The password goes through MYSQL_PWD rather than the command line, the MYSQL_* names are the legacy aliases
    # used by some of the stacks.
    if docker exec "$container" sh -c '
        MYSQL_PWD="${MARIADB_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD}" exec mariadb-dump -uroot \
            --single-transaction --routines --events \
            --databases "${MARIADB_DATABASE:-$MYSQL_DATABASE}"' \
        | gzip > "$DUMP_DIR/$container.sql.gz.tmp"; then
        mv "$DUMP_DIR/$container.sql.gz.tmp" "$DUMP_DIR/$container.sql.gz"
        echo "$container dumped ($(du -h "$DUMP_DIR/$container.sql.gz" | cut -f1))"
    else
        rm -f "$DUMP_DIR/$container.sql.gz.tmp"
        echo "$container dump FAILED" >&2
        status=1
    fi
done

exit $status
