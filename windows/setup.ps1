# One-time Windows setup for the team's SFTP/rclone research share.
$ErrorActionPreference = 'Stop'

$RemoteName = 'researchcloud'
$DefaultRemotePath = '/home/ubuntu/data/research'
$DefaultDrive = 'R:'
$KeyDirectory = Join-Path $HOME '.ssh'
$PrivateKey = Join-Path $KeyDirectory 'researchcloud_ed25519'
$PublicKey = "$PrivateKey.pub"
$KnownHosts = Join-Path $KeyDirectory 'known_hosts'
$AppConfigDirectory = Join-Path $env:LOCALAPPDATA 'ResearchCloud'

function Stop-WithMessage([string]$Message) {
    Write-Error "错误：$Message"
    exit 1
}

function Read-Setting([string]$Prompt, [string]$Default = '') {
    if ([string]::IsNullOrWhiteSpace($Default)) {
        return (Read-Host $Prompt).Trim()
    }
    $Value = (Read-Host "$Prompt [$Default]").Trim()
    if ([string]::IsNullOrWhiteSpace($Value)) { return $Default }
    return $Value
}

function Refresh-Path {
    $MachinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $UserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$MachinePath;$UserPath"
}

Write-Host ''
Write-Host '研究共享盘 Windows 一次性配置' -ForegroundColor Cyan
Write-Host '请先向管理员确认服务器地址、你的个人 Linux 用户名及服务器指纹。'

$Winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $Winget) {
    Stop-WithMessage '未找到 winget。请使用受支持的 Windows 10/11 并安装“应用安装程序 (App Installer)”，然后重新运行本脚本。'
}

$ServerHost = Read-Setting '服务器地址（IP 或域名）'
if ([string]::IsNullOrWhiteSpace($ServerHost) -or $ServerHost -match '\s') {
    Stop-WithMessage '服务器地址不能为空，也不能包含空格。'
}
$ServerUser = Read-Setting '你的个人 Linux 用户名'
if ($ServerUser -notmatch '^[a-zA-Z][a-zA-Z0-9._-]*$') {
    Stop-WithMessage '用户名格式不正确。'
}
$PortText = Read-Setting 'SSH 端口' '22'
$ServerPort = 0
if (-not [int]::TryParse($PortText, [ref]$ServerPort) -or $ServerPort -lt 1 -or $ServerPort -gt 65535) {
    Stop-WithMessage '端口必须是 1 到 65535 之间的数字。'
}
$RemotePath = Read-Setting '共享目录服务器路径' $DefaultRemotePath
if (-not $RemotePath.StartsWith('/')) { Stop-WithMessage '服务器路径必须以 / 开头。' }
$DriveLetter = (Read-Setting '共享盘盘符' $DefaultDrive).ToUpperInvariant()
if ($DriveLetter -notmatch '^[D-Z]:$') { Stop-WithMessage '请输入未使用的盘符，例如 R:（可选 D: 到 Z:）。' }

Write-Host "`n正在安装/检查 rclone…"
& $Winget.Source install --id Rclone.Rclone --exact --accept-package-agreements --accept-source-agreements --silent
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage 'rclone 安装失败。请查看 winget 输出；也可从 https://rclone.org/downloads/ 安装后重新运行。'
}

$WinFspInstalled = $false
$UninstallRoots = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
foreach ($Root in $UninstallRoots) {
    if (Get-ItemProperty $Root -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -match '^WinFsp' }) {
        $WinFspInstalled = $true
        break
    }
}
if (-not $WinFspInstalled) {
    Write-Host '正在安装 WinFsp（rclone Windows 挂载所需组件）…'
    & $Winget.Source install --id WinFsp.WinFsp --exact --accept-package-agreements --accept-source-agreements --silent
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage 'WinFsp 安装失败。请由本机管理员安装 WinFsp，再重新运行本脚本。'
    }
}

Refresh-Path
$RcloneCommand = Get-Command rclone.exe -ErrorAction SilentlyContinue
if (-not $RcloneCommand) {
    $RcloneCandidates = @(
        (Join-Path $env:ProgramFiles 'rclone\rclone.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\rclone.exe')
    )
    foreach ($Candidate in $RcloneCandidates) {
        if (Test-Path $Candidate) { $RcloneCommand = Get-Item $Candidate; break }
    }
}
if (-not $RcloneCommand) {
    Stop-WithMessage '已安装 rclone，但当前终端找不到 rclone.exe。请关闭并重新打开 PowerShell，再运行本脚本。'
}
$RclonePath = $RcloneCommand.Source
if ([string]::IsNullOrWhiteSpace($RclonePath)) { $RclonePath = $RcloneCommand.FullName }

$SshCommand = Get-Command ssh.exe -ErrorAction SilentlyContinue
$KeygenCommand = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
if (-not $SshCommand -or -not $KeygenCommand) {
    try {
        $Capability = Get-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' -ErrorAction Stop
        if ($Capability.State -ne 'Installed') {
            Write-Host '正在启用 Windows OpenSSH Client（可能需要管理员权限）…'
            Add-WindowsCapability -Online -Name 'OpenSSH.Client~~~~0.0.1.0' | Out-Null
        }
    }
    catch {
        Stop-WithMessage '无法自动启用 OpenSSH Client。请由 Windows 管理员在“设置 > 系统 > 可选功能”安装 OpenSSH Client，然后重新运行本脚本。'
    }
    Refresh-Path
    $SshCommand = Get-Command ssh.exe -ErrorAction SilentlyContinue
    $KeygenCommand = Get-Command ssh-keygen.exe -ErrorAction SilentlyContinue
}
if (-not $SshCommand -or -not $KeygenCommand) {
    Stop-WithMessage '找不到 ssh.exe / ssh-keygen.exe。请安装 Windows OpenSSH Client 后重试。'
}

New-Item -ItemType Directory -Force -Path $KeyDirectory | Out-Null
if ((Test-Path $PrivateKey) -or (Test-Path $PublicKey)) {
    if (-not (Test-Path $PrivateKey) -or -not (Test-Path $PublicKey)) {
        Stop-WithMessage "密钥文件不完整；请检查 $PrivateKey 及其 .pub 文件。"
    }
    Write-Host "将使用已有的专用密钥：$PrivateKey"
}
else {
    Write-Host '正在生成本机专用 SSH 密钥（无口令，供挂载脚本免交互使用）…'
    & $KeygenCommand.Source -q -t ed25519 -N '' -f $PrivateKey -C "$ServerUser@$ServerHost"
    if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'SSH 密钥生成失败。' }
}

$PublicKeyText = (Get-Content -Raw $PublicKey).Trim()
if ([string]::IsNullOrWhiteSpace($PublicKeyText) -or $PublicKeyText -notmatch '^ssh-ed25519\s+') {
    Stop-WithMessage '公钥文件格式异常；请确认 .pub 文件有效。'
}
try { Set-Clipboard -Value $PublicKeyText } catch { }
Write-Host "`nSSH 公钥已复制到剪贴板。请把下面整行公钥发给管理员添加到你的账号：" -ForegroundColor Yellow
Write-Host $PublicKeyText
Write-Host '只发送公钥，不要发送没有 .pub 后缀的私钥文件。'
$Continue = Read-Host '管理员确认已添加公钥后按 Enter 继续；输入 q 退出'
if ($Continue -match '^[qQ]$') { exit 0 }

Write-Host "`n正在首次连接 SSH。请先与管理员核对显示的服务器指纹；确认无误后输入 yes。" -ForegroundColor Yellow
$SshArgs = @(
    '-i', $PrivateKey,
    '-p', "$ServerPort",
    '-o', 'IdentitiesOnly=yes',
    '-o', 'PreferredAuthentications=publickey',
    '-o', 'PasswordAuthentication=no',
    '-o', 'StrictHostKeyChecking=ask',
    "$ServerUser@$ServerHost",
    'exit'
)
& $SshCommand.Source @SshArgs
# Some SFTP-only accounts reject shell sessions. The rclone SFTP test below is authoritative.

New-Item -ItemType Directory -Force -Path $AppConfigDirectory | Out-Null
Set-Content -Path (Join-Path $AppConfigDirectory 'remote_path') -Value $RemotePath -Encoding UTF8

$ExistingRemotes = & $RclonePath listremotes
if ($LASTEXITCODE -ne 0) { Stop-WithMessage '无法读取 rclone 配置。' }
$RcloneOptions = @(
    "host=$ServerHost",
    "user=$ServerUser",
    "port=$ServerPort",
    "key_file=$PrivateKey",
    "known_hosts_file=$KnownHosts"
)
if ($ExistingRemotes -contains "${RemoteName}:") {
    Write-Host '正在更新已有的 rclone 连接配置…'
    & $RclonePath config update $RemoteName @RcloneOptions
}
else {
    Write-Host '正在创建 rclone SFTP 连接配置…'
    & $RclonePath config create $RemoteName sftp @RcloneOptions
}
if ($LASTEXITCODE -ne 0) { Stop-WithMessage 'rclone SFTP 配置失败。' }

Write-Host "`n正在测试连接和共享目录权限…"
& $RclonePath lsd "${RemoteName}:$RemotePath"
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage '连接测试失败。请确认管理员已添加公钥、共享目录路径和权限正确，并已核对服务器指纹。'
}

Set-Content -Path (Join-Path $AppConfigDirectory 'drive_letter') -Value $DriveLetter -Encoding ASCII
Write-Host "`n配置完成。共享盘将挂载为 $DriveLetter"
Write-Host '以后在本目录运行：powershell -ExecutionPolicy Bypass -File .\windows\mount.ps1'
