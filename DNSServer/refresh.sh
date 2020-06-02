#!/bin/bash

kill "$(cat /var/run/dns.pid)"
python /usr/src/app/main.py