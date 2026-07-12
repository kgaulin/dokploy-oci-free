#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Add ubuntu SSH authorized keys to the root user
mkdir -p /root/.ssh
cp /home/ubuntu/.ssh/authorized_keys /root/.ssh/
chown root:root /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Add ubuntu user to sudoers
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

apt-get update -y
apt-get install -y openssh-server fail2ban

# SSH hardening: key-based auth only (Dokploy connects as root with a key).
# Use a drop-in so it wins over cloud-init's /etc/ssh/sshd_config.d/*.conf
cat > /etc/ssh/sshd_config.d/99-dokploy-hardening.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
UsePAM no
EOF
systemctl restart sshd

# Brute force protection
systemctl enable --now fail2ban

# Firewall (UFW): default deny incoming, open only what is required
ufw default deny incoming
ufw default allow outgoing

# Public services
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 3000/tcp  # Dokploy dashboard

# Docker Swarm cluster traffic — restricted to the VCN network only.
# 4789 (VXLAN) has no authentication and must never be exposed publicly.
ufw allow from 10.0.0.0/16 to any port 2376 proto tcp   # Docker daemon
ufw allow from 10.0.0.0/16 to any port 2377 proto tcp   # Swarm management
ufw allow from 10.0.0.0/16 to any port 7946 proto tcp   # Node discovery
ufw allow from 10.0.0.0/16 to any port 7946 proto udp   # Node discovery
ufw allow from 10.0.0.0/16 to any port 4789 proto udp   # Overlay network (VXLAN)

ufw --force enable

# Install Dokploy (pinned version)
export DOKPLOY_VERSION=v0.29.11
curl -sSL https://dokploy.com/install.sh | sh
