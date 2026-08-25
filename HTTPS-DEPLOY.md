# Update and enable HTTPS

Run this from the Website repository on the EC2 server. It pulls the latest Website commit, deploys the static files through Nginx, installs Certbot, and configures HTTPS for both domain names.

Before running it:

- Create DNS `A` records for `myles-mattlock.co.uk` and `www.myles-mattlock.co.uk` pointing to the EC2 public or Elastic IP.
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
curl -I https://myles-mattlock.co.uk
sudo certbot renew --dry-run
```
