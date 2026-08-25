#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN_NAME="cleanup-tool.myles-mattlock.co.uk"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER="${SUDO_USER:-ubuntu}"
CERTBOT_EMAIL="${1:-}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root: sudo ./deploy-https.sh you@example.com" >&2
  exit 1
fi

if [[ -z "${CERTBOT_EMAIL}" || "${CERTBOT_EMAIL}" != *@*.* ]]; then
  echo "Provide a valid email address for Let's Encrypt." >&2
  echo "Usage: sudo ./deploy-https.sh you@example.com" >&2
  exit 1
fi

if [[ ! -f "${SOURCE_DIR}/install-ubuntu-arm64.sh" || ! -d "${SOURCE_DIR}/.git" ]]; then
  echo "Run this script from the Website Git repository." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if id --user "${DEPLOY_USER}" >/dev/null 2>&1; then
  git -C "${SOURCE_DIR}" config --global --add safe.directory "${SOURCE_DIR}"
  runuser -u "${DEPLOY_USER}" -- git -C "${SOURCE_DIR}" pull --ff-only
else
  git -C "${SOURCE_DIR}" pull --ff-only
fi

bash "${SOURCE_DIR}/install-ubuntu-arm64.sh"

apt-get update
apt-get install -y --no-install-recommends certbot python3-certbot-nginx

certbot --nginx --non-interactive --agree-tos \
  --email "${CERTBOT_EMAIL}" \
  --redirect \
  --keep-until-expiring \
  -d "${DOMAIN_NAME}"

nginx -t
systemctl reload nginx

cat <<EOF

HTTPS is enabled for:
  https://${DOMAIN_NAME}

Certificate renewal test:
  certbot renew --dry-run
EOF
