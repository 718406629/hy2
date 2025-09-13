#!/bin/bash
# Hysteria2 一键安装脚本（支持有域名 / 无域名）

HY_BIN="/usr/local/bin/hysteria"
CONF_DIR="/etc/hysteria"
CONF_FILE="$CONF_DIR/config.yaml"
echo "请选择安装模式："
echo "1) 有域名 (推荐)"
echo "2) 无域名 (自签名)"
read -p "输入数字选择模式 [1/2]: " MODE

read -p "设置连接密码（默认 mypass123）: " PASSWORD
[ -z "$PASSWORD" ] && PASSWORD="mypass123"

apt update -y && apt install -y curl wget openssl socat unzip

# 下载 Hysteria2
wget -O $HY_BIN https://github.com/apernet/hysteria/releases/download/app/v2.5.0/hysteria-linux-amd64
chmod +x $HY_BIN
mkdir -p $CONF_DIR

if [ "$MODE" == "1" ]; then
    read -p "请输入绑定的域名: " DOMAIN
    curl https://get.acme.sh | sh
    ~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone -k ec-256
    ~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc \
      --key-file $CONF_DIR/key.pem \
      --fullchain-file $CONF_DIR/cert.pem

    cat > $CONF_FILE <<EOF
listen: :443
auth:
  type: password
  password: $PASSWORD
tls:
  cert: $CONF_DIR/cert.pem
  key: $CONF_DIR/key.pem
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
EOF

elif [ "$MODE" == "2" ]; then
    openssl req -x509 -newkey rsa:2048 -keyout $CONF_DIR/key.pem -out $CONF_DIR/cert.pem -days 365 -nodes -subj "/CN=hy2.local"

    cat > $CONF_FILE <<EOF
listen: :443
auth:
  type: password
  password: $PASSWORD
tls:
  cert: $CONF_DIR/cert.pem
  key: $CONF_DIR/key.pem
  insecure: true
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
EOF
fi

# systemd 服务
cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria2 Service
After=network.target

[Service]
ExecStart=$HY_BIN server -c $CONF_FILE
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hysteria
systemctl restart hysteria

SERVER_IP=$(curl -s ipv4.ip.sb || curl -s ifconfig.me)

echo "======================================"
echo "✅ Hysteria2 已安装并运行"
echo "服务器地址: $SERVER_IP"
echo "端口: 443"
echo "密码: $PASSWORD"
if [ "$MODE" == "1" ]; then
    echo "域名: $DOMAIN"
    echo "客户端请填写域名，skip-cert-verify 可设为 false"
else
    echo "无域名模式 (自签名证书)"
    echo "客户端请使用 sni: hy2.local, 并开启 skip-cert-verify: true"
fi
echo "======================================"
