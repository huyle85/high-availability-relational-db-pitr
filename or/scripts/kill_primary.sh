#!/bin/bash
source "$(dirname "$0")/common.sh"
 
MODE="${1:-crash}"
LEADER=$(get_leader)
echo "Leader hiện tại: $LEADER"
echo "Thời điểm gây sự cố: $(date -Is)"
 
if [ "$MODE" = "crash" ]; then
  docker kill -s KILL "$LEADER"
else
  docker stop "$LEADER"
fi
