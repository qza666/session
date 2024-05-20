#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# 字体颜色设置
Green="\033[32m"
Red="\033[31m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

# 检查系统类型和版本
source '/etc/os-release'
OK="${Green}[OK]${Font}"
Error="${Red}[错误]${Font}"

# 判断是否为root用户
if [ 0 -ne $UID ]; then
    echo -e "${Error} ${RedBG} 当前用户不是root用户，请使用 'sudo -i' 切换到root用户后重新执行脚本 ${Font}"
    exit 1
fi

# 检查系统是否支持
check_system() {
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]]; then
        INS="yum"
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]]; then
        INS="apt-get"
    elif [[ "${ID}" == "ubuntu" && $(echo "${VERSION_ID}" | cut -d '.' -f1) -ge 16 ]]; then
        INS="apt-get"
    else
        echo -e "${Error} ${RedBG} 当前系统 ${ID} ${VERSION_ID} 不支持，安装中断 ${Font}"
        exit 1
    fi
    $INS update -y
    $INS install -y curl
}

# 设置随机端口，检查端口是否被占用
set_random_port() {
    while true; do
        port=$(shuf -i 2000-65000 -n 1)
        if [ $(lsof -i:"${port}" | wc -l) -eq 0 ]; then
            echo -e "${OK} ${GreenBG} 端口 ${port} 可用 ${Font}"
            break
        else
            echo -e "${Error} ${RedBG} 端口 ${port} 被占用，正在重新生成 ${Font}"
        fi
    done
}

# 安装socks5
install_socks5() {
    wget -O /usr/local/bin/socks --no-check-certificate https://github.com/kangcwei/ss5/releases/download/ss5/socks
    chmod +x /usr/local/bin/socks

    cat <<EOF > /etc/systemd/system/sockd.service
[Unit]
Description=Socks Service
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/socks run -config /etc/socks/config.yaml
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sockd.service

    mkdir -p /etc/socks
    cat <<EOF > /etc/socks/config.yaml
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "listen": "0.0.0.0",
            "port": $port,
            "protocol": "socks",
            "settings": {
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "freedom",
            "tag": "direct"
        },
        {
            "protocol": "blackhole",
            "tag": "block"
        }
    ]
}
EOF
    systemctl start sockd.service
    echo -e "${OK} ${GreenBG} Socks5已安装完成 ${Font}"
    IP=$(curl -4  http://ip.sb)
    echo "IP地址: $IP"
    echo "端口号: $port"
}

check_system
set_random_port
install_socks5
