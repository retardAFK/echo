#!/usr/bin/env bash
# Sends a server build to the Écho server and restarts the lobby (S-010).
# Used by the CI on main (T-108): deploy.sh build/server/echo_server.x86_64
# (the build for the server's processor: x86_64, or arm64 on an ARM machine).
# Needs ECHO_HOST (the domain) and an SSH agent or key for the "echo" user.
set -euo pipefail

build="${1:?path of the server build}"
: "${ECHO_HOST:?set ECHO_HOST, the server domain}"
target="echo@${ECHO_HOST}"

# Sent through ssh itself: no need for the sftp service that scp uses.
ssh "$target" 'cat > /opt/echo/echo_server.new' < "$build"
ssh "$target" 'chmod +x /opt/echo/echo_server.new \
	&& mv /opt/echo/echo_server.new /opt/echo/echo_server \
	&& sudo /usr/bin/systemctl restart echo-lobby'
echo "Deployed to $ECHO_HOST"
