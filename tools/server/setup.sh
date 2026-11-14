#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu 24.04 server for Écho (S-010, T-108).
# Run as root: ECHO_DOMAIN=echo.example.org DEPLOY_KEY="ssh-ed25519 AAAA..." bash setup.sh
# - installs Caddy and opens HTTP and HTTPS (ufw, or the iptables rules that
#   Oracle Cloud images come with; SSH stays open)
# - creates the "echo" user, which the CI uses to deploy, with the right to
#   restart the lobby service and nothing else
# - installs the lobby service; it starts once a server build is deployed
set -euo pipefail

: "${ECHO_DOMAIN:?set ECHO_DOMAIN, the domain that points to this server}"
: "${DEPLOY_KEY:?set DEPLOY_KEY, the public SSH key used by the CI to deploy}"
here="$(cd "$(dirname "$0")" && pwd)"

apt-get update
apt-get install -y caddy

if [ -f /etc/iptables/rules.v4 ] && command -v netfilter-persistent >/dev/null; then
	# Oracle Cloud: its rules reject everything but SSH; ufw would fight them.
	for port in 80 443; do
		iptables -C INPUT -p tcp --dport "$port" -m state --state NEW -j ACCEPT 2>/dev/null \
			|| iptables -I INPUT 5 -p tcp --dport "$port" -m state --state NEW -j ACCEPT
	done
	netfilter-persistent save
else
	apt-get install -y ufw
	ufw allow OpenSSH
	ufw allow 80/tcp
	ufw allow 443/tcp
	ufw --force enable
fi

id echo >/dev/null 2>&1 || useradd --system --create-home --home-dir /opt/echo --shell /bin/bash echo
install -d -o echo -g echo -m 755 /opt/echo
install -d -o echo -g echo -m 700 /opt/echo/.ssh
echo "$DEPLOY_KEY" > /opt/echo/.ssh/authorized_keys
chown echo:echo /opt/echo/.ssh/authorized_keys
chmod 600 /opt/echo/.ssh/authorized_keys

cat > /etc/sudoers.d/echo-deploy <<'SUDO'
echo ALL=(root) NOPASSWD: /usr/bin/systemctl restart echo-lobby, /usr/bin/systemctl status echo-lobby
SUDO
chmod 440 /etc/sudoers.d/echo-deploy

install -m 644 "$here/echo-lobby.service" /etc/systemd/system/echo-lobby.service
systemctl daemon-reload
systemctl enable echo-lobby

install -m 644 "$here/Caddyfile" /etc/caddy/Caddyfile
echo "ECHO_DOMAIN=$ECHO_DOMAIN" > /etc/default/caddy
systemctl restart caddy

echo "Server ready for https://$ECHO_DOMAIN; deploy a server build to start the lobby."
