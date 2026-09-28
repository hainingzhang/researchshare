# Windows 成员使用指南

按此指南设置 Windows 电脑，通过文件资源管理器访问团队共享盘。服务器管理员应先创建你的个人 Linux 账号，并准备服务器地址、SSH 端口及共享路径。

## 一次性配置

### 1. 准备电脑和仓库

使用 Windows 10/11，确认已安装 Microsoft Store 的“应用安装程序 (App Installer)”并可使用 winget。下载或克隆本方案仓库到本机。

### 2. 运行配置脚本

在仓库目录打开 PowerShell，运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

根据提示输入：

- 服务器地址（IP 或域名）
- 你的个人 Linux 用户名
- SSH 端口（默认 `22`）
- 共享目录路径（默认 `/home/ubuntu/data/research`）
- 本机可用盘符（默认 `R:`）

脚本会通过 winget 安装 rclone 和 WinFsp，并检查 Windows OpenSSH Client；系统可能要求本机管理员批准安装。脚本还会生成本机 SSH 密钥并复制公钥到剪贴板。

把终端显示的、以 `ssh-ed25519` 开头的**公钥整行**通过团队认可的渠道交给服务器管理员。不要发送没有 `.pub` 后缀的私钥文件。管理员确认登记后，回到 PowerShell 按 Enter 继续。

首次 SSH 连接时，先和管理员核对终端显示的服务器指纹，再确认连接。配置脚本会测试 SFTP 是否能列出共享目录。

## 日常挂载与文件资源管理器

在仓库目录打开 PowerShell，运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\mount.ps1
```

保持 PowerShell 窗口打开，然后在文件资源管理器打开 `R:`（如果配置时选了其他盘符，则打开对应盘符）。使用结束并确认上传完成后，在挂载窗口按 **Ctrl+C** 卸载。

## 重要说明

- rclone 挂载是远程访问，不是完整离线同步；断网时远端文件可能不可用。
- 文件保存后等待上传完成再卸载或关机。
- 其他成员的更改可能受目录缓存影响，稍后才出现在资源管理器中（当前脚本使用 30 秒目录缓存）。
- 避免多人同时编辑同一份 Office 文件，以免互相覆盖。
- Git 研究项目保存在本机磁盘，不放在共享盘中。

若盘符已占用，重新运行一次配置脚本并选择空闲盘符。遇到 SSH 指纹错误时停止操作并联系管理员核对；不要关闭主机密钥检查。

服务器管理员步骤见 [服务器指南](../server/README.md)，Mac 成员步骤见 [Mac 指南](../macos/README.md)，综合流程见 [部署总指南](../DEPLOYMENT.md)。
