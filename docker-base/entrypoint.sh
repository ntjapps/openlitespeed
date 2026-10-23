#!/bin/bash

# init PID
pid=0

# SIGTERM signal handlers
sigterm_handler() {
    if [ $pid -ne 0 ]; then
        kill -s SIGTERM $pid
        wait $pid
    fi
    exit 143; # 128 + 15 -- SIGTERM
}

# CTRL + C signal handlers
abort_handler() {
    if [ $pid -ne 0 ]; then
        kill -s SIGTERM $pid
        wait $pid
    fi
    exit 130; # 128 + 2 -- SIGINT
}

trap 'sigterm_handler' SIGTERM
trap 'abort_handler' SIGINT INT

# Render env-driven settings into the OLS config (idempotent, safe on container restarts).
#   OLS_MAX_REQ_BODY_SIZE      max request body, e.g. 128M (default: whatever httpd_config.conf has)
#   OLS_PHP_ENTRYPOINT_ONLY=1  front-controller apps (Laravel-style): only /index.php executes PHP
# See README "Path filtering".
CONF_DIR=/usr/local/lsws/conf
if [ -n "${OLS_MAX_REQ_BODY_SIZE:-}" ]; then
    if [[ "$OLS_MAX_REQ_BODY_SIZE" =~ ^[0-9]+[KkMmGg]?$ ]]; then
        sed -i -E "s/^([[:space:]]*maxReqBodySize[[:space:]]+).*/\1${OLS_MAX_REQ_BODY_SIZE}/" "$CONF_DIR/httpd_config.conf"
    else
        echo "entrypoint: ignoring invalid OLS_MAX_REQ_BODY_SIZE='${OLS_MAX_REQ_BODY_SIZE}' (use e.g. 128M)" >&2
    fi
fi
VHCONF="$CONF_DIR/vhosts/docker/vhconf.conf"
if [ -f "$VHCONF" ]; then
    if [ "${OLS_PHP_ENTRYPOINT_ONLY:-0}" = "1" ]; then
        grep -qE '^#.*\(\?#phpentry\)' "$VHCONF" && sed -i -E '/\(\?#phpentry\)/ s/^#+//' "$VHCONF"
    else
        grep -qE '^[^#].*\(\?#phpentry\)' "$VHCONF" && sed -i -E '/\(\?#phpentry\)/ s/^/#/' "$VHCONF"
    fi
fi

# run application if no ARGS / CMD
if [ $# -eq 0 ]; then
    /usr/local/lsws/bin/litespeed
else
    exec "$@"
fi

# container healthcheck
while true; do
    if [ $# -eq 0 ]; then
        if ! /usr/local/lsws/bin/lswsctrl status | grep 'litespeed is running' > /dev/null; then
            /usr/local/lsws/bin/lswsctrl status >&1
            exit 143; # 128 + 15 -- SIGTERM
        fi
    fi

    # prevent container from exiting and get stdout
    tail -f /usr/local/lsws/logs/main.log >&1 &
    wait ${!}
done
