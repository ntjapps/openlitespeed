#!/usr/bin/env bash
# Runs the repo's real OLS config (docker-base/lsws-conf + entrypoint.sh, copied into a temp dir and
# bind-mounted over the image's) against a tiny fixture docroot and checks the HTTP status of
# sensitive paths. Builds nothing: it only needs an already-pulled image.
#
#   tests/test-paths.sh                       # image ghcr.io/ntjapps/openlitespeed:php85-base
#   IMAGE=my/image:tag tests/test-paths.sh
#
# Containers are capped (512 MB, 1 CPU), bound to 127.0.0.1 on random high ports and removed on exit.
set -u
IMAGE="${IMAGE:-ghcr.io/ntjapps/openlitespeed:php85-base}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../docker-base"
WORK="$(mktemp -d)"
NAME="ols-path-test-$$"
PORT=$((20000 + RANDOM % 10000))
SPORT=$((PORT + 10000))
FAILS=0
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT

PUB="$WORK/public"
mkdir -p "$PUB/.well-known" "$PUB/.git" "$PUB/vendor/pkg" "$PUB/wp-admin" "$PUB/storage" "$PUB/build"
echo '<?php echo "index-ok:" . strlen(file_get_contents("php://input"));' > "$PUB/index.php"
echo '<?php echo "legacy-ok";' | tee "$PUB/foo.php" "$PUB/wp-admin/admin.php" "$PUB/storage/x.php" "$PUB/vendor/autoload.php" > /dev/null
echo 'APP_KEY=secret' > "$PUB/.env"
echo 'APP_KEY=secret' > "$PUB/.env.production"
echo '[core]'         > "$PUB/.git/config"
echo '{"ok":true}'    > "$PUB/.well-known/assetlinks.json"
echo '{}'             > "$PUB/.well-known/apple-app-site-association"
echo 'secret'         > "$PUB/.well-known/.hidden"
echo '{}'             > "$PUB/composer.json"
echo 'dump'           > "$PUB/db.sql"
echo 'js'             > "$PUB/build/app.js"
echo 'js'             > "$PUB/vendor/pkg/app.js"
echo 'x'              > "$PUB/robots.txt"
chmod -R a+rX "$WORK"

# Conf is copied once per run and then reused, so a restart sees the already-rendered config like a real container.
start() { # extra docker args (e.g. -e VAR=...)
  docker rm -f "$NAME" >/dev/null 2>&1
  if [ ! -d "$WORK/conf" ]; then cp -r "$SRC/lsws-conf" "$WORK/conf"; chmod -R a+rX "$WORK/conf"; fi
  cp "$SRC/entrypoint.sh" "$WORK/entrypoint.sh"; chmod a+rx "$WORK/entrypoint.sh"
  docker run -d --name "$NAME" --memory=512m --memory-swap=512m --cpus=1 \
    -p "127.0.0.1:$PORT:80" -p "127.0.0.1:$SPORT:8080" \
    -v "$PUB:/var/www/vhosts/localhost/public:ro" \
    -v "$WORK/conf:/usr/local/lsws/conf" \
    -v "$WORK/entrypoint.sh:/entrypoint.sh:ro" \
    "$@" "$IMAGE" >/dev/null || exit 2
  for _ in $(seq 1 40); do
    curl -s -o /dev/null "http://127.0.0.1:$PORT/robots.txt" && return 0
    sleep 0.5
  done
  echo "server did not start:"; docker logs "$NAME" 2>&1 | tail -20; exit 2
}

check() { # port expected_status path [curl args...]
  local port="$1" want="$2" path="$3"; shift 3
  local got
  got="$(curl -s -o /dev/null -w '%{http_code}' --path-as-is "$@" "http://127.0.0.1:$port$path")"
  if [ "$got" = "$want" ]; then printf 'PASS %s  %s\n' "$got" "$path"
  else printf 'FAIL want %s got %s  %s (port %s)\n' "$want" "$got" "$path" "$port"; FAILS=$((FAILS + 1)); fi
}

always_blocked() {
  for p in /.env /.env.production /.git/config /nested/.env //.env /%2eenv /.well-known/.hidden /.well-known/../.env \
           /vendor/autoload.php /VENDOR/AUTOLOAD.PHP /composer.json /db.sql; do
    check "$PORT" 404 "$p"
  done
  check "$PORT" 200 /index.php
  check "$PORT" 200 /.well-known/assetlinks.json
  check "$PORT" 200 /.well-known/apple-app-site-association
  check "$PORT" 200 /build/app.js
  check "$PORT" 200 /vendor/pkg/app.js
  check "$PORT" 200 /robots.txt
}

echo "== $IMAGE: default mode (legacy multi-file PHP apps keep working)"
start
always_blocked
check "$PORT" 200 /foo.php
check "$PORT" 200 /wp-admin/admin.php
check "$PORT" 200 /storage/x.php
body="$(curl -s "http://127.0.0.1:$PORT/index.php")"
[ "$body" = "index-ok:0" ] && echo "PASS index.php executed" || { echo "FAIL index.php body: $body"; FAILS=$((FAILS + 1)); }

echo "== static listener (:8080, never executes PHP)"
for p in /.env /.git/config /index.php /foo.php /composer.json /db.sql /.well-known/.hidden; do check "$SPORT" 404 "$p"; done
check "$SPORT" 200 /robots.txt
check "$SPORT" 200 /.well-known/assetlinks.json

echo "== OLS_PHP_ENTRYPOINT_ONLY=1 (front-controller apps)"
start -e OLS_PHP_ENTRYPOINT_ONLY=1
always_blocked
check "$PORT" 200 /index.php/api/thing
check "$PORT" 404 /foo.php
check "$PORT" 404 /FOO.PHP
check "$PORT" 404 /foo.php/bar
check "$PORT" 404 /wp-admin/admin.php
check "$PORT" 404 /storage/x.php

echo "== restart in the same container FS without the flag (entrypoint re-disables the rule)"
start
check "$PORT" 200 /foo.php
check "$PORT" 404 /.env

echo "== OLS_MAX_REQ_BODY_SIZE=1M"
start -e OLS_MAX_REQ_BODY_SIZE=1M
head -c 100  /dev/zero > "$WORK/small"
head -c 3000000 /dev/zero > "$WORK/big"
check "$PORT" 200 /index.php --data-binary "@$WORK/small"
check "$PORT" 413 /index.php --data-binary "@$WORK/big"

echo "== default request body limit in the shipped config"
grep -E '^\s*maxReqBodySize\s+128M' "$SRC/lsws-conf/httpd_config.conf" > /dev/null \
  && echo "PASS maxReqBodySize 128M" || { echo "FAIL maxReqBodySize default is not 128M"; FAILS=$((FAILS + 1)); }

if [ "$FAILS" -ne 0 ]; then echo "$FAILS check(s) FAILED"; exit 1; fi
echo "all checks passed"
