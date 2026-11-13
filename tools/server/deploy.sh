#!/usr/bin/env bash
# Sends a server build to the Écho server and restarts the lobby (S-010).
# Used by the CI on main (T-108): deploy.sh build/server/echo_server.x86_64
# Needs ECHO_HOST (the domain) and an SSH agent or key for the "echo" user.
set -euo pipefail

build="${1:?path of echo_server.x86_64}"
: "${ECHO_HOST:?set ECHO_HOST, the server domain}"
target="echo@${ECHO_HOST}"

scp -q "$build" "$target:/opt/echo/echo_server.x86_64.new"
ssh "$target" 'chmod +x /opt/echo/echo_server.x86_64.new \
	&& mv /opt/echo/echo_server.x86_64.new /opt/echo/echo_server.x86_64 \
	&& sudo /usr/bin/systemctl restart echo-lobby'
echo "Deployed to $ECHO_HOST"
