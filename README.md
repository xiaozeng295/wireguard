# WireGuard 自动安装脚本

这是一个用于 Ubuntu 系统的 WireGuard 自动安装脚本，适用于阿里云等国内服务器环境。

## 📦 功能特性

- 自动安装 WireGuard
- 生成服务端密钥对
- 创建配置文件 wg0.conf
- 支持客户端一键配置生成
- 可选二维码输出，方便手机导入

## 🧪 支持系统

- Ubuntu 20.04 LTS
- Ubuntu 22.04 LTS

## 📥 安装方法

```bash
wget https://raw.githubusercontent.com/你的用户名/你的仓库名/main/wireguard-install.sh 
chmod +x wireguard-install.sh
sudo ./wireguard-install.sh
```

## 📋 使用说明
运行后会提示输入客户端名称，脚本将自动生成客户端配置文件，并输出二维码。


## 📞 联系方式
如有问题欢迎提交 issue