#!/bin/bash

# =============================
# WireGuard 自动化安装脚本
# 支持 Ubuntu 20.04/22.04
# =============================

set -e

echo "🚀 正在开始安装 WireGuard..."

# 检查是否 root 用户
if [[ $EUID -ne 0 ]]; then
   echo "❌ 错误：必须以 root 权限运行此脚本。" 
   exit 1
fi

# 获取公网 IP
SERVER_IP=$(curl -s ifconfig.me)

# 默认监听端口
SERVER_PORT=51820

# 客户端地址池
CLIENT_IP="10.0.0.2"

WG_CONF="/etc/wireguard/wg0.conf"
WG_KEYS_DIR="/etc/wireguard"

# Step 1: 更新系统并安装 WireGuard 和相关工具
echo "🔄 更新系统软件包..."
apt update && apt upgrade -y
echo "📦 安装 WireGuard 及相关工具..."
apt install -y wireguard qrencode iptables-persistent

# Step 2: 创建密钥目录
mkdir -p "$WG_KEYS_DIR"
cd "$WG_KEYS_DIR"

# Step 3: 生成服务端密钥
echo "🔐 生成服务端密钥对..."
umask 077
wg genkey | tee privatekey_server | wg pubkey > publickey_server
SERVER_PRIVKEY=$(cat privatekey_server)
SERVER_PUBKEY=$(cat publickey_server)

# Step 4: 创建配置文件
echo "📝 创建 WireGuard 配置文件..."
cat <<EOF > "$WG_CONF"
[Interface]
PrivateKey = $SERVER_PRIVKEY
Address = 10.0.0.1/24
ListenPort = $SERVER_PORT
SaveConfig = true

# 示例客户端配置（可添加多个）
[Peer]
PublicKey = CLIENT_PUBLIC_KEY
AllowedIPs = $CLIENT_IP/32
EOF

# Step 5: 启用 IP 转发
echo "🌐 启用 IP 转发..."
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p >/dev/null 2>&1

# Step 6: 配置防火墙和 NAT 规则
WAN_INTERFACE=$(ip route get 1.1.1.1 | awk '{print $5}')

echo "🔧 配置防火墙和 NAT 转发..."
iptables -A FORWARD -i wg0 -o $WAN_INTERFACE -j ACCEPT
iptables -A FORWARD -i $WAN_INTERFACE -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -t nat -A POSTROUTING -o $WAN_INTERFACE -j MASQUERADE

# 保存 iptables
netfilter-persistent save >/dev/null 2>&1

# Step 7: 启动 WireGuard
echo "🔌 启动 WireGuard 服务..."
wg-quick up wg0
systemctl enable wg-quick@wg0 >/dev/null 2>&1

# Step 8: 生成客户端配置
read -p "请输入客户端名称（例如 user1）：" CLIENT_NAME
CLIENT_PRIVKEY=$(wg genkey)
CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | wg pubkey)

# 替换配置文件中的 Peer 配置
sed -i "/PublicKey = CLIENT_PUBLIC_KEY/c\PublicKey = $CLIENT_PUBKEY" "$WG_CONF"

# 创建客户端配置文件
CLIENT_CONF="$WG_KEYS_DIR/${CLIENT_NAME}.conf"
cat <<EOF > "$CLIENT_CONF"
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = $CLIENT_IP/32
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBKEY
Endpoint = $SERVER_IP:$SERVER_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# 生成二维码（方便手机导入）
qrencode -t ansiutf8 < "$CLIENT_CONF"

echo "✅ 客户端配置已生成：$CLIENT_CONF"
echo "📱 扫描上方二维码或手动导入配置文件即可连接 WireGuard。"
echo ""
echo "🎉 安装完成！你可以使用以下命令管理 WireGuard："
echo "启动服务: sudo wg-quick up wg0"
echo "停止服务: sudo wg-quick down wg0"
echo "查看状态: sudo wg show"