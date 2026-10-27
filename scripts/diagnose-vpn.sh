#!/usr/bin/env bash
# Диагностика AmneziaWG на VPS (только чтение, ключи не выводятся).
# Использование: scripts/diagnose-vpn.sh [ssh-хост]   (по умолчанию amster)
set -uo pipefail

host="${1:-amster}"

# JSON-логи gost из ProxyCommand отфильтрованы, остальные ошибки ssh видны
ssh "$host" 'bash -s' 2> >(grep -v '^{"time"' >&2) <<'REMOTE'
export PATH="$PATH:/usr/sbin:/sbin"
s() { echo; echo "=== $*"; }

s "сервис amneziawg-go"
systemctl is-active amneziawg-go; systemctl is-enabled amneziawg-go

s "интерфейс wg0"
ip -br addr show wg0

s "awg show (рукопожатия и трафик)"
sudo -n awg show

s "UDP-слушатель 443"
sudo -n ss -ulnp | grep ':443 ' || echo "НЕ слушает 443/udp"

s "ip_forward"
sysctl net.ipv4.ip_forward

s "дефолтный интерфейс"
ip -4 route show default

s "NAT: iptables nat POSTROUTING"
sudo -n iptables -t nat -S POSTROUTING 2>&1 || echo "iptables недоступен"

s "nftables ruleset (nat)"
sudo -n nft list ruleset 2>&1 | grep -i -B2 -A4 'masquerade' || echo "masquerade в nft не найден"

s "ufw"
sudo -n ufw status verbose 2>&1 || echo "ufw недоступен"

s "ufw: forward policy и NAT-блок"
grep '^DEFAULT_FORWARD_POLICY' /etc/default/ufw 2>&1
sudo -n grep -n -A4 'amneziawg NAT' /etc/ufw/before.rules 2>&1

s "iptables FORWARD"
sudo -n iptables -S FORWARD 2>&1 | head -20

s "лог amneziawg-go (последние 15)"
sudo -n journalctl -u amneziawg-go -n 15 --no-pager 2>&1
REMOTE
rc=$?
if [ "$rc" -ne 0 ]; then
  echo "ssh завершился с кодом $rc: до сервера не дошли (gost/сеть). Напрямую: ssh -o ProxyCommand=none ..." >&2
fi
exit "$rc"
