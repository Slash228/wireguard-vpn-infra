# WireGuard VPN Infrastructure

Automated WireGuard VPN infrastructure with monitoring, alerting, and secure user management. One-command deployment via Ansible.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     VPN Server                          │
│                                                         │
│  ┌──────────┐  ┌────────────┐  ┌──────────────────┐    │
│  │ WireGuard│  │ Prometheus │  │   Alertmanager   │    │
│  │  :51820  │  │   :9090    │  │     :9093        │    │
│  └──────────┘  └─────┬──────┘  └───────┬──────────┘    │
│                      │                 │                │
│  ┌──────────┐  ┌─────┴──────┐  ┌───────┴──────────┐    │
│  │  Nginx   │──│  Grafana   │  │    Telegram Bot   │    │
│  │   :80    │  │   :3000    │  │                   │    │
│  └──────────┘  └────────────┘  └───────────────────┘    │
│                                                         │
│  ┌──────────┐  ┌────────────┐                           │
│  │  Node    │  │ WG Metrics │                           │
│  │ Exporter │  │ Collector  │                           │
│  │  :9100   │  │ (every 15s)│                           │
│  └──────────┘  └────────────┘                           │
│                                                         │
│  Security: UFW + Fail2ban + SSH hardening               │
└─────────────────────────────────────────────────────────┘
```

## Technology Stack

- **VPN:** WireGuard
- **Infrastructure:** Docker, Docker Compose, Nginx
- **Automation:** Ansible
- **Monitoring:** Prometheus, Grafana, Alertmanager, Node Exporter
- **Security:** UFW, Fail2ban, SSH hardening
- **CI/CD:** GitHub Actions

## Requirements

- macOS / Linux / Windows (with WSL2)
- Homebrew (macOS) or apt (Linux)
- Git

## Setup from Scratch

### 1. Clone the Repository

```bash
git clone https://github.com/Slash228/wireguard-vpn-infra.git
cd wireguard-vpn-infra
```

### 2. Install Multipass

```bash
brew install multipass            # macOS
sudo snap install multipass       # Linux
```

### 3. Create the Virtual Machine

```bash
multipass launch --name vpn-server --memory 2G --disk 20G
```

Get the VM's IP address:

```bash
multipass info vpn-server
```

Note the `IPv4` value (e.g. `192.168.64.7`).

### 4. Configure SSH Access

Generate an SSH key if you don't have one:

```bash
ssh-keygen -t ed25519 -C "vpn-project"
```

Copy the key to the VM:

```bash
multipass exec vpn-server -- bash -c "echo '$(cat ~/.ssh/id_ed25519.pub)' >> ~/.ssh/authorized_keys"
```

Verify:

```bash
ssh ubuntu@<YOUR_VM_IP>
```

### 5. Install Ansible

```bash
python3 -m venv ~/ansible-env
source ~/ansible-env/bin/activate
pip install ansible docker
ansible-galaxy collection install community.docker
```

### 6. Update Configuration

Update the VM's IP address in two files:

```bash
# ansible/inventory/hosts.yml — change ansible_host
nano ansible/inventory/hosts.yml

# docker/docker-compose.yml — change SERVERURL default
nano docker/docker-compose.yml
```

### 7. Configure Telegram Alerts (Optional)

Create a Telegram bot via @BotFather, get the token and your chat_id, then update:

```bash
nano docker/alertmanager/alertmanager.yml
```

Replace `YOUR_BOT_TOKEN_HERE` with your bot token and `0` with your chat_id.

### 8. Verify Ansible Connection

```bash
cd ansible
ansible all -m ping
```

Should respond with `SUCCESS` and `pong`.

## Deployment

### Deploy Full Stack

```bash
cd ansible
ansible-playbook playbooks/deploy.yml
```

This will install Docker, copy all configs, and start: WireGuard, Prometheus, Grafana, Alertmanager, Node Exporter, Nginx, and the WireGuard metrics collector.

After deployment:
- Grafana: `http://<VM_IP>:3000` (login: admin / admin123)
- Prometheus: `http://<VM_IP>:9090`
- Nginx proxy: `http://<VM_IP>` (routes to Grafana)

### Harden the Server

```bash
ansible-playbook playbooks/harden.yml
```

Configures UFW firewall, Fail2ban, disables SSH password auth and root login.

## User Management

### Add a User

```bash
ansible-playbook playbooks/add_user.yml -e user=alice
```

Config saved to `ansible/client-configs/alice.conf`.

### Remove a User

```bash
ansible-playbook playbooks/remove_user.yml -e user=alice
```

## Connecting to VPN

### macOS / Windows

1. Install **WireGuard** from App Store or wireguard.com
2. Import the `.conf` file from `ansible/client-configs/`
3. Activate the tunnel
4. Verify: `ping 10.13.13.1`

### iOS / Android

1. Install **WireGuard** from App Store / Google Play
2. Display QR code:

```bash
multipass shell vpn-server
docker exec wireguard /app/show-peer <name>
```

3. Scan the QR code in the app

## Project Structure

```
wireguard-vpn-infra/
├── .github/workflows/
│   └── lint.yml                          # CI: lint, validate, security checks
├── ansible/
│   ├── ansible.cfg                       # Ansible settings
│   ├── inventory/hosts.yml               # Server IP config
│   └── playbooks/
│       ├── deploy.yml                    # Full stack deployment
│       ├── add_user.yml                  # Add VPN user
│       ├── remove_user.yml              # Remove VPN user
│       └── harden.yml                    # Server hardening
├── docker/
│   ├── docker-compose.yml               # All services
│   ├── prometheus/
│   │   ├── prometheus.yml               # Scrape targets
│   │   └── alerts.yml                   # Alert rules
│   ├── alertmanager/
│   │   └── alertmanager.yml             # Telegram notifications
│   ├── grafana/provisioning/
│   │   ├── datasources/datasource.yml   # Prometheus datasource
│   │   └── dashboards/
│   │       ├── dashboard.yml            # Dashboard provisioning
│   │       └── dashboard1.json          # VPN monitoring dashboard
│   └── scripts/
│       └── wg_metrics.sh                # WireGuard metrics collector
├── nginx/
│   └── nginx.conf                       # Reverse proxy config
└── README.md
```

## Monitoring Dashboard

The Grafana dashboard includes:
- CPU Usage (stat panel with thresholds)
- RAM Usage (stat panel with thresholds)
- Disk Usage (gauge panel)
- WireGuard peer traffic — upload/download per peer (time series)
- Connected peers table

## Alert Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| WireGuardPeerInactive24h | Peer hasn't connected for 24+ hours | Warning |
| WireGuardHighTraffic | Traffic rate > 10MB/s for 5+ minutes | Critical |
| HostDiskUsageHigh | Disk usage > 80% | Critical |
| ServiceDown | Any monitored service is down for 2+ minutes | Critical |

## CI/CD Pipeline

GitHub Actions runs on every push/PR to main:
- **Ansible Lint** — validates playbook syntax and best practices
- **Docker Compose Validate** — checks compose file syntax
- **Nginx Config Validate** — tests nginx.conf syntax
- **Security Check** — ensures no private keys or tokens in repo

## Common Issues

**VM has no internet:** Turn off any VPN on your host machine.

**Ansible can't reach server:** Check IP in `ansible/inventory/hosts.yml` matches `multipass info vpn-server`.

**VPN connects but ping fails:** Ensure `network_mode: host` is set for WireGuard in docker-compose.yml.

**`ansible` command not found:** Run `source ~/ansible-env/bin/activate`.

## Team

- Member 1 — Infrastructure & VPN (Docker, WireGuard, Nginx)
- Member 2 — Automation & Security (Ansible, UFW, Fail2ban)
- Member 3 — Monitoring & Alerting (Prometheus, Grafana, Alertmanager)
