# Ubuntu ARM deployment

`install-ubuntu-arm64.sh` installs and runs the website on Ubuntu 26.04 ARM64 (`aarch64`). Run it from the Website repository, or from another directory and it will clone the public Website repository automatically. It installs:

- .NET 10 runtime and the dependencies required by ASP.NET Core
- Nginx
- Git, when the Website repository needs to be downloaded
- A dedicated `cleanup-site` system user
- A `systemd` service that runs the published website on `127.0.0.1:5000`

## Install

Copy the repository to the Ubuntu server, then run from the repository root:

```sh
chmod +x install-ubuntu-arm64.sh
sudo ./install-ubuntu-arm64.sh
```

To use a different website repository, set its URL before running the script:

```sh
sudo env WEBSITE_REPO_URL=https://github.com/your-name/your-website.git ./install-ubuntu-arm64.sh
```

Open the printed server address in a browser. Make sure TCP port 80 is allowed in the server firewall and cloud provider security group.

The script is safe to run again after website changes. It republishes the project and restarts the service through `systemd`.

```sh
sudo systemctl status cleanup-tool-website.service
sudo journalctl -u cleanup-tool-website.service -f
```

## HTTPS

The installer serves HTTP through Nginx. For HTTPS, point a domain at the server, allow TCP port 443, then install Certbot and configure an Nginx certificate:

```sh
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d example.com
```

Replace `example.com` with your real domain. The server should have a stable public IP before requesting the certificate.
