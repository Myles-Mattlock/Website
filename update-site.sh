#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="cleanup-tool-website"
DOMAIN_NAME="cleanup-tool.myles-mattlock.co.uk"
PERSONAL_DOMAIN_NAME="myles-mattlock.co.uk"
WEB_ROOT="/var/www/${APP_NAME}"
PERSONAL_APP_NAME="myles-mattlock-website"
PERSONAL_WEB_ROOT="/var/www/${PERSONAL_APP_NAME}"
BACKUP_DIR="/var/backups/${APP_NAME}"
BACKUP_FILE="${BACKUP_DIR}/latest.tar.gz"
SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_USER="${SUDO_USER:-ubuntu}"
STAGING_DIR="$(mktemp -d)"
PERSONAL_STAGING_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${STAGING_DIR}"
  rm -rf "${PERSONAL_STAGING_DIR}"
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

for required_file in index.html releases.html styles.css brand-overrides.css script.js; do
  if [[ ! -f "${SOURCE_DIR}/${required_file}" ]]; then
    echo "Missing required website file: ${required_file}" >&2
    exit 1
  fi
done

for required_file in myles-mattlock.html myles-mattlock.css "assets/Myles Mattlock Logo.jpeg"; do
  if [[ ! -f "${SOURCE_DIR}/${required_file}" ]]; then
    echo "Missing personal website file: ${required_file}" >&2
    exit 1
  fi
done

if [[ ! -d "${SOURCE_DIR}/assets" ]]; then
  echo "Missing required website directory: assets/" >&2
  exit 1
fi

install -d -o root -g www-data -m 0755 "${WEB_ROOT}" "${PERSONAL_WEB_ROOT}" "${BACKUP_DIR}"

if [[ -n "$(find "${WEB_ROOT}" -mindepth 1 -print -quit)" ]]; then
  tar -czf "${BACKUP_FILE}" -C "${WEB_ROOT}" .
  chmod 0600 "${BACKUP_FILE}"
fi

cp "${SOURCE_DIR}/index.html" "${SOURCE_DIR}/releases.html" "${SOURCE_DIR}/styles.css" "${SOURCE_DIR}/brand-overrides.css" "${SOURCE_DIR}/script.js" "${STAGING_DIR}/"
cp -a "${SOURCE_DIR}/assets" "${STAGING_DIR}/"
install -d "${PERSONAL_STAGING_DIR}/assets"
cp "${SOURCE_DIR}/myles-mattlock.html" "${SOURCE_DIR}/myles-mattlock.css" "${PERSONAL_STAGING_DIR}/"
cp "${SOURCE_DIR}/assets/Myles Mattlock Logo.jpeg" "${PERSONAL_STAGING_DIR}/assets/"
find "${STAGING_DIR}" -type d -exec chmod 0755 {} +
find "${STAGING_DIR}" -type f -exec chmod 0644 {} +
find "${PERSONAL_STAGING_DIR}" -type d -exec chmod 0755 {} +
find "${PERSONAL_STAGING_DIR}" -type f -exec chmod 0644 {} +

if [[ ! -s "${STAGING_DIR}/index.html" || ! -s "${STAGING_DIR}/releases.html" || ! -f "${STAGING_DIR}/assets/cleanup-icon.png" ]]; then
  echo "The staged website is incomplete; live files were not changed." >&2
  exit 1
fi

if [[ ! -s "${PERSONAL_STAGING_DIR}/myles-mattlock.html" || ! -s "${PERSONAL_STAGING_DIR}/myles-mattlock.css" || ! -s "${PERSONAL_STAGING_DIR}/assets/Myles Mattlock Logo.jpeg" ]]; then
  echo "The staged personal website is incomplete; live files were not changed." >&2
  exit 1
fi

restore_backup() {
  find "${WEB_ROOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
  if [[ -f "${BACKUP_FILE}" ]]; then
    tar -xzf "${BACKUP_FILE}" -C "${WEB_ROOT}"
    chown -R root:www-data "${WEB_ROOT}"
  fi
}

find "${WEB_ROOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "${STAGING_DIR}/." "${WEB_ROOT}/"
chown -R root:www-data "${WEB_ROOT}"
find "${PERSONAL_WEB_ROOT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "${PERSONAL_STAGING_DIR}/." "${PERSONAL_WEB_ROOT}/"
chown -R root:www-data "${PERSONAL_WEB_ROOT}"

for required_file in index.html releases.html styles.css brand-overrides.css script.js; do
  if ! cmp -s "${STAGING_DIR}/${required_file}" "${WEB_ROOT}/${required_file}"; then
    echo "The live file was not copied correctly: ${required_file}" >&2
    restore_backup
    exit 1
  fi
done

for required_file in myles-mattlock.html myles-mattlock.css; do
  if ! cmp -s "${PERSONAL_STAGING_DIR}/${required_file}" "${PERSONAL_WEB_ROOT}/${required_file}"; then
    echo "The live personal site file was not copied correctly: ${required_file}" >&2
    restore_backup
    exit 1
  fi
done

cat > /etc/nginx/sites-available/${PERSONAL_APP_NAME} <<EOF
server {
  listen 80;
  listen [::]:80;
  server_name ${PERSONAL_DOMAIN_NAME};

  root ${PERSONAL_WEB_ROOT};
  index myles-mattlock.html;

  location / {
    try_files \$uri \$uri/ /myles-mattlock.html;
  }
}
EOF
ln -sfn "/etc/nginx/sites-available/${PERSONAL_APP_NAME}" "/etc/nginx/sites-enabled/${PERSONAL_APP_NAME}"

if ! nginx -t || ! test -s "${WEB_ROOT}/index.html" || ! test -s "${WEB_ROOT}/releases.html" || ! test -f "${WEB_ROOT}/assets/cleanup-icon.png"; then
  echo "Website validation failed. Restoring the previous website files." >&2
  restore_backup
  exit 1
fi

systemctl reload nginx

if ! curl --fail --silent --show-error --max-time 10 \
  -H "Host: ${DOMAIN_NAME}" \
  "http://127.0.0.1/" >/dev/null; then
  echo "The local Nginx site check failed. Restoring the previous website files." >&2
  restore_backup
  systemctl reload nginx
  exit 1
fi

if ! curl --fail --silent --show-error --max-time 10 \
  -H "Host: ${DOMAIN_NAME}" \
  "http://127.0.0.1/releases.html" >/dev/null; then
  echo "The local Nginx releases page check failed. Restoring the previous website files." >&2
  restore_backup
  systemctl reload nginx
  exit 1
fi

if ! curl --fail --silent --show-error --max-time 10 \
  -H "Host: ${PERSONAL_DOMAIN_NAME}" \
  "http://127.0.0.1/" >/dev/null; then
  echo "The local personal website check failed." >&2
  restore_backup
  systemctl reload nginx
  exit 1
fi

cat <<EOF

Website updated successfully.

URL: https://${DOMAIN_NAME}
Backup: ${BACKUP_FILE}

The backup is replaced on the next update, so exactly one previous copy is retained.
EOF
