#!/bin/bash
# Railway entrypoint shared by every image in this repo (standalone, hub, node).
#
# The stock docker-selenium images assume a docker-compose network and a
# hand-run `docker run -p 4444:4444`. Two of Railway's rules break that
# assumption silently, and one of the defaults is a security problem on a
# public URL. This shim fixes all three before handing over to the upstream
# start script.
set -e

ROLE="${SE_RAILWAY_ROLE:-standalone}"

# The Firefox builds set SE_BROWSER_ARGS_DEV_SHM to an empty string, because
# --disable-dev-shm-usage is a Chromium flag and geckodriver refuses a session
# that carries it. docker-selenium appends any SE_BROWSER_ARGS_* it finds, so
# an empty one has to be removed rather than left blank.
if [ -z "${SE_BROWSER_ARGS_DEV_SHM:-}" ]; then
    unset SE_BROWSER_ARGS_DEV_SHM
fi

# ---------------------------------------------------------------------------
# 1. Port
# ---------------------------------------------------------------------------
# Railway injects PORT into every service, and its HTTP healthcheck dials the
# INJECTED port rather than the port the public domain targets. A service that
# pins its own port therefore serves 200 on the public URL while the deploy
# fails with "1/1 replicas never became healthy". Selenium's router listens on
# 4444 unless --port says otherwise, so hand $PORT over through SE_OPTS, which
# the upstream start scripts append to the java command line.
#
# Only the HTTP-serving roles care: a node is private, has no domain and no
# healthcheck, and must keep its own registration port.
if [ "$ROLE" != "node" ] && [ -n "${PORT:-}" ]; then
    SE_OPTS="--port ${PORT} ${SE_OPTS:-}"
    export SE_OPTS
    echo "railway-entrypoint: router port=${PORT} (Railway-injected)"
fi

# ---------------------------------------------------------------------------
# 2. Private networking is IPv6-only
# ---------------------------------------------------------------------------
# Railway's internal DNS (*.railway.internal) publishes AAAA records and no A
# records, so hub<->node traffic is IPv6-only. The JVM handles that without
# help: those names resolve to exactly one address family, so address-sorting
# preference never comes into it.
#
# Do NOT set -Djava.net.preferIPv6Addresses=true here. It fixes nothing on
# Railway and it breaks Firefox: geckodriver binds 127.0.0.1 only, the node
# then dials ::1 for its own driver, and every session dies with
# "Connection error (POST http://localhost:NNNN/session)" while Chromium --
# whose driver binds both families -- keeps working. Measured on live deploys
# 2026-08-08: with the flag, 0 of 2 Firefox session attempts started.

# ---------------------------------------------------------------------------
# 3. Authentication
# ---------------------------------------------------------------------------
# A Selenium Grid router accepts a session request from anyone who can reach
# it, and a session is arbitrary code execution plus an outbound network path
# from inside the deployer's project. Every Selenium listing on the Railway
# marketplace publishes that on a public URL with no credentials. Grid 4 has
# had built-in basic auth on the router since 4.6; this image refuses to start
# without it rather than shipping an open one.
if [ "$ROLE" != "node" ]; then
    if [ -z "${SE_ROUTER_PASSWORD:-}" ]; then
        echo "railway-entrypoint: FATAL - SE_ROUTER_PASSWORD is empty." >&2
        echo "railway-entrypoint: refusing to start an unauthenticated Selenium Grid on a public URL." >&2
        echo "railway-entrypoint: set SE_ROUTER_PASSWORD in the service variables and redeploy." >&2
        exit 1
    fi
    echo "railway-entrypoint: router basic auth enabled for user '${SE_ROUTER_USERNAME}'"
fi

exec "$@"
