#!/bin/bash

# 現在のディレクトリをスクリプトのディレクトリに設定
cd $(dirname $0)
set -eu
set -o pipefail

# ヘルプメッセージ
usage() {
    echo "Usage: $0 -p <remote_port> [-t <target_host>] [-l <local_port>] [-s <service_name>]"
    echo ""
    echo "Options:"
    echo "  -p <remote_port>   Port number for the remote forwarding (e.g., 9898)"
    echo "  -t <target_host>   Target SSH host (default: springboard)"
    echo "  -l <local_port>    Local SSH port to forward (default: 22)"
    echo "  -s <service_name>  Name of the systemd service (default: remote_forwarding_<target_host>_<local_port>_to_<remote_port>)"
    echo "  -h                 Show this help message and exit"
    exit 1
}

# デフォルト値
LOCAL_PORT=22
TARGET_HOST=springboard

# 引数解析
while getopts ":p:t:l:s:h" opt; do
    case $opt in
        p) REMOTE_PORT=$OPTARG ;;
        t) TARGET_HOST=$OPTARG ;;
        l) LOCAL_PORT=$OPTARG ;;
        s) CUSTOM_SERVICE_NAME=$OPTARG ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# 必須引数チェック
if [[ -z "${REMOTE_PORT:-}" ]]; then
    echo "Error: -p is required."
    usage
fi

# サービス名の決定
if [[ -z "${CUSTOM_SERVICE_NAME:-}" ]]; then
    SERVICE_NAME="remote_forwarding_${TARGET_HOST}_${LOCAL_PORT}_to_${REMOTE_PORT}"
else
    SERVICE_NAME=$CUSTOM_SERVICE_NAME
fi

# autosshがなければインストール
which autossh >/dev/null || sudo apt -y install autossh

# systemdサービスファイルの動的生成
SERVICE_FILE=/etc/systemd/system/$SERVICE_NAME.service

cat <<EOL | sudo tee $SERVICE_FILE
[Unit]
Description = Remote forwarding service for $SERVICE_NAME (${TARGET_HOST}:${REMOTE_PORT} <- localhost:${LOCAL_PORT})

[Service]
ExecStartPre = /bin/sleep 1
ExecStart = /bin/bash -l -c 'autossh -NR $REMOTE_PORT:localhost:$LOCAL_PORT $TARGET_HOST'
ExecStop = /bin/kill \${MAINPID}
Restart = always
Type = simple
StartLimitBurst = 0
User = $(whoami)
Group = $(whoami)

[Install]
WantedBy = multi-user.target
EOL

# systemdでサービスを有効化して開始
sudo systemctl enable $SERVICE_NAME
sudo systemctl restart $SERVICE_NAME

echo "Service $SERVICE_NAME has been created and started:"
echo "  Target host: $TARGET_HOST"
echo "  Remote port: $REMOTE_PORT (on $TARGET_HOST)"
echo "  Local port: $LOCAL_PORT"

