#!/bin/bash
STANZA="prod01"
LOGFILE="/backup/pgbackrest/log/daily_bkp.log"

echo "$(date '+%F %T') - Starting pgBackRest check" >> "$LOGFILE"
pgbackrest --stanza=$STANZA check >> "$LOGFILE" 2>&1
if [ $? -ne 0 ]; then
    echo "$(date '+%F %T') - ERROR: pgBackRest check failed. Backup skipped." >> "$LOGFILE"
    exit 1
fi

echo "$(date '+%F %T') - Check successful. Starting backup." >> "$LOGFILE"
DOW=$(date +%w)
if [ "$DOW" -eq 0 ]; then
    pgbackrest --stanza=$STANZA --type=full backup >> "$LOGFILE" 2>&1
else
    pgbackrest --stanza=$STANZA --type=incr backup >> "$LOGFILE" 2>&1
fi

if [ $? -eq 0 ]; then
    echo "$(date '+%F %T') - Backup completed successfully." >> "$LOGFILE"
else
    echo "$(date '+%F %T') - ERROR: Backup failed." >> "$LOGFILE"
    exit 1
fi
