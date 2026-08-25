# Update and enable HTTPS

Run this from the Website repository on the EC2 server. It pulls the latest Website commit, deploys the static files through Nginx, installs Certbot, and configures HTTPS for `cleanup-tool.myles-mattlock.co.uk`.

Before running it:

- Create a DNS `A` record named `cleanup-tool` pointing to the EC2 public or Elastic IP. This creates `cleanup-tool.myles-mattlock.co.uk`.
- Allow inbound TCP ports `80` and `443` in the EC2 security group.
- Make sure the repository has no uncommitted server-side changes.

Run:

```sh
chmod +x deploy-https.sh install-ubuntu-arm64.sh
sudo ./deploy-https.sh you@example.com
```

The email is used by Let's Encrypt for certificate expiry notices. The script uses `git pull --ff-only` and will stop if the server repository has diverged.

Check the result:

```sh
curl -I https://cleanup-tool.myles-mattlock.co.uk
sudo certbot renew --dry-run
```

The v3.0.0 download is hosted by this website at `/assets/SystemCleanUp-v3.0.0.zip`. Replace that asset and update the filename in `index.html` when publishing a newer release. The official source and release history remain available through the GitHub links.
