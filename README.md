# WireGuard VPN Infrastructure

Automated WireGuard VPN infrastructure with user management, security hardening, and (soon) monitoring. One-command deployment via Ansible.

## What's Already Implemented

- WireGuard VPN server in Docker
- Automated deployment via Ansible
- User management (add/remove) via playbooks
- Server hardening: UFW, Fail2ban, SSH password authentication disabled

## Requirements

- macOS (for Windows/Linux steps are similar, only Multipass installation differs)
- Homebrew
- Git

## Setup from Scratch

### 1. Clone the Repository

```bash
git clone https://github.com/Slash228/wireguard-vpn-infra.git
cd wireguard-vpn-infra
```

### 2. Install Multipass (virtual machine for the server)

```bash
brew install multipass
```

### 3. Create the Virtual Machine

```bash
multipass launch --name vpn-server --memory 2G --disk 20G
```

Get the VM's IP (remember it):

```bash
multipass info vpn-server
```

Find the `IPv4:` line — this is your server's address.

### 4. Configure SSH Access

Generate an SSH key if you don't have one:

```bash
ssh-keygen -t ed25519 -C "vpn-project"
```

Press Enter for all prompts.

Copy the public key to the VM:

```bash
multipass exec vpn-server -- bash -c "echo '$(cat ~/.ssh/id_ed25519.pub)' >> ~/.ssh/authorized_keys"
```

Test the connection:

```bash
ssh ubuntu@192.168.64.7
```

The session should open without a password prompt. Exit back:

```bash
exit
```

### 5. Install Ansible in a Virtual Environment

```bash
python3 -m venv ~/ansible-env
source ~/ansible-env/bin/activate
pip install ansible
ansible-galaxy collection install community.docker
pip install docker
```

To make Ansible available every time you open a terminal:

```bash
echo 'source ~/ansible-env/bin/activate' >> ~/.zshrc
```

### 6. Update the IP in Ansible Inventory

Open the file:

```bash
nano ansible/inventory/hosts.yml
```

Replace the IP with your VM's address:

```yaml
all:
  hosts:
    vpn-server:
      ansible_host: 192.168.64.7   # ← your IP from multipass info
      ansible_user: ubuntu
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519
```

### 7. Update the IP in docker-compose.yml

```bash
nano docker/docker-compose.yml
```

Replace `SERVERURL` with your IP.

### 8. Verify Ansible Can Reach the Server

```bash
cd ansible
ansible all -m ping
```

Should respond with `SUCCESS` and `pong`.

## Deploy the Infrastructure

From the `ansible/` folder:

```bash
ansible-playbook playbooks/deploy.yml
```

The playbook will:
- Install Docker and Docker Compose on the server
- Configure system parameters for WireGuard
- Copy docker-compose.yml to the server
- Start the WireGuard container
- Generate initial configs for 3 users (peer1, peer2, peer3)

## User Management

### Add a User

```bash
ansible-playbook playbooks/add_user.yml -e user=alice
```

The client config will be saved to `ansible/client-configs/alice.conf`.

### Remove a User

```bash
ansible-playbook playbooks/remove_user.yml -e user=alice
```

## Server Hardening

```bash
ansible-playbook playbooks/harden.yml
```

Configures:
- UFW firewall (only ports 22, 443, 51820 open)
- Fail2ban for SSH brute-force protection
- Disables SSH password authentication
- Disables root SSH login

## Connecting to the VPN

### macOS

1. Download the **WireGuard** app from the App Store
2. Open the app → "Import Tunnel(s) from File"
3. Select the file `ansible/client-configs/<your_name>.conf`
4. Click "Activate"

Verify the connection:

```bash
ping -c 3 10.13.13.1
```

If ping succeeds, the VPN is working.

### iOS / Android

1. Install the **WireGuard** app from App Store / Google Play
2. On your Mac, display the QR code in the terminal:

```bash
multipass shell vpn-server
docker exec wireguard /app/show-peer <number_or_name>
```

For example: `docker exec wireguard /app/show-peer alice`

3. Scan the QR code with your phone using the WireGuard app
4. Activate the tunnel

## Project Structure
wireguard-vpn-infra/
├── ansible/
│   ├── ansible.cfg              # Ansible settings
│   ├── inventory/hosts.yml      # Server IP
│   ├── playbooks/
│   │   ├── deploy.yml           # Full deployment
│   │   ├── add_user.yml         # Add a user
│   │   ├── remove_user.yml      # Remove a user
│   │   └── harden.yml           # Server hardening
│   └── client-configs/          # User configs (generated)
├── docker/
│   └── docker-compose.yml       # WireGuard container
├── monitoring/                  # (soon) Prometheus, Grafana
├── nginx/                       # (soon) reverse proxy + SSL
└── docs/                        # Documentation and screenshots
## Common Issues

### VM Has No Internet Access

Turn off any VPN on your Mac — Multipass can't route through it.

### Ansible Can't Reach the Server

Make sure the IP in `ansible/inventory/hosts.yml` matches the VM's current IP (`multipass info vpn-server`). Multipass may assign a new IP after restart.

### VPN Connects but Ping Fails

Make sure `network_mode: host` is set in Docker Compose. Docker's UDP proxy doesn't work well with WireGuard.

### Command `ansible` Not Found

Activate the virtual environment:

```bash
source ~/ansible-env/bin/activate
```

## Next Steps

- Prometheus + Grafana for VPN connection and traffic monitoring
- Alertmanager with Telegram notifications
- Nginx reverse proxy with SSL in front of Grafana
- GitHub Actions for CI/CD
