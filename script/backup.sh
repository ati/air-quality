#!/bin/bash

BACKUP_DIR=/var/data/backup/vozduh

/usr/bin/rsync -r /home/ati/Dropbox/vozduh $BACKUP_DIR/potd/
/usr/bin/pg_dump -U vozduh vozduh | /bin/gzip > $BACKUP_DIR/db/$(/bin/date +%Y-%m-%d-db-vozduh.gz)
/usr/bin/find $BACKUP_DIR/db -mtime +7 -exec /bin/rm {} \;
