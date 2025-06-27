#!/bin/bash

# ========== 安装依赖 ==========
echo "安装依赖..."
sudo apt update && sudo apt install -y wget unzip

# ========== 下载 GoEdge Node 包 ==========
echo "下载 GoEdge Node 程序..."
wget https://dl.goedge.cloud/edge-node/v1.4.7/edge-node-linux-amd64-plus-v1.4.7.zip  -O edge-node-linux-amd64-plus-v1.4.7.zip

# ========== 解压文件 ==========
echo "解压文件..."
unzip edge-node-linux-amd64-plus-v1.4.7.zip
cd edge-node || { echo "进入目录失败"; exit 1; }

# ========== 创建配置文件 api_cluster.yaml（严格按用户指定格式写入）==========
echo "写入配置文件 api_cluster.yaml..."
cat <<'EOF' > /configs/api_cluster.yaml
rpc.endpoints: [ "http://148.66.3.82:8001" ]
clusterId: "b6b507f7a3c5afdb884caa9f48db771a"
secret: "amxplSyNUNqvJUzAlexCLZ7zdX3oXpB8"
EOF

# ========== 设置文件权限 ==========
echo "设置配置文件权限..."
chmod 755 /configs/api_cluster.yaml

# ========== 启动服务 ==========
echo "启动 GoEdge Node..."
./bin/edge-node start

echo "部署完成！GoEdge Node 已启动。"
