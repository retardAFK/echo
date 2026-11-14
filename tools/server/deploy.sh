#!/usr/bin/env bash
# Sends a server build to the Écho server and restarts the lobby (S-010).
# Used by the CI on main (T-108): deploy.sh build/server/echo_server.x86_64
# build/web (the build for the server's processor: x86_64, or arm64 on an ARM
# machine, then the optional web export, served at https://<domain>/).
# Needs ECHO_HOST (the domain) and an SSH agent or key for the "echo" user.
set -euo pipefail

build="${1:?path of the server build}"
web="${2:-}"
: "${ECHO_HOST:?set ECHO_HOST, the server domain}"
target="echo@${ECHO_HOST}"

# Sent through ssh itself: no need for the sftp service that scp uses.
ssh "$target" 'cat > /opt/echo/echo_server.new' < "$build"
ssh "$target" 'chmod +x /opt/echo/echo_server.new \
	&& mv /opt/echo/echo_server.new /opt/echo/echo_server \
	&& sudo /usr/bin/systemctl restart echo-lobby'

if [ -n "$web" ]; then
	# Unpacked next to the live copy, then swapped in one move.
	tar -C "$web" -czf - . | ssh "$target" 'set -e
		rm -rf /opt/echo/web.new /opt/echo/web.old
		mkdir /opt/echo/web.new
		tar -xzf - -C /opt/echo/web.new
		chmod -R a+rX /opt/echo/web.new
		if [ -d /opt/echo/web ]; then mv /opt/echo/web /opt/echo/web.old; fi
		mv /opt/echo/web.new /opt/echo/web
		rm -rf /opt/echo/web.old'
fi
echo "Deployed to $ECHO_HOST"
