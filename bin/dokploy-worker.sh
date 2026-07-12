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
# Write to the MAIN sshd_config (this is what Dokploy's security checklist reads)
# AND to a drop-in so it also wins over cloud-init's sshd_config.d/*.conf.
harden_ssh() {
  key="$1"; val="$2"
  sed -i "/^[[:space:]]*#\?[[:space:]]*${key}[[:space:]]/Id" /etc/ssh/sshd_config
  echo "${key} ${val}" >> /etc/ssh/sshd_config
}
harden_ssh PasswordAuthentication no
harden_ssh UsePAM no
harden_ssh PermitRootLogin prohibit-password

cat > /etc/ssh/sshd_config.d/99-dokploy-hardening.conf <<'EOF'
PermitRootLogin prohibit-password
PasswordAuthentication no
UsePAM no
EOF
sshd -t && systemctl restart sshd

# Brute force protection: enable the SSH jail in aggressive mode
cat > /etc/fail2ban/jail.d/dokploy-sshd.local <<'EOF'
[sshd]
enabled = true
mode = aggressive
maxretry = 3
bantime = 1h
EOF
systemctl enable --now fail2ban

# Firewall: OCI Ubuntu images already ship a default-deny iptables firewall
# (policy DROP + a catch-all "REJECT ... icmp-host-prohibited" rule).
# - Ports 80/443/3000 are published by Docker containers, so they bypass the
#   INPUT chain via DNAT/FORWARD; their exposure is controlled by the OCI
#   Security List (see network.tf), not here.
# - Docker Swarm ports are host-level services that DO traverse INPUT, so they
#   must be ACCEPTed BEFORE the catch-all REJECT rule. Using `ufw` does not work
#   here: its rules are appended AFTER the native REJECT and never match.
#   4789 (VXLAN) has no authentication and is restricted to the VCN network.
for p in 2376 2377 7946; do
  iptables -I INPUT 1 -s 10.0.0.0/16 -p tcp --dport "$p" -j ACCEPT
done
for p in 7946 4789; do
  iptables -I INPUT 1 -s 10.0.0.0/16 -p udp --dport "$p" -j ACCEPT
done
netfilter-persistent save

# Install Docker (required to join the Swarm cluster as a worker node)
curl -sSL https://get.docker.com | sh
