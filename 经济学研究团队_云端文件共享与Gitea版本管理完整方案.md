# 经济学研究团队共享文件与版本管理方案

## 1. 目标

本方案面向以经济学研究人员为主的团队，成员使用 macOS 和 Windows，并希望继续在本地使用 WorkBuddy 进行论文阅读、研究计划修改、数据分析和研究文件操作。

核心目标：

- 论文、数据、Word、Excel、PPT 等文件统一存放在云主机；
- 团队成员可以像访问本地文件一样访问云端共享文件；
- 不要求每台电脑完整同步全部论文和数据；
- 研究计划、Markdown、代码、Prompt 等需要版本追踪的内容使用 Git 管理；
- 团队成员不必熟练掌握 Git 命令；
- 提供类似 GitHub 的 Web 页面，用于查看 README、研究计划、版本、作者、时间和修改差异；
- WorkBuddy 保持运行在本地电脑，不要求云主机安装图形界面；
- 整体尽量采用免费、开源、轻量的软件。

---

## 2. 推荐架构

```text
                              云主机
┌──────────────────────────────────────────────────────────┐
│                                                          │
│  A. 共享文件区                                           │
│                                                          │
│  /data/research/                                         │
│  ├── 00_Papers/          论文 PDF                        │
│  ├── 01_Datasets/        原始数据、处理后数据            │
│  ├── 02_Office/          Word / Excel / PPT              │
│  ├── 03_Shared_Results/  图表、结果、导出文件            │
│  └── 99_Temp/            临时交换区                      │
│                                                          │
│       ↑                                                  │
│       │ SFTP / SSH                                       │
│       │                                                  │
│     rclone mount                                         │
│                                                          │
│  B. 研究项目版本管理区                                   │
│                                                          │
│  Gitea                                                   │
│  ├── GEO                                                 │
│  ├── AI-Agents                                           │
│  ├── Open-Weights                                        │
│  └── Other-Projects                                      │
│                                                          │
│  每个项目包含：                                          │
│  README.md                                               │
│  research_plan.md                                        │
│  literature_review.md                                    │
│  hypotheses.md                                           │
│  code/                                                   │
│  prompts/                                                │
│  tasks/                                                  │
│  results/                                                │
│                                                          │
└──────────────────────────────────────────────────────────┘
                    │                     │
                    │                     │
              rclone / SFTP             Git / HTTPS / SSH
                    │                     │
          ┌─────────┴─────────┐   ┌───────┴─────────┐
          │                   │   │                 │
       macOS               Windows              Browser
          │                   │                   │
       Finder            File Explorer          Gitea
          │                   │                   │
       WorkBuddy          WorkBuddy          查看项目与历史
```

整套方案可以理解为三个入口：

```text
Finder / File Explorer
= 团队共享文件库

Gitea
= 项目主页 + README + 研究计划 + 版本历史

WorkBuddy
= AI 研究助手 + 文件操作 + Git 操作代理
```

---

# 3. 为什么采用“两套存储”

不建议把所有文件都放入 Git。

研究团队通常同时存在两类文件。

## 3.1 共享文件

例如：

- PDF 论文；
- Word；
- Excel；
- PowerPoint；
- 原始数据；
- 大型 CSV；
- Stata 数据；
- 图片；
- 视频；
- 其他二进制文件。

这些文件的主要需求是：

> 大家能够方便地上传、下载、打开和共享。

因此放入：

```text
/data/research/
```

通过：

```text
SFTP + rclone mount
```

提供给团队。

---

## 3.2 需要版本管理的研究文件

例如：

- `README.md`
- `research_plan.md`
- `literature_review.md`
- `hypotheses.md`
- Python / R / Stata 代码
- Prompt
- Agent task
- YAML / JSON
- BibTeX
- 研究备忘录
- 文本形式的分析结果

这些文件的主要需求是：

> 知道谁修改了、什么时候修改、修改了什么，以及能够恢复旧版本。

因此放在 Gitea 的 Git Repository 中。

---

# 4. 云主机部署

## 4.1 基础软件

推荐云主机使用 Ubuntu。

至少需要：

```text
OpenSSH Server
Git
Docker
Docker Compose
rclone 不需要安装在云主机
```

其中：

- OpenSSH / SFTP：负责共享文件访问；
- Git：供 Gitea 和 Git Repository 使用；
- Docker：运行 Gitea。

云主机不需要桌面环境。

---

# 5. 共享文件目录设计

建议统一使用：

```text
/data/research/
```

目录示例：

```text
/data/research/
├── 00_Papers/
│   ├── GEO/
│   ├── AI_Agents/
│   ├── Industrial_Economics/
│   └── General/
│
├── 01_Datasets/
│   ├── GEO/
│   ├── Open_Weights/
│   └── Common/
│
├── 02_Office/
│   ├── Proposals/
│   ├── Presentations/
│   └── Reports/
│
├── 03_Shared_Results/
│   ├── Figures/
│   ├── Tables/
│   └── Exports/
│
└── 99_Temp/
```

这样做的好处是：

- Finder 和 File Explorer 中结构清楚；
- WorkBuddy 容易理解目录；
- 项目之间不容易混乱；
- 后续备份简单。

---

# 6. 团队用户和权限

建议每个成员拥有独立的 Linux 用户。

例如：

```text
henry
alice
bob
```

创建统一研究组：

```bash
sudo groupadd research
```

把成员加入：

```bash
sudo usermod -aG research henry
sudo usermod -aG research alice
sudo usermod -aG research bob
```

共享目录：

```bash
sudo mkdir -p /data/research
sudo chgrp -R research /data/research
sudo chmod -R 2775 /data/research
```

推荐使用 SSH Key 登录，尽量不要长期使用密码。

---

# 7. rclone 的作用

rclone 的核心作用不是把全部文件同步到本地，而是：

> 把远端云主机目录映射成一个本地目录或磁盘。

因此：

```text
云主机 200 GB
```

并不意味着：

```text
每台电脑必须先下载 200 GB
```

团队成员可以先看到所有目录和文件，在真正打开某个 PDF、Word 或数据文件时，rclone 再读取远端内容，并根据配置使用本地缓存。

---

# 8. macOS 客户端

## 8.1 推荐本地结构

```text
~/ResearchCloud/      ← rclone mount
~/ResearchProjects/   ← Git clone
```

即：

```text
ResearchCloud
= 云端共享文件

ResearchProjects
= Git 管理的研究项目
```

---

## 8.2 rclone 配置

为降低非技术成员的配置负担，仓库提供 macOS 一次性配置脚本。脚本会检查并安装 rclone、生成个人 SSH Key、建立 SFTP remote、验证服务器主机密钥并测试共享目录。

在仓库目录打开终端，运行：

```sh
bash macos/setup.sh
```

成员需要提供服务器地址和自己的 Linux 用户名；端口默认为 `22`，共享目录默认为 `/home/ubuntu/data/research`。管理员须先创建成员账号、配置共享目录权限，并将成员公钥添加到账户。首次连接时，成员应先与管理员核对服务器指纹。

以后每次使用，在仓库目录运行：

```sh
bash macos/mount.sh
```

脚本使用 `rclone nfsmount` 在 macOS 上挂载到 `~/ResearchCloud`，启用写缓存并将目录缓存设置为 30 秒。保持终端打开即可在 Finder 访问；确认上传完成后按 Ctrl+C 卸载。挂载不是离线同步。

---

## 8.3 Finder 中的体验

Finder 中看到：

```text
ResearchCloud/
├── 00_Papers/
├── 01_Datasets/
├── 02_Office/
├── 03_Shared_Results/
└── 99_Temp/
```

团队成员可以直接：

- 双击打开论文；
- 拖入新论文；
- 拖出文件到本地；
- 移动；
- 改名；
- 删除；
- 用 Word / Excel / Preview 打开；
- 让 WorkBuddy 直接读取。

Windows 成员可在仓库目录运行 `powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1` 完成客户端一次性配置，并运行 `powershell -ExecutionPolicy Bypass -File .\windows\mount.ps1` 将共享目录挂载为盘符。详细的服务器管理员、Mac 和 Windows 操作流程见 [部署与成员使用指南](DEPLOYMENT.md)。

---

# 9. Windows 客户端

## 9.1 推荐本地结构

```text
R:\                  ← rclone mount
C:\ResearchProjects\ ← Git clone
```

---

## 9.2 一次性配置和日常挂载

在本方案仓库目录打开 PowerShell，完成一次性配置：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

脚本使用 winget 安装 rclone 和 WinFsp，并配置 SSH Key 与 SFTP remote。成员将脚本生成的公钥交给管理员登记；首次连接前核对服务器指纹。完成后，每次使用运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\windows\mount.ps1
```

保持 PowerShell 窗口打开，在文件资源管理器中访问所选盘符；用完并确认上传后按 Ctrl+C 卸载。详细步骤见 [部署与成员使用指南](DEPLOYMENT.md)。

Windows File Explorer 中即可看到：

```text
R:\
├── 00_Papers
├── 01_Datasets
├── 02_Office
├── 03_Shared_Results
└── 99_Temp
```

操作方式与普通磁盘基本一致。

---

# 10. 上传和下载论文

团队不需要使用 `scp`、`rsync` 等命令。

日常操作直接使用：

```text
macOS
→ Finder

Windows
→ File Explorer
```

例如上传论文：

```text
Downloads/paper.pdf
        ↓ 拖拽
ResearchCloud/00_Papers/GEO/
        ↓
云主机
```

下载论文：

```text
ResearchCloud/00_Papers/GEO/paper.pdf
        ↓ 拖拽
Downloads/
```

直接双击打开时，则不需要先手工下载完整文件库。

---

# 11. 为什么还需要 Gitea

rclone 解决的是：

> 文件共享。

Gitea 解决的是：

> 研究过程和版本历史。

例如：

```text
research_plan.md
```

Gitea 可以清楚显示：

```text
Sep 24  Henry  增加稳健性检验
Sep 22  Alice  修改变量定义
Sep 18  Henry  增加 DID 识别策略
```

还可以查看：

```diff
- 本研究采用传统 DID
+ 本研究采用 staggered DID
+ 并增加事件研究和平行趋势检验
```

这正是普通文件共享无法很好解决的部分。

---

# 12. 为什么使用 Gitea，而不是 GitLab

当前场景主要需要：

- Git Repository；
- Web 文件浏览；
- README 渲染；
- Commit History；
- Diff；
- 用户和团队管理；
- 基本项目管理。

不需要复杂的：

- CI/CD；
- Runner；
- Container Registry；
- 大规模 DevOps；
- 企业级软件研发流程。

因此 Gitea 比 GitLab 更轻，更适合研究团队。

---

# 13. Gitea 部署方式

建议 Docker 部署。

示意：

```yaml
services:
  gitea:
    image: docker.gitea.com/gitea:latest
    container_name: gitea
    restart: always
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - /srv/gitea:/data
```

初期可以直接使用 SQLite。

项目较少、团队规模较小时，没有必要立即引入 PostgreSQL。

正式使用时建议：

```text
https://git.example.com
```

通过 Nginx / Caddy 配置 HTTPS。

---

# 14. Gitea 项目结构

例如 GEO 项目：

```text
GEO/
├── README.md
├── research_plan.md
├── literature_review.md
├── hypotheses.md
├── variables.md
│
├── code/
│   ├── cleaning.py
│   ├── did.py
│   └── robustness.py
│
├── prompts/
├── tasks/
├── notes/
└── results/
```

不建议把大型论文和数据直接提交到 Repository。

---

# 15. README 作为研究项目首页

建议每个项目都有统一的：

```text
README.md
```

模板可以包含：

```markdown
# 项目名称

## 研究问题

## 当前假设

## 数据来源

## 识别策略

## 当前阶段

## 最近进展

## 下一步工作

## 负责人

## 共享资料位置

Papers:
ResearchCloud/00_Papers/GEO

Datasets:
ResearchCloud/01_Datasets/GEO
```

这样团队成员进入 Gitea 后，首先看到的是“研究项目首页”，而不是一个程序员式代码仓库。

---

# 16. Git 在本地仍然需要安装

虽然团队成员不需要熟练掌握 Git 命令，但 Mac 和 Windows 本地仍然需要 Git。

因为 WorkBuddy 背后会执行：

```bash
git pull
git add
git commit
git push
```

本地 Git Repository 会完整保存：

```text
research_plan.md
README.md
code/
.git/
```

例如：

```text
Mac:

~/ResearchProjects/GEO/


Windows:

C:\ResearchProjects\GEO\
```

---

# 17. 不建议把 Git Working Tree 放进 rclone 挂载盘

推荐：

```text
ResearchCloud/
= rclone mount

ResearchProjects/
= 本地 Git Repository
```

不要：

```text
ResearchCloud/GEO/.git/
```

主要原因是 Git 会频繁读写大量小文件和 `.git/objects`。

本地磁盘上的 Git Repository：

- 性能更好；
- 更稳定；
- 可以离线 commit；
- 网络中断时不会破坏 Git 操作。

---

# 18. WorkBuddy 的角色

WorkBuddy 可以成为研究人员和 Git 之间的“代理层”。

研究人员可以说：

> 获取 GEO 项目的最新版本。

WorkBuddy 执行：

```bash
git pull
```

研究人员说：

> 修改研究计划，增加稳健性分析，然后保存一个新版本。

WorkBuddy 可以执行：

```bash
git add research_plan.md
git commit -m "增加稳健性分析"
git push
```

研究人员不需要记住 Git 命令。

---

# 19. 推荐的日常工作流

## 19.1 阅读论文

```text
Finder / File Explorer
        ↓
ResearchCloud/00_Papers/
        ↓
打开 PDF
```

或者：

```text
WorkBuddy
        ↓
读取 ResearchCloud/00_Papers/GEO/*.pdf
        ↓
总结、比较、提取研究方法
```

---

## 19.2 修改研究计划

开始工作：

```text
WorkBuddy
   ↓
git pull
```

编辑：

```text
ResearchProjects/GEO/research_plan.md
```

完成：

```text
WorkBuddy
   ↓
git add
git commit
git push
```

之后所有团队成员都能在 Gitea 中看到：

- 最新版本；
- 修改时间；
- 修改人；
- Commit Message；
- Diff。

---

## 19.3 新增论文

团队成员：

```text
Finder / Explorer
      ↓
拖入
ResearchCloud/00_Papers/GEO/
```

即可。

不需要 Git。

---

## 19.4 上传 Word / PPT / Excel

直接：

```text
ResearchCloud/02_Office/
```

或者项目子目录。

同样不需要 Git。

---

# 20. 成员实际需要学习什么

普通研究人员只需要掌握三件事：

## 文件

```text
Finder / Explorer
```

## 项目查看

```text
Gitea Web
```

## 研究操作

```text
WorkBuddy
```

不需要熟练学习：

```text
SSH
SFTP
Git branch
Git rebase
Git merge
Git CLI
Linux
```

Git 的复杂性由 WorkBuddy 和 Gitea 屏蔽。

---

# 21. 推荐安装清单

## 云主机

```text
Ubuntu
OpenSSH Server
Git
Docker
Docker Compose
Gitea
Nginx 或 Caddy（推荐）
```

---

## macOS

```text
rclone
Git
WorkBuddy
浏览器
```

可选：

```text
Cyberduck
```

用于排错或直接访问 SFTP。

---

## Windows

```text
rclone
WinFsp
Git for Windows
WorkBuddy
浏览器
```

可选：

```text
WinSCP
```

用于排错或直接访问 SFTP。

---

# 22. 备份策略

即使云主机是集中存储，也不能把“云主机”理解成“自动有备份”。

至少建议备份：

```text
/data/research/
/srv/gitea/
```

可以采用：

```text
每天增量备份
+
每周完整备份
```

备份目标可以是：

- 另一台云主机；
- 对象存储；
- NAS；
- 外部硬盘。

尤其是：

```text
/data/research/00_Papers
/data/research/01_Datasets
/srv/gitea
```

必须纳入备份。

---

# 23. 安全建议

建议：

1. 所有团队成员使用独立 Linux 账号；
2. 优先使用 SSH Key；
3. 禁止共享一个 SSH 账号；
4. Gitea 使用独立账号；
5. 对公网 Gitea 强制 HTTPS；
6. SSH 尽量关闭 root 密码登录；
7. 做服务器防火墙；
8. 定期更新 Gitea、Docker 和系统；
9. `/data/research` 不直接开放 Samba 到公网；
10. 大文件库与 Gitea Repository 分开备份。

---

# 24. 第一阶段部署建议

不要一开始做得太复杂。

## Phase 1：先建立共享文件盘

完成：

```text
/data/research
SSH / SFTP
rclone
Finder / Explorer
```

确认：

- Mac 可以访问；
- Windows 可以访问；
- 可以上传论文；
- 可以打开 PDF；
- WorkBuddy 可以读写。

---

## Phase 2：部署 Gitea

建立：

```text
GEO
AI-Agents
Open-Weights
...
```

Repository。

把：

```text
README
research_plan
code
prompt
research notes
```

迁入 Git。

---

## Phase 3：规范 WorkBuddy 工作流

例如统一要求 WorkBuddy：

```text
开始任务前：
git pull

修改完成后：
git status
git diff

确认改动后：
git add
git commit
git push
```

Commit Message 使用人类可读的研究描述，例如：

```text
增加平行趋势检验设计

修改核心解释变量定义

补充国内 GEO 相关文献

增加异质性分析计划
```

而不是：

```text
update files
fix
new version
```

---

# 25. 最终用户体验

团队成员不需要知道整个系统背后的复杂结构。

他们看到的只有：

```text
Finder / File Explorer
        │
        └── ResearchCloud
             ├── Papers
             ├── Datasets
             ├── Office
             └── Shared Results
```

浏览器：

```text
Gitea
 ├── GEO
 ├── AI Agents
 └── Other Projects
```

WorkBuddy：

```text
阅读论文
分析数据
修改研究计划
生成代码
更新研究文档
提交 Git 版本
```

背后的技术结构则是：

```text
                     Cloud Server

          Shared Files             Version Control
               │                          │
          SFTP / SSH                   Gitea
               │                          │
            rclone                       Git
               │                          │
      Finder / Explorer             Local Clone
               │                          │
               └──────── WorkBuddy ───────┘
```

---

# 26. 最终推荐

对于目前的团队规模和研究场景，推荐：

```text
共享论文 / 数据 / Office
→ 云主机普通目录
→ SFTP
→ rclone mount
→ Finder / File Explorer

研究计划 / Markdown / 代码
→ Gitea
→ Git
→ 本地完整 Clone

AI 研究和操作
→ WorkBuddy

项目浏览和版本查看
→ Gitea Web
```

暂时不需要：

```text
GitLab
Nextcloud
Seafile
复杂 NAS 协议
完整文件同步
```

除非未来出现新的需求，例如：

- 大量成员同时编辑同一个文件；
- 在线协作编辑 Office；
- 细粒度文件锁；
- 文件评论；
- 企业级身份认证；
- CI/CD；
- 软件研发团队规模扩大。

对于当前以论文、研究计划、数据分析和 AI Agent 辅助研究为主的团队，这套架构在功能、成本、维护复杂度和使用门槛之间比较平衡。
