#!/bin/bash

DATE=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_DIR="./backups"

mkdir -p $BACKUP_DIR

echo "Starting backup..."

docker exec -e PGPASSWORD=postgres -t dwh_db pg_dump -U postgres mrr > $BACKUP_DIR/mrr_$DATE.sql
docker exec -e PGPASSWORD=postgres -t dwh_db pg_dump -U postgres stg > $BACKUP_DIR/stg_$DATE.sql
docker exec -e PGPASSWORD=postgres -t dwh_db pg_dump -U postgres dwh > $BACKUP_DIR/dwh_$DATE.sql

echo "Backup completed!"