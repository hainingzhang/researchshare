# 云端共享盘部署与成员使用指南

本文按三个角色分工：**服务器管理员一次性准备服务器**、**管理员逐个开通成员**、**Mac/Windows 成员运行客户端脚本**。这些脚本是本仓库的辅助工具；管理员仍需确认服务器地址、网络策略、账号授权和备份。

## 一、服务器管理员：准备 Ubuntu 服务器

### 1. 先确认有恢复通道

开始改 SSH 或防火墙前，确认管理员仍能通过云厂商网页控制台/串口控制台登录服务器，并了解如何在控制台恢复网络规则。SSH、防火墙配置错误可能中断远程管理。

### 2. 安装并启动 SSH 与 ACL 工具

在 Ubuntu 服务器上执行：

```sh
sudo apt update
sudo apt install -y openssh-server acl ufw
sudo systemctl enable --now ssh
sudo sshd -t
sudo systemctl status ssh --no-pager
```

确认 SSH 正在监听的端口（常见为 22）：

```sh
sudo sshd -T | grep '^port '
sudo ss -lntp | grep sshd
```

如果 `sshd_config` 设置了多个端口，以服务器实际监听端口为准。

### 3. 配置云防火墙/安全组和 Ubuntu UFW

先在云厂商控制台的入站规则中放行实际 SSH TCP 端口。若可限制来源，优先限制为管理员及团队实际使用的公网出口 IP；在确认之前不要删除现有管理规则。

例如实际 SSH 端口为 `22` 时，在 Ubuntu 上先允许 SSH，再启用 UFW：

```sh
sudo ufw allow 22/tcp
sudo ufw status verbose
sudo ufw enable
sudo ufw status numbered
```

如果 SSH 使用其他端口，将 `22` 换成真实端口。启用前确认现有服务（例如 HTTPS）也有对应的云安全组和 UFW 放行规则，避免切断业务。**不要为 rclone/SFTP 开 Samba、NFS 公网端口**；成员通过同一个 SSH 端口访问 SFTP。

### 4. 验证管理员 SSH Key 后，再考虑加固

先从管理员自己的电脑确认 SSH Key 登录成功，同时保留当前服务器会话，并从另一终端再开一个 SSH 会话测试。确认云厂商控制台可用后，管理员可以评估禁用密码认证及 root 远程登录。不要在所有管理员都能用密钥登录前禁用密码。

修改 SSH 配置后先验证语法，再 reload：

```sh
sudo sshd -t && sudo systemctl reload ssh
```

加固策略需结合服务器已有账号、自动化任务和云镜像的 SSH 配置审查；不要直接覆盖整份 `/etc/ssh/sshd_config`。

### 5. 初始化共享区（只需运行一次）

把仓库克隆到服务器或以其他可信方式放入仓库中的 `server/` 目录，然后在仓库根目录执行：

```sh
sudo bash server/setup_research_share.sh
```

默认会建立 `/home/ubuntu/data/research`、`research` 组、标准子目录和 ACL。自定义目录时：

```sh
sudo bash server/setup_research_share.sh /data/research research
```

该脚本会递归修正目录内容的组和 ACL；只在首次初始化或管理员有意修复权限时运行。运行前应备份重要数据，并确认目录路径正确。

### 6. 逐个创建成员账号和登记公钥

Mac/Windows 成员运行各自的 `setup` 客户端脚本后，会生成并展示自己的 `.pub` 公钥。成员通过组织认可的安全渠道将**公钥整行**交给管理员；不通过聊天机器人或普通邮件转交私钥，管理员也绝不收集私钥。

管理员对每位成员运行一次，例如：

```sh
sudo bash server/add_research_user.sh hzhang
```

按提示粘贴该成员自己的公钥。脚本会创建 Linux 个人账号（如果不存在）、写入 `authorized_keys`、加入 `research` 组，并测试共享目录访问。每个人一把密钥、一个账号；成员离开团队时应移除账号/密钥并审核其文件交接。

## 二、Mac 成员：一次配置、日常使用

### 一次性配置

1. 在 Mac 安装 Git，下载/克隆本方案仓库。
2. 打开终端并进入仓库目录，运行：

   ```sh
   bash macos/setup.sh
   ```

3. 输入管理员提供的服务器地址和你的 Linux 用户名。SSH 端口默认 `22`，共享路径默认 `/home/ubuntu/data/research`。
4. 把脚本生成并显示的公钥发给管理员。管理员确认添加后，回到终端按 Enter。
5. 首次连接时，与管理员核对服务器指纹后再确认。成功后脚本会测试共享目录。

脚本自动安装 rclone（需要 Mac 已安装 Homebrew）、生成 SSH Key 并配置 SFTP。它不会在服务器上创建账号，也不会替代管理员登记公钥。

### 日常挂载/卸载

在仓库目录运行：

```sh
bash macos/mount.sh
```

保持终端打开，在 Finder 按 **Command+Shift+G**，输入 `~/ResearchCloud`。用完并确认上传完成后，在挂载终端按 **Ctrl+C**。若网络断开，远端文件可能无法访问；挂载不是离线同步。不要多人同时编辑同一份 Office 文件。

## 三、Windows 成员：一次配置、日常使用

### 一次性配置

1. 使用 Windows 10/11，安装并更新“应用安装程序 (App Installer)”以获得 `winget`；下载/克隆本方案仓库。
2. 在仓库目录打开 PowerShell，运行：

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
   ```

3. 输入服务器地址、个人 Linux 用户名；按需更改 SSH 端口、服务器共享路径和盘符（默认 `22`、`/home/ubuntu/data/research`、`R:`）。
4. 脚本通过 winget 安装 rclone 与 WinFsp，并检查 Windows OpenSSH Client。系统可能要求本机管理员批准安装。
5. 把脚本显示的 SSH 公钥交给管理员；管理员确认登记后按 Enter 继续。首次连接时与管理员核对服务器指纹。

### 日常挂载/卸载

在仓库目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\mount.ps1
```

挂载后在文件资源管理器打开 `R:`（或配置时选定的盘符）。保持 PowerShell 窗口打开；确认上传完成后按 **Ctrl+C** 卸载。

## 故障排查和安全约定

- `Permission denied (publickey)`：确认管理员登记的是该电脑对应的公钥，用户名正确，且 SSH 端口可达。
- 主机密钥/指纹报错：停止连接并找管理员核对指纹；不要通过关闭校验绕过。
- 目录不存在或权限拒绝：确认服务器共享路径、父目录遍历权限和 `research` 组 ACL。
- 盘符已占用：在 Windows 一次性设置时选择未使用的盘符。
- 文件列表有延迟：脚本设置了 30 秒目录缓存；回到上层再进入或等待缓存刷新。不是实时同步。
- 文件上传后才断开挂载；rclone 的写缓存不是完整离线副本。大型或重要文件传输后，应由用户或管理员确认远端文件存在。
- Git 工作目录保存在本地磁盘，不放进 rclone 挂载盘；共享盘和 Gitea 都要有异地备份及恢复测试。
