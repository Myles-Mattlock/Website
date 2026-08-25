#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="cleanup-tool-website"
APP_USER="cleanup-site"
APP_DIR="/opt/${APP_NAME}"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTNET_VERSION="10.0"
APP_PORT="5000"

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
  nginx \
  libicu-dev \
  zlib1g

if apt-cache show libssl3t64 >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends libssl3t64
else
  apt-get install -y --no-install-recommends libssl3
fi

if ! id --user "${APP_USER}" >/dev/null 2>&1; then
  useradd --system --home-dir "${APP_DIR}" --shell /usr/sbin/nologin "${APP_USER}"
fi

if [[ ! -x /usr/local/bin/dotnet ]]; then
  curl --fail --silent --show-error --location https://dot.net/v1/dotnet-install.sh \
    --output /tmp/dotnet-install.sh
  chmod 0755 /tmp/dotnet-install.sh
  /tmp/dotnet-install.sh \
    --channel "${DOTNET_VERSION}" \
    --architecture arm64 \
    --install-dir /usr/local/share/dotnet
  ln -sfn /usr/local/share/dotnet/dotnet /usr/local/bin/dotnet
  rm -f /tmp/dotnet-install.sh
fi

if [[ ! -f "${SOURCE_DIR}/Website.csproj" ]]; then
  echo "Website.csproj was not found beside this script." >&2
  exit 1
fi

install -d -o "${APP_USER}" -g "${APP_USER}" "${APP_DIR}"
/usr/local/bin/dotnet publish "${SOURCE_DIR}/Website.csproj" \
  --configuration Release \
  --runtime linux-arm64 \
  --self-contained false \
  --output "${APP_DIR}"
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

if [[ ! -x /usr/local/bin/dotnet || ! -f "${APP_DIR}/Website.dll" ]]; then
  echo "The .NET host or published Website.dll is missing." >&2
  exit 1
fi

cat > /etc/systemd/system/${APP_NAME}.service <<EOF
[Unit]
Description=CleanUp Tool website
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${APP_USER}
Group=${APP_USER}
WorkingDirectory=${APP_DIR}
ExecStart=/usr/local/bin/dotnet ${APP_DIR}/Website.dll
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://127.0.0.1:${APP_PORT}
Restart=on-failure
RestartSec=5
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=${APP_DIR}

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/nginx/sites-available/${APP_NAME} <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

rm -f /etc/nginx/sites-enabled/default
ln -sfn /etc/nginx/sites-available/${APP_NAME} /etc/nginx/sites-enabled/${APP_NAME}
nginx -t
systemctl daemon-reload
systemctl enable "${APP_NAME}.service"
systemctl restart "${APP_NAME}.service"
if ! systemctl is-active --quiet "${APP_NAME}.service"; then
  echo "The website service failed to start. Recent service logs:" >&2
  journalctl -u "${APP_NAME}.service" -n 40 --no-pager >&2
  exit 1
fi
systemctl enable --now nginx

cat <<EOF

CleanUp Tool website is running.

Local app:  http://127.0.0.1:${APP_PORT}
Public URL: http://$(hostname -I | awk '{print $1}')

Service status:
  systemctl status ${APP_NAME}.service

To update after changing the site files, run this script again.
For HTTPS, point your domain at this server and add a certificate with certbot.
EOF
