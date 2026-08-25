#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="cleanup-tool-website"
DOMAIN_NAME="cleanup-tool.myles-mattlock.co.uk"
WEB_ROOT="/var/www/${APP_NAME}"
BACKUP_DIR="/var/backups/${APP_NAME}"
BACKUP_FILE="${BACKUP_DIR}/latest.tar.gz"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER="${SUDO_USER:-ubuntu}"
STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script as root: sudo ./update-site.sh" >&2
  exit 1
fi

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  echo "Run this script from the Website Git repository." >&2
  exit 1
fi

if id --user "${DEPLOY_USER}" >/dev/null 2>&1; then
  git -C "${SOURCE_DIR}" config --global --add safe.directory "${SOURCE_DIR}"
  runuser -u "${DEPLOY_USER}" -- git -C "${SOURCE_DIR}" pull --ff-only
else
  git -C "${SOURCE_DIR}" pull --ff-only
fi

for required_file in index.html styles.css brand-overrides.css script.js; do
  if [[ ! -f "${SOURCE_DIR}/${required_file}" ]]; then
    echo "Missing required website file: ${required_file}" >&2
    exit 1
  fi
done

if [[ ! -d "${SOURCE_DIR}/assets" ]]; then
  echo "Missing required website directory: assets/" >&2
  exit 1
fi

install -d -o root -g www-data -m 0755 "${WEB_ROOT}" "${BACKUP_DIR}"

if [[ -n "$(find "${WEB_ROOT}" -mindepth 1 -print -quit)" ]]; then
  tar -czf "${BACKUP_FILE}" -C "${WEB_ROOT}" .
  chmod 0600 "${BACKUP_FILE}"
fi

cp "${SOURCE_DIR}/index.html" "${SOURCE_DIR}/styles.css" "${SOURCE_DIR}/brand-overrides.css" "${SOURCE_DIR}/script.js" "${STAGING_DIR}/"
cp -a "${SOURCE_DIR}/assets" "${STAGING_DIR}/"
find "${STAGING_DIR}" -type d -exec chmod 0755 {} +
find "${STAGING_DIR}" -type f -exec chmod 0644 {} +

find "${WEB_ROOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "${STAGING_DIR}/." "${WEB_ROOT}/"
chown -R root:www-data "${WEB_ROOT}"

if ! nginx -t; then
  echo "Nginx validation failed. Restoring the previous website files." >&2
  find "${WEB_ROOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  if [[ -f "${BACKUP_FILE}" ]]; then
    tar -xzf "${BACKUP_FILE}" -C "${WEB_ROOT}"
  fi
  chown -R root:www-data "${WEB_ROOT}"
  exit 1
fi

systemctl reload nginx

cat <<EOF

Website updated successfully.

URL: https://${DOMAIN_NAME}
Backup: ${BACKUP_FILE}

The backup is replaced on the next update, so exactly one previous copy is retained.
EOF
