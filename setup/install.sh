#!/bin/bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y percona-toolkit graphviz unzip

ARCH=$(dpkg --print-architecture)  # amd64 / arm64
curl -fsSL -o /tmp/alp.zip "https://github.com/tkuchiki/alp/releases/latest/download/alp_linux_${ARCH}.zip"
sudo unzip -o /tmp/alp.zip -d /usr/local/bin

git config --global user.name  "isucon"
git config --global user.email "isucon@example.com"
