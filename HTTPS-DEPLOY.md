# Update and enable HTTPS

Run this from the Website repository on the EC2 server. It pulls the latest Website commit, deploys both static sites through Nginx, installs Certbot, and configures HTTPS for `cleanup-tool.myles-mattlock.co.uk` and `myles-mattlock.co.uk`.

Before running it:

- Create DNS `A` records named `cleanup-tool` and `@`, both pointing to the EC2 public or Elastic IP. These create `cleanup-tool.myles-mattlock.co.uk` and `myles-mattlock.co.uk`.
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
curl -I https://myles-mattlock.co.uk
sudo certbot renew --dry-run
```

Release downloads are hosted by this website under `/assets/`, with the available versions listed in `index.html`. When publishing a newer release, add its archive to `assets/` and add a matching download link to the releases section. The official source and release history remain available through the GitHub link.
