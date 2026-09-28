#!/usr/bin/env bash
# One-time macOS setup for the team's SFTP/rclone research share.
set -Eeuo pipefail

REMOTE_NAME="researchcloud"
DEFAULT_REMOTE_PATH="/home/ubuntu/data/research"
DEFAULT_MOUNT_POINT="$HOME/ResearchCloud"
SSH_DIR="$HOME/.ssh"
PRIVATE_KEY="$SSH_DIR/researchcloud_ed25519"
PUBLIC_KEY="$PRIVATE_KEY.pub"
KNOWN_HOSTS="$SSH_DIR/known_hosts"
APP_CONFIG_DIR="$HOME/.config/researchcloud"

fail() {
  printf '错误：%s\n' "$1" >&2
  exit 1
}

prompt() {
  local label="$1" default_value="${2-}" answer
  if [[ -n "$default_value" ]]; then
    read -r -p "$label [$default_value]: " answer
    REPLY="${answer:-$default_value}"
  else
    read -r -p "$label: " REPLY
  fi
}

# Load Homebrew's standard locations because this script may be started from Finder.
if ! command -v brew >/dev/null 2>&1; then
  for brew_path in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$brew_path" ]]; then
      eval "$("$brew_path" shellenv)"
      break
    fi
  done
fi
command -v brew >/dev/null 2>&1 || fail "未找到 Homebrew。请先安装 Homebrew，再重新运行 bash macos/setup.sh。"

if ! command -v rclone >/dev/null 2>&1; then
  printf '正在安装 rclone…\n'
  brew install rclone
fi
command -v rclone >/dev/null 2>&1 || fail "rclone 安装失败。请检查 Homebrew 输出后重试。"

printf '\n研究共享盘 Mac 一次性配置\n'
printf '请向管理员确认服务器地址、你的个人 Linux 用户名；SSH 指纹出现时也要与管理员核对。\n\n'
prompt "服务器地址（IP 或域名）"
SERVER_HOST="$REPLY"
[[ -n "$SERVER_HOST" && "$SERVER_HOST" != *[[:space:]]* ]] || fail "服务器地址不能为空，也不能包含空格。"

prompt "你的个人 Linux 用户名"
SERVER_USER="$REPLY"
[[ "$SERVER_USER" =~ ^[a-zA-Z0-9._-]+$ ]] || fail "用户名格式不正确。"

prompt "SSH 端口" "22"
SERVER_PORT="$REPLY"
[[ "$SERVER_PORT" =~ ^[0-9]+$ ]] && (( SERVER_PORT > 0 && SERVER_PORT < 65536 )) || fail "端口必须是 1 到 65535 之间的数字。"

prompt "共享目录服务器路径" "$DEFAULT_REMOTE_PATH"
REMOTE_PATH="$REPLY"
[[ "$REMOTE_PATH" == /* ]] || fail "服务器路径必须以 / 开头。"

MOUNT_POINT="$DEFAULT_MOUNT_POINT"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
if [[ -e "$PRIVATE_KEY" || -e "$PUBLIC_KEY" ]]; then
  [[ -f "$PRIVATE_KEY" && -f "$PUBLIC_KEY" ]] || fail "密钥文件不完整：请检查 $PRIVATE_KEY 和对应的 .pub 文件。"
  printf '将使用已有的专用密钥：%s\n' "$PRIVATE_KEY"
else
  printf '\n正在生成本机专用 SSH 密钥（不设置口令，以便挂载时无需反复输入）…\n'
  ssh-keygen -q -t ed25519 -N "" -f "$PRIVATE_KEY" -C "$SERVER_USER@$SERVER_HOST"
fi
chmod 600 "$PRIVATE_KEY"
chmod 644 "$PUBLIC_KEY"

printf '\n已将公钥复制到剪贴板。请把下面这一整行公钥发给服务器管理员；不要发送私钥。\n\n'
cat "$PUBLIC_KEY"
printf '\n'
if command -v pbcopy >/dev/null 2>&1; then
  pbcopy < "$PUBLIC_KEY"
fi
read -r -p "管理员确认已把公钥添加到你的账号后，按 Enter 继续；输入 q 退出： " answer
[[ "$answer" != "q" && "$answer" != "Q" ]] || exit 0

printf '\n现在将通过 SSH 首次连接。若出现服务器指纹确认提示，请先与管理员核对指纹，再输入 yes。\n'
SSH_STATUS=0
ssh \
  -i "$PRIVATE_KEY" \
  -p "$SERVER_PORT" \
  -o IdentitiesOnly=yes \
  -o PreferredAuthentications=publickey \
  -o PasswordAuthentication=no \
  -o StrictHostKeyChecking=ask \
  "$SERVER_USER@$SERVER_HOST" exit || SSH_STATUS=$?

mkdir -p "$APP_CONFIG_DIR" "$MOUNT_POINT"
chmod 700 "$APP_CONFIG_DIR"
printf '%s\n' "$REMOTE_PATH" > "$APP_CONFIG_DIR/remote_path"
chmod 600 "$APP_CONFIG_DIR/remote_path"

if rclone listremotes | grep -Fxq "$REMOTE_NAME:"; then
  printf '\n更新已有的 rclone 连接配置…\n'
  rclone config update "$REMOTE_NAME" \
    host "$SERVER_HOST" \
    user "$SERVER_USER" \
    port "$SERVER_PORT" \
    key_file "$PRIVATE_KEY" \
    known_hosts_file "$KNOWN_HOSTS"
else
  printf '\n创建 rclone 连接配置…\n'
  rclone config create "$REMOTE_NAME" sftp \
    host "$SERVER_HOST" \
    user "$SERVER_USER" \
    port "$SERVER_PORT" \
    key_file "$PRIVATE_KEY" \
    known_hosts_file "$KNOWN_HOSTS"
fi

printf '\n正在测试 SFTP 连接和共享目录权限…\n'
if ! rclone lsd "$REMOTE_NAME:$REMOTE_PATH"; then
  if [[ "$SSH_STATUS" -ne 0 ]]; then
    printf '\nSSH shell 登录未成功；若服务器限制 shell、只允许 SFTP，可忽略此项，以上 rclone 测试才是共享盘验证。\n' >&2
  fi
  fail "连接测试失败。请确认管理员已添加公钥、服务器地址/用户名/路径正确，并已核对主机指纹。"
fi

printf '\n配置完成。共享盘目录：%s\n' "$MOUNT_POINT"
printf '以后运行 bash macos/mount.sh 即可挂载；保持打开的终端窗口，按 Ctrl+C 卸载。\n'
printf 'Finder 中按 Command+Shift+G，输入 %s 即可打开。\n' "$MOUNT_POINT"
