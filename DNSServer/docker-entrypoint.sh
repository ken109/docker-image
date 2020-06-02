#!/bin/bash
set -euo pipefail

touch domains.txt
if [ -v LOCAL_DOMAINS ]; then
  if [ -n "$LOCAL_DOMAINS" ]; then
    for domain in $LOCAL_DOMAINS; do
      echo "$domain" >> domains.txt
    done
  fi
fi

exec "$@"
