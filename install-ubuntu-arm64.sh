#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="cleanup-tool-website"
WEB_ROOT="/var/www/${APP_NAME}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOMAIN_NAME="cleanup-tool.myles-mattlock.co.uk"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root: sudo ./install-ubuntu-arm64.sh" >&2
  exit 1
fi

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "This installer is intended for 64-bit ARM (aarch64), found: $(uname -m)" >&2
  exit 1
fi

if [[ ! -f /etc/os-release ]]; then
  echo "Cannot identify the operating system." >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "ubuntu" ]]; then
  echo "This installer supports Ubuntu, found: ${ID:-unknown}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  nginx

if [[ ! -f "${SOURCE_DIR}/index.html" || ! -f "${SOURCE_DIR}/styles.css" || ! -f "${SOURCE_DIR}/script.js" || ! -d "${SOURCE_DIR}/assets" ]]; then
  echo "The Website repository files were not found beside this script." >&2
  echo "Expected index.html, styles.css, script.js, and assets/." >&2
  exit 1
fi

install -d -o root -g www-data -m 0755 "${WEB_ROOT}"
find "${WEB_ROOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp "${SOURCE_DIR}/index.html" "${SOURCE_DIR}/styles.css" "${SOURCE_DIR}/brand-overrides.css" "${SOURCE_DIR}/script.js" "${WEB_ROOT}/"
cp -a "${SOURCE_DIR}/assets" "${WEB_ROOT}/"
find "${WEB_ROOT}" -type d -exec chmod 0755 {} +
find "${WEB_ROOT}" -type f -exec chmod 0644 {} +

cat > /etc/nginx/sites-available/${APP_NAME} <<EOF
server {
  listen 80;
  listen [::]:80;
  server_name ${DOMAIN_NAME};

    root ${WEB_ROOT};
    index index.html;

    location / {
      try_files \$uri \$uri/ /index.html;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/${APP_NAME}
nginx -t

systemctl disable --now "${APP_NAME}.service" 2>/dev/null || true
rm -f "/etc/systemd/system/${APP_NAME}.service"
systemctl daemon-reload
systemctl enable --now nginx
systemctl reload nginx

cat <<EOF

CleanUp Tool website is running.

Public URL: http://$(hostname -I | awk '{print $1}')
Domain URL: http://${DOMAIN_NAME}

Website root: ${WEB_ROOT}

Service status:
  systemctl status nginx

To update after changing the site files, run this script again.
For HTTPS, point ${DOMAIN_NAME} at this server and add a certificate with certbot.
EOF
