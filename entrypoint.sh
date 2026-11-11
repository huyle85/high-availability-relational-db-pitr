#!/bin/bash
set -e
 
if [ "$BACKUP_MODE" = "on" ]; then
  export ARCHIVE_MODE=on
  export RESTORE_COMMAND='pgbackrest --stanza=demo archive-get %f "%p"'
else
  export ARCHIVE_MODE=off
  export RESTORE_COMMAND=''
fi
 
envsubst '${PATRONI_NAME} ${ARCHIVE_MODE} ${RESTORE_COMMAND}' \
  < /etc/patroni/patroni.yml.tpl > /tmp/patroni.yml
 
exec patroni /tmp/patroni.yml
