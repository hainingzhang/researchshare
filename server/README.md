# 服务器管理员操作指南

本指南适用于负责 Ubuntu 服务器和团队账号的管理员。客户端是 SFTP over SSH；不要将 Samba/NFS 服务端口暴露到公网。

## 0. 防止把自己锁在服务器外

改 SSH 或防火墙之前，确认云厂商网页控制台/串口救援通道可用。确认你有可用 SSH Key，并保留当前已登录会话；所有变更都应能从控制台恢复。

## 1. 安装并验证 SSH 服务

在 Ubuntu 服务器执行：

```sh
sudo apt update
sudo apt install -y openssh-server acl ufw
sudo systemctl enable --now ssh
sudo sshd -t
sudo systemctl status ssh --no-pager
sudo sshd -T | grep '^port '
sudo ss -lntp | grep sshd
```

记录实际 SSH 端口（常见为 TCP 22），并确认 SSH 服务确实监听该端口。

## 2. 配置云安全组和 UFW

先在云厂商网络防火墙/安全组入站规则放行实际 SSH TCP 端口。若条件允许，将来源限制为管理员及团队成员实际使用的出口 IP。

例如 SSH 端口为 22：

```sh
sudo ufw allow 22/tcp
sudo ufw status verbose
sudo ufw enable
sudo ufw status numbered
```

非 22 端口时，改为实际端口。启用前检查服务器其他必要业务端口及云安全组规则，避免中断业务。只开放需要的端口；共享文件访问复用 SSH 端口。

## 3. 管理员 SSH 加固（谨慎、可选）

从管理员电脑验证密钥登录成功，并从另一终端新开会话再次验证。确认云厂商控制台救援通道可用后，才考虑关闭密码认证或 root 远程登录。先检查配置语法，再 reload：

```sh
sudo sshd -t && sudo systemctl reload ssh
```

不要未经检查覆盖整份 SSH 配置，也不要在其他管理员仍依赖密码登录时禁用密码认证。

## 4. 初始化共享目录（仅首次运行）

在本仓库根目录执行：

```sh
sudo bash server/setup_research_share.sh
```

默认共享目录 `/home/ubuntu/data/research`，共享组 `research`。如需自定义：

```sh
sudo bash server/setup_research_share.sh /data/research research
```

初始化脚本会创建目录分类并递归调整现有共享文件的组和 ACL。仅在首次部署或明确修复权限时运行；处理大目录可能需要一些时间，先备份并确认路径。

## 5. 为每个成员开通账号及 SSH 公钥

成员分别运行 Mac 或 Windows 一次性配置脚本，提供生成的**公钥整行**。管理员绝不收集成员私钥。

在仓库根目录，对每位成员运行一次，例如：

```sh
sudo bash server/add_research_user.sh hzhang
```

按提示粘贴该成员的公钥。脚本会创建 Linux 个人账号（若不存在）、将公钥加入 `authorized_keys`、将账号加入 `research` 组，并检查共享目录访问。每位成员必须使用独立账号和密钥。

成员离队时应及时撤销其 SSH key/账号权限，并按团队流程完成文件交接。

## 6. 验收

- 成员 SSH 端口能从授权网络访问，且云安全组与 UFW 规则一致。
- 每个成员可通过个人 SSH Key 使用 SFTP。
- 成员能读写共享目录；不应依赖 777 权限。
- SSH/SFTP 以外的共享服务端口没有不必要的公网开放。
- `/home/ubuntu/data/research` 和 Gitea 数据纳入异地备份，并定期演练恢复。

Mac 步骤见 [macOS 使用指南](../macos/README.md)，Windows 步骤见 [Windows 使用指南](../windows/README.md)，综合流程见 [部署总指南](../DEPLOYMENT.md)。
