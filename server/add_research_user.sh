#!/usr/bin/env bash
# Create or update one Ubuntu user's SSH access to the research share.
set -Eeuo pipefail

SHARE_DIR="${RESEARCH_SHARE_DIR:-/home/ubuntu/data/research}"
SHARE_GROUP="${RESEARCH_SHARE_GROUP:-research}"
USERNAME="${1:-}"

fail() {
  printf '错误：%s\n' "$1" >&2
  exit 1
}

[[ "$EUID" -eq 0 ]] || fail "请用 sudo 运行：sudo bash server/add_research_user.sh 用户名"
[[ "$USERNAME" =~ ^[a-zA-Z][a-zA-Z0-9._-]*$ ]] || fail "用户名格式不正确。"
getent group "$SHARE_GROUP" >/dev/null || fail "共享组 $SHARE_GROUP 不存在；请先运行 sudo bash server/setup_research_share.sh。"
[[ -d "$SHARE_DIR" ]] || fail "共享目录不存在：$SHARE_DIR；请先运行 sudo bash server/setup_research_share.sh。"
command -v ssh-keygen >/dev/null 2>&1 || fail "未找到 ssh-keygen。"

if id "$USERNAME" >/dev/null 2>&1; then
  printf '账号 %s 已存在，将保留账号本身并补齐共享组和 SSH Key。\n' "$USERNAME"
else
  useradd --create-home --shell /bin/bash "$USERNAME"
  passwd --lock "$USERNAME" >/dev/null
  printf '已创建 Linux 用户：%s（密码登录已锁定，使用 SSH Key 登录）。\n' "$USERNAME"
fi

USER_ENTRY="$(getent passwd "$USERNAME")"
IFS=: read -r _ _ _ _ _ USER_HOME _ <<< "$USER_ENTRY"
[[ -n "$USER_HOME" && -d "$USER_HOME" ]] || fail "无法确认用户 $USERNAME 的主目录。"
USER_GROUP="$(id -gn "$USERNAME")"

read -r -p "请粘贴 $USERNAME 的整行 SSH 公钥：" PUBLIC_KEY
[[ -n "$PUBLIC_KEY" && "$PUBLIC_KEY" != *$'\n'* && "$PUBLIC_KEY" != *$'\r'* ]] || fail "公钥必须是单行文本。"

TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT
printf '%s\n' "$PUBLIC_KEY" > "$TMP_KEY"
ssh-keygen -l -f "$TMP_KEY" >/dev/null 2>&1 || fail "公钥格式无效；请确认粘贴的是 .pub 公钥，而不是私钥。"

SSH_DIR="$USER_HOME/.ssh"
AUTHORIZED_KEYS="$SSH_DIR/authorized_keys"
install -d -m 700 -o "$USERNAME" -g "$USER_GROUP" "$SSH_DIR"
touch "$AUTHORIZED_KEYS"
if ! grep -Fqx -- "$PUBLIC_KEY" "$AUTHORIZED_KEYS"; then
  printf '%s\n' "$PUBLIC_KEY" >> "$AUTHORIZED_KEYS"
fi
chown "$USERNAME:$USER_GROUP" "$AUTHORIZED_KEYS"
chmod 600 "$AUTHORIZED_KEYS"

usermod -aG "$SHARE_GROUP" "$USERNAME"

# Verify effective access using a fresh process, which loads the updated groups.
if ! runuser -u "$USERNAME" -- test -r "$SHARE_DIR" || ! runuser -u "$USERNAME" -- test -w "$SHARE_DIR" || ! runuser -u "$USERNAME" -- test -x "$SHARE_DIR"; then
  fail "账号已创建并加入组，但共享目录读写/遍历权限检查失败。请管理员检查父目录 ACL 和共享目录 ACL。"
fi

printf '\n用户配置完成：%s\n' "$USERNAME"
printf '主目录：%s\n共享目录：%s\n共享组：%s\n' "$USER_HOME" "$SHARE_DIR" "$SHARE_GROUP"
printf '请让用户从 Mac/Windows 使用其对应私钥测试 SFTP；组权限已在新进程中验证。\n'
