#!/usr/bin/env bash
# Run once on Ubuntu as root to create the shared directory and group ACLs.
set -Eeuo pipefail

SHARE_DIR="${1:-${RESEARCH_SHARE_DIR:-/home/ubuntu/data/research}}"
SHARE_GROUP="${2:-${RESEARCH_SHARE_GROUP:-research}}"

fail() {
  printf '错误：%s\n' "$1" >&2
  exit 1
}

[[ "$EUID" -eq 0 ]] || fail "请用 sudo 运行：sudo bash server/setup_research_share.sh"
[[ "$SHARE_DIR" == /* ]] || fail "共享目录必须是绝对路径。"
[[ "$SHARE_GROUP" =~ ^[a-zA-Z0-9_-]+$ ]] || fail "共享组名称格式不正确。"

if ! command -v setfacl >/dev/null 2>&1; then
  command -v apt-get >/dev/null 2>&1 || fail "未找到 setfacl。请安装 acl 软件包后重试。"
  apt-get update
  apt-get install -y acl
fi

getent group "$SHARE_GROUP" >/dev/null || groupadd "$SHARE_GROUP"
mkdir -p "$SHARE_DIR"

# The current deployment keeps the share under /home/ubuntu. Give group members
# traversal rights on parent directories without granting directory listings.
for parent in /home/ubuntu /home/ubuntu/data; do
  if [[ "$SHARE_DIR" == "$parent"/* && -d "$parent" ]]; then
    setfacl -m "g:$SHARE_GROUP:--x" "$parent"
  fi
done

# Create the standard team folders, then grant access to existing and future files.
mkdir -p \
  "$SHARE_DIR/00_Papers" \
  "$SHARE_DIR/01_Datasets" \
  "$SHARE_DIR/02_Office" \
  "$SHARE_DIR/03_Shared_Results" \
  "$SHARE_DIR/99_Temp"
chgrp -R "$SHARE_GROUP" "$SHARE_DIR"
setfacl -R -m "g:$SHARE_GROUP:rwX" "$SHARE_DIR"
find "$SHARE_DIR" -type d -exec chmod g+s {} +
find "$SHARE_DIR" -type d -exec setfacl -m "d:g:$SHARE_GROUP:rwx" {} +

printf '共享目录初始化完成。\n目录：%s\n共享组：%s\n' "$SHARE_DIR" "$SHARE_GROUP"
printf '现在可为每位成员运行：sudo bash server/add_research_user.sh 用户名\n'
