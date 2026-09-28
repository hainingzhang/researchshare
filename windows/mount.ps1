# Start the foreground rclone NFS mount on Windows.
$ErrorActionPreference = 'Stop'
$RemoteName = 'researchcloud'
$AppConfigDirectory = Join-Path $env:LOCALAPPDATA 'ResearchCloud'
$RemotePathFile = Join-Path $AppConfigDirectory 'remote_path'
$DriveFile = Join-Path $AppConfigDirectory 'drive_letter'

$RcloneCommand = Get-Command rclone.exe -ErrorAction SilentlyContinue
if (-not $RcloneCommand) {
    $Candidates = @(
        (Join-Path $env:ProgramFiles 'rclone\rclone.exe'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\rclone.exe')
    )
    foreach ($Candidate in $Candidates) {
        if (Test-Path $Candidate) { $RcloneCommand = Get-Item $Candidate; break }
    }
}
if (-not $RcloneCommand) {
    Write-Error '找不到 rclone.exe。请先运行 powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1。'
    exit 1
}
if (-not (Test-Path $RemotePathFile) -or -not (Test-Path $DriveFile)) {
    Write-Error '尚未完成一次性配置。请先运行 powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1。'
    exit 1
}

$RemotePath = (Get-Content -Raw $RemotePathFile -Encoding UTF8).Trim()
$DriveLetter = (Get-Content -Raw $DriveFile -Encoding ASCII).Trim().ToUpperInvariant()
if (-not $RemotePath.StartsWith('/') -or $DriveLetter -notmatch '^[D-Z]:$') {
    Write-Error '本机配置无效。请重新运行 windows\setup.ps1。'
    exit 1
}

$ExistingDrive = Get-PSDrive -Name $DriveLetter.TrimEnd(':') -ErrorAction SilentlyContinue
if ($ExistingDrive) {
    Write-Error "盘符 $DriveLetter 已在使用。请修改 $DriveFile 为未占用盘符后重试。"
    exit 1
}

$RclonePath = $RcloneCommand.Source
if ([string]::IsNullOrWhiteSpace($RclonePath)) { $RclonePath = $RcloneCommand.FullName }
Write-Host "正在挂载到 $DriveLetter。请保持此窗口打开；完成使用并确认上传后按 Ctrl+C 卸载。"
Write-Host '打开文件资源管理器即可访问该盘；此挂载不是离线同步。'
& $RclonePath nfsmount "${RemoteName}:$RemotePath" $DriveLetter `
    --vfs-cache-mode writes `
    --dir-cache-time 30s `
    --volname ResearchCloud
exit $LASTEXITCODE
