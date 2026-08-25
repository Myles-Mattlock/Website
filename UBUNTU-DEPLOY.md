# Ubuntu ARM deployment

`install-ubuntu-arm64.sh` installs the static website on Ubuntu 26.04 ARM64 (`aarch64`). Run it from the Website repository. It deploys only this repository and does not clone or serve the CleanUp-Tool repository. It installs:

- Nginx

## Install

Copy the repository to the Ubuntu server, then run from the repository root:

```sh
chmod +x install-ubuntu-arm64.sh
sudo ./install-ubuntu-arm64.sh
```

Create DNS A records for `myles-mattlock.co.uk` and `www.myles-mattlock.co.uk` pointing to the server's public IPv4 address. Then open `http://myles-mattlock.co.uk`. Make sure TCP port 80 is allowed in the server firewall and cloud provider security group.

The script is safe to run again after website changes. It copies the current repository files and reloads Nginx.

```sh
sudo systemctl status nginx
```

## HTTPS

The installer serves HTTP through Nginx. For HTTPS, point a domain at the server, allow TCP port 443, then install Certbot and configure an Nginx certificate:

```sh
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d example.com
```

Replace `example.com` with your real domain. The server should have a stable public IP before requesting the certificate.
