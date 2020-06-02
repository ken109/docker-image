#!/bin/bash
set -euo pipefail

if [ -e /var/run/watcher.pid ]; then
    rm /var/run/watcher.pid
fi

watcher.py -c /usr/src/watcher.ini start

exec "$@"
