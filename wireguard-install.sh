#!/bin/bash

# =============================
# 优化版 WireGuard 安装脚本
# 支持多客户端自动分配 IP
# =============================

set -e

echo "🚀 正在开始安装或添加 WireGuard 客户端..."

# 检查是否 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "❌ 错误：必须以 root 权限运行此脚本。" 
   exit 1
fi

WG_CONF="/etc/wireguard/wg0.conf"
WG_KEYS_DIR="/etc/wireguard"
IP_RANGE="10.0.0.0/24"
SERVER_PORT=51820

# Step 1: 获取公网 IP 和网卡
SERVER_IP=$(curl -s ifconfig.me)
WAN_INTERFACE=$(ip route get 1.1.1.1 | awk '{print $5}')

# Step 2: 安装依赖
echo "🔄 更新系统并安装依赖..."
apt update && apt upgrade -y
apt install -y wireguard qrencode iptables-persistent

# Step 3: 创建密钥目录
mkdir -p "$WG_KEYS_DIR"
cd "$WG_KEYS_DIR"

# Step 4: 如果是第一次运行，创建服务端密钥和配置
if [ ! -f "$WG_CONF" ]; then
    echo "🔐 生成服务端密钥对..."
    umask 077
    wg genkey | tee privatekey | wg pubkey > publickey
    SERVER_PRIVKEY=$(cat privatekey)
    SERVER_PUBKEY=$(cat publickey)

    cat <<EOF > "$WG_CONF"
[Interface]
PrivateKey = $SERVER_PRIVKEY
Address = 10.0.0.1/24
ListenPort = $SERVER_PORT
SaveConfig = true
EOF

    echo "📌 服务端配置已初始化，请勿重复删除 wg0.conf。"
else
    SERVER_PUBKEY=$(grep PrivateKey "$WG_CONF" | wg pubkey)
fi

# Step 5: 启用 IP 转发
echo "🌐 启用 IP 转发..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1

# Step 6: 配置 NAT 转发规则
echo "🔧 配置防火墙和 NAT 规则..."
iptables -A FORWARD -i wg0 -o "$WAN_INTERFACE" -j ACCEPT
iptables -A FORWARD -i "$WAN_INTERFACE" -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A POSTROUTING -o "$WAN_INTERFACE" -j MASQUERADE
netfilter-persistent save >/dev/null 2>&1

# Step 7: 启动 WireGuard
echo "🔌 启动 WireGuard 服务..."
systemctl stop wg-quick@wg0 2>/dev/null || true
wg-quick down wg0 2>/dev/null || true
wg-quick up wg0
systemctl enable wg-quick@wg0 >/dev/null 2>&1

# Step 8: 获取下一个可用客户端 IP
USED_IPS=$(grep AllowedIPs "$WG_CONF" | awk '{print $3}' | cut -d'/' -f1 | sort)
NEXT_IP="10.0.0.2"

for ip in $USED_IPS; do
    NEXT_IP="10.0.0.$(( $(echo "$NEXT_IP" | cut -d'.' -f4) + 1 ))"
    if [[ "$ip" != "$NEXT_IP" ]]; then
        break
    fi
done

# Step 9: 输入客户端名称
read -p "请输入客户端名称（例如 user1）：" CLIENT_NAME
if grep -q "\[Peer\]" "$WG_CONF" && grep -A 2 "AllowedIPs = 10.0.0.$(echo "$NEXT_IP" | cut -d'.' -f4)" "$WG_CONF"; then
    echo "⚠️ 已存在相同 IP 的客户端配置。请重试。"
    exit 1
fi

# Step 10: 生成客户端密钥
echo "🔐 生成客户端密钥对..."
CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | wg pubkey)

# Step 11: 添加客户端到配置文件
cat <<EOF >> "$WG_CONF"

[Peer]
PublicKey = $CLIENT_PUBKEY
AllowedIPs = $NEXT_IP/32
EOF

# Step 12: 生成客户端配置文件
CLIENT_CONF="$WG_KEYS_DIR/${CLIENT_NAME}.conf"
cat <<EOF > "$CLIENT_CONF"
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $NEXT_IP/32
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_CONF"

# Step 13: 生成二维码
echo "📱 正在生成二维码（可用于手机导入配置）..."
qrencode -t ansiutf8 < "$CLIENT_CONF"

# Step 14: 提示信息
echo ""
echo "✅ 客户端 '$CLIENT_NAME' 已成功添加！"
echo "📌 配置文件路径: $CLIENT_CONF"
echo "📶 客户端 IP 地址: $NEXT_IP"
echo "🔗 扫描上方二维码或将配置文件导入客户端即可连接。"
echo ""
echo "🎉 WireGuard 服务已启动，并设置为开机自启。"
echo "🛠️ 常用命令："
echo "启动服务: sudo wg-quick up wg0"
echo "停止服务: sudo wg-quick down wg0"
echo "查看状态: sudo wg show"