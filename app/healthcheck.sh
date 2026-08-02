#!/usr/bin/env bash
# Container healthcheck: run 'p4 info' against the local server,
# over SSL when P4SSL is enabled.
PORT="${P4PORT:-1666}"

if [ "${P4SSL:-false}" = "true" ]; then
    p4 -p "ssl:localhost:${PORT}" trust -y >/dev/null 2>&1 || true
    exec p4 -p "ssl:localhost:${PORT}" info >/dev/null 2>&1
else
    exec p4 -p "localhost:${PORT}" info >/dev/null 2>&1
fi
