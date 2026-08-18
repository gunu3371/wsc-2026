#!/bin/bash
set -eux
dnf install -y python3-pip
mkdir -p /opt/bigbae
echo '${app_b64}' | base64 -d > /opt/bigbae/app.py
python3 -m venv /opt/bigbae/venv
/opt/bigbae/venv/bin/pip install --no-cache-dir flask boto3
cat >/etc/systemd/system/bigbae.service <<'EOF'
[Unit]
After=network-online.target
[Service]
Environment=AWS_REGION=ap-southeast-1
Environment=TABLE_NAME=bigbae-nosql-reservation-table
ExecStart=/opt/bigbae/venv/bin/python /opt/bigbae/app.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now bigbae
