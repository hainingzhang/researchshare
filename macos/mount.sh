#!/usr/bin/env bash
# Start the foreground rclone NFS mount on macOS.
set -Eeuo pipefail

REMOTE_NAME="researchcloud"
MOUNT_POINT="$HOME/ResearchCloud"
APP_CONFIG_DIR="$HOME/.config/researchcloud"

# Finder/Automator may not inherit Homebrew's PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v rclone >/dev/null 2>&1 || {
  printf '找不到 rclone。请先运行 bash macos/setup.sh 完成一次性配置。\n' >&2
  exit 1
}

[[ -f "$APP_CONFIG_DIR/remote_path" ]] || {
  printf '尚未完成配置。请先运行 bash macos/setup.sh。\n' >&2
  exit 1
}
REMOTE_PATH="$(< "$APP_CONFIG_DIR/remote_path")"
[[ -n "$REMOTE_PATH" ]] || {
  printf '共享目录路径配置为空。请重新运行 bash macos/setup.sh。\n' >&2
  exit 1
}

mkdir -p "$MOUNT_POINT"
if mount | grep -Fq " on $MOUNT_POINT ("; then
  printf '共享盘已经挂载在 %s\n' "$MOUNT_POINT"
  open "$MOUNT_POINT"
  exit 0
fi

if [[ -n "$(find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  printf '挂载目录不是空目录，为避免覆盖本机文件，已停止：%s\n' "$MOUNT_POINT" >&2
  exit 1
fi

printf '正在挂载共享盘到 %s。挂载期间请保持此终端打开。\n' "$MOUNT_POINT"
printf 'Finder 打开方式：Command+Shift+G，然后输入 %s\n' "$MOUNT_POINT"
printf '完成使用并确认文件上传后，在此终端按 Ctrl+C 卸载。\n\n'

exec rclone nfsmount "$REMOTE_NAME:$REMOTE_PATH" "$MOUNT_POINT" \
  --vfs-cache-mode writes \
  --dir-cache-time 30s \
  --volname ResearchCloud
