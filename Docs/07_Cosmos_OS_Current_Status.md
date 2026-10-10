# Cosmos OS Current Status

## 0. 文件说明

- 本文件**只记录当前状态**（AGENTS §18.1），目标不超过 40 KB。
- 历史细节、各阶段验证过程和旧检查点见 `Docs/Archive/07_Cosmos_OS_Current_Status_至2026-10-10.md`（下文写“归档 §N”即指该归档文件的章节号；归档只追加新归档，不修改）和 `Docs/Development Log/`（按日追加）。
- 更新规则：模块关闭时，本文件只保留该模块的**一行清单、存储与兼容事实和待办**；过程细节、测试数量推演、PID、临时日志路径写进当日开发日志。不得在头部堆叠“Previous stage”。

---

## 1. 当前检查点

- **日期：** 2026-10-11。**项目：** Cosmos OS / Cosmos-Toolbox（原生 macOS SwiftUI 个人工作操作系统）。
- **主线：** `main` = `origin/main` = `b57d5aa1eaf3c3a424cb57f9b69bf7d08b00f1d5`（第一步已由用户体验接受、提交并推送）。本轮只在 `integration/ui-step2` 集成，未推送、未移动 main；两个 feature worktree 保留。
- **当前阶段：** 体验升级第二步 A / B 已集成并部署；隔离 Debug / Universal Release 构建与 250 个唯一测试通过。在 `integration/ui-step2` 等待用户体验验收，main 未变；真实交互与真实知识库 GitHub 拉取未替代为 XCTest 验收。
- **集成验证：** 本轮唯一测试数量与离屏截图证据见当日开发日志；截图覆盖知识库三个分段、空来源、合成来源浏览 / 阅读、统一检索知识库文档，以及仪表盘 / 项目 / AI 工作台抽查。业务存储格式、交付 / 路径服务未改；新增来源登记不进核心备份。
- **安装位置：** `~/Applications/Cosmos Toolbox.app`；版本 1.0（构建 1）不代表 PRD V1.0。最新部署为已提交源码（dirty=false）；部署时 HEAD 与启动证据见当日日志。

---

## 2. 协作模式（用户确认，2026-10-10 起）

- **用户：** 产品负责人，最终决策与验收；授权提交 / 推送 / 合并。
- **统筹（claude.ai 中的 Claude 会话）：** 产品方向、模块范围、给开发工具写完整模块提示词、阶段收尾判断；可只读用户 Mac 上的本仓库并查看 GitHub 远端分支状态。
- **开发工具：** Claude Code 与 Codex 按额度择一主开发；必要时另一个只做一次集中只读复审；确有两个独立模块时，才在同一仓库的独立分支 + 独立 worktree 并行，共享文件只由明确负责人修改，整合与部署串行、只有一个部署负责人。参与修改的工具的自查不是独立第三方复审。
- ChatGPT web 不再是架构顾问角色（历史记录保留）。
- **用户确认的产品决定（2026-10-10）：** Cosmos OS 属于用户本人，卓望是第一个公司工作区。将来换公司时新增与“卓望工作”平级的工作区（如“A 工作”），旧工作区归档不删除；真实出现第二个公司前不做通用多工作区框架，但新导航、仪表盘统计与后续迁移不得把卓望写死为唯一工作区；旧公司内部资料默认不迁移到新工作区。
- 推进、验证、收尾、Git 授权规则见 **AGENTS §23**（本文件不复制；该规则由提交 `765b33b` 引入，Codex 开发规范由 `df90894` 建立）；AGENTS §1 的必读文档在 §23 优先级前提下按需读取。

---

## 3. 模块清单（在用与进行中）

“关闭提交”为 `git log` 上实际存在的短哈希；早期（2026-08/09）英文提交为该能力的主要实现提交。入口为侧栏名称（`SidebarItem`，本模块已改为分组：首页[仪表盘、统一检索]｜工作[卓望工作、项目、知识库]｜AI[AI 工作台、提示词库]｜学习[AI 学习中心]｜系统[Mac 优化]；设置改为侧栏底部入口与原生 Settings scene，隔离验证已通过）。

| 模块 | 入口位置 | 状态 | 关闭提交 | 归档 | 一句话主要限制 |
|---|---|---|---|---|---|
| 体验升级第一步 | 仪表盘 / 工作台指标 / 统一检索 / 设置窗口 / 侧栏 | 用户已体验接受、已提交推送 | b57d5aa | 2026-10-11 开发日志 | 本轮继续保留业务边界；交付计数沿用工作台检查 |
| 页面改版与全局动效（第二步 A） | 项目 / AI 工作台 / 提示词库 / 学习 / Mac / 笔记列表与侧栏切换 | 已集成部署，待体验验收 | 7d783bb | 2026-10-11 开发日志 | 模板仅预填草稿；动态手感与玻璃合成需真实体验 |
| 我的知识库（外部知识库只读接入，第二步 B） | 知识库 → 我的知识库；统一检索 | 已集成部署，待体验验收 | c8d3349；接线 02b7a09 | 2026-10-11 开发日志 | 只读，仅文本类读正文、附件只列名称；无 FSEvents，不进核心备份 |
| 卓望 Workspace / Campaign / 六步 Workflow 01–06 | 卓望工作 | 在用 | 4536dbb、546faea、442e6fb、dc5c711 | §2–§4 | 数据在 UserDefaults；DeepSeek Harness 是唯一已接通 Provider |
| Step 05 HTML 原型闭环 + Tool Adapter | 卓望工作 → 活动详情 | 在用 | 2b85a00、a72e61a、402ef24 | §6–§7 | 原型工具未绑定 Figma；Figma/Pixso 自动执行未实现 |
| AI/工具配置持久化保护；Campaign/Workspace Store 保护 Phase 1 | 内部 | 在用 | 214975d、6b52af5 | §4 | 仅进程内锁 + UserDefaults 读回，无跨进程事务 |
| Artifact Review Workspace + 版本切换 | 活动详情 → 工作产物 | 在用 | 1d8403a | §7–§8 | 真实 UI 逐项点击未全覆盖 |
| HTML Preview 安全边界 | Review 窗口 | 在用 | 028b393 | §7 | 兼容边界，非通用浏览器沙箱 |
| Artifact 双版本并排比较 | Artifact 详情 | 在用 | cfa7d81 | §7 | 无文本 Diff / 差异高亮 |
| Preview 类型化抽象层 | Review 内部 | 在用 | 01b1207 | §7 | 持久化模型仍偏 HTML |
| 本地图片 Renderer | Review / Compare | 在用 | 30de1e0 | §7 | 仅本地 PNG/JPEG；ImageIO 解码不可中断 |
| 本地 PDF Renderer | Review / Compare | 在用 | c7491a3 | §7 | PDFKit 在进程内解析，非进程隔离 |
| Step 06 客服文档（DeepSeek Harness → Markdown） | 卓望 Workflow 第 6 步 | 在用（单次真实验收） | 0f1c54e | §2–§3、§13 | 仅验收 2026-09-29 一轮；Harness 暂缓 |
| Campaign 工作产物交付包（ZIP） | 活动详情 → 工作产物 | 在用 | e15bf38 | §3、§13 | ZIP 构建/校验在 UI 动作中同步执行 |
| Campaign 项目推进工作台 | 卓望工作 → 总览 | 在用 | e2c6151 | §13 | 摘要每次渲染重算；未逐项点击 |
| 知识与资产中心（卓望产物检索） | 知识库 →「卓望知识与资产」 | 在用 | db15f79 | §16 | F1–F5 后续项未处理 |
| Prompt Vault（变量模板） | 提示词库 | 在用 | 693c4fc | §17 | 单一文本分类、无标签；变量值不保存 |
| 提示词版本管理 | 提示词库 → 详情 | 在用 | 0eca18f | §35 | schema 2，旧程序无法编辑 |
| 学习中心 | AI 学习中心 | 在用 | 82cc7ba | §18 | 三态手动，不显示百分比；条目不可删 |
| 省份可维护配置 | 卓望工作 → 管理工作区 | 在用 | 863fc83 | §19 | 全新安装无省份；活动改名仍改变推导目录 |
| 全国月度会员促活清单 | 卓望（全国）→ 活动详情「月度清单」 | 在用 | 68f080f | §20 | 登记不是采用，不进交付包 |
| 首页真实数据 | 仪表盘 | 在用 | 4c45dbb | §21 | 已结束活动只计数不列出；AI 检测状态仅使用已有缓存 |
| AI 工作台 Phase 1 本机工具检测 | AI 工作台 | 在用 | 6639e43 | §22 | 只证明 `--version` 可运行 |
| AI 工作台 Phase 2 任务准备与提示词交接 | AI 工作台 | 在用 | e66dd21 | §23 | 草稿仅页面内存 |
| AI 工作台 Phase 3 任务交接记录 | AI 工作台 → 交接记录 | 在用 | bc9cb33 | §24 | 历史全量加载、无分页 |
| 任务上下文资料选择 | AI 工作台 | 在用 | 3024ceb | §25 | 单份 2 MiB、总提示词 4 MiB |
| 核心数据备份（现为 V3） | 设置 | 在用 | 16dd386 | §26 | 仅元数据；非加密、非签名 |
| 核心数据空环境恢复 | 设置 / 启动保护 | 在用 | 72f020b | §27 | 非跨进程原子事务；仅空环境 |
| Mac 环境只读概览 | Mac 优化 | 在用 | 7124c4f | §28 | 无内存压力、电池健康；只读 |
| 日常使用部署（Universal Release） | `scripts/deploy-macos.py` | 在用 | f6a1e90 | §29 | ad-hoc 签名，无公证与自动更新 |
| 个人项目 Projects | 项目 | 在用 | caf6150 | §30 | 引用仅路径；无永久删除 |
| 卓望工作区入口接通 | 卓望工作 → 概览 | 在用 | a5294c9 | §31 | 真实按钮/导航未逐项点击 |
| 卓望分类页接通 | 卓望工作 → 分类 | 在用 | 5eb45f6 | §32 | 仅 FAQ/原型/流程图/素材/提示词有归属 |
| 活动资料与外部成果引用 | 活动详情 → 概览 | 在用 | 6c86c60 | §33 | 只登记路径/链接，不读实体 |
| 统一检索 | 统一检索 | 在用 | 16b9463 | §34 | 只搜白名单元数据字段，不搜正文 |
| 个人知识笔记 | 知识库 →「个人笔记」 | 在用 | 6272a52 | §36 | 纯文本 / Markdown 源文；无永久删除 |
| 个人内容导出（本期） | 个人笔记 / 提示词库 → 批量导出、详情单条导出 | 在用 | ebf4280 | §37 | 真实点击与保存面板未测；不是备份 |

**内容导出（归档 §37 摘要）：** 单条 `.md` = 所选**已保存版本**正文的 UTF-8 原字节（不含标题 / 元数据 / 引用）；批量 ZIP（`说明.md`、`manifest.json`、`notes|prompts/<显示名>--<UUID>/current.md` + 可选 `history/vNNN.md`，manifest 含来源 / 稳定 ID / 版本 / 保存时间 / 路径 / 字节 / SHA-256，笔记引用只登记）。准备时冻结，导出前两次重读按指纹核对，所选记录变化即停；源库只读；临时目录生成并读回 → `.part` → `renamex_np(RENAME_EXCL)` 不覆盖发布；取消仅在发布前生效；保存位置不得在源库目录。manifest `exportFormat=CosmosContentExport`，核心校验 / 恢复拒绝。本期新增 17 个测试，加受影响既有类共 55 项（17+24+14）54 通过，唯一失败为新夹具大小假设，修复后通过；ditto 与 Python zipfile 独立解包核对。

**测试活动现状（浙江活动测试）：** Workflow 01–06 均已确认；完整策划案采用 **V1**；产品原型采用 **V3**，Artifact 详情管理 V1 / V3 / V4，本地 V2 刻意不入管且不得导入 / 删除 / 修改；Step 06 为一次成功 Run + 一次已批准 Approval + 已采用 Markdown V1（`~/Documents/Cosmos OS/Workspaces/卓望/浙江/浙江活动测试/06_客服文档/客服文档_V1.md`，28,360 字节，SHA-256 `ad4b0f6070d9e5b743cb3f6fff2c631469fb934a96fe9f8ca836efc50d830fd5`）。除非用户明确更改，不覆盖这些选择。

---

## 4. 数据存储与格式

### 4.1 UserDefaults（正式域 `com.wangyucosmos.Cosmos-Toolbox`）

业务键（Data）：`cosmos.zhuowang.campaigns.v1`、`…workspace.v1`（含省份配置）、`…workflows.v1`（内嵌 Artifact / Run / Approval）、`…ai.providers.v1`、`…ai.connections.v1`、`…ai.toolIntegrations.v1`、`…ai.agentToolRoutes.v1`；每个主键有同名 `.backup`。保护：向后兼容解码（新增字段不使旧数据不可解码）；解码失败锁定 Store、保留原字节、不以空数据覆盖；写前备份并读回；写失败不发布到内存；陈旧 Store 实例重读后拒绝写；仅主键真正缺失时才种默认配置。Workspace 模块更新 / 删除只是 Store API，无正式 UI。完整性闸门口径：逐键 SHA-256 + 解码检查；整份 plist 哈希只作诊断（含 AppKit 窗口状态键）。

### 4.1.1 UI 偏好（本模块新增，隔离测试通过，已部署）

仅新增 `cosmos.ui.appearance`（system / light / dark）、`cosmos.ui.textSize`（standard / large / extraLarge）、`cosmos.ui.startup`（dashboard / lastPage）、`cosmos.ui.sidebarEnglish`（Bool，默认 false）、`cosmos.ui.motion`（system / reduced）、`cosmos.ui.lastPage`（侧栏模块白名单）。非法值只读回退默认值，不修复原键；不修改业务键，不进入核心备份。外观使用 NSApp.appearance；近期检索词与导航筛选只在内存。随机 suite 自动测试通过；第一步已接受体验范围，第二步动效待体验验收。

### 4.2 独立 JSON 文件存储（`~/Library/Application Support/Cosmos OS/…`）

共同模式（Prompt Vault 首创，Learning / Handoff / Projects / Notes 复制改写，未抽象成框架）：缺库只读零初始化；lstat 父路径与文件类型校验、拒绝符号链接、`O_NOFOLLOW` 读；flock 协作写锁；锁内重读最新磁盘文档并核对目标修订；写前备份**精确原字节**并读回；同目录临时文件 fsync + 原子 rename；发布后读回校验，失败 = `uncertainWrite` 并锁定保存；损坏 / 未知 schema / 重复身份 / 缺主有备份 / 符号链接 → 锁定写入，不自动恢复、不以空库覆盖；容量超限拒绝而不截断，其中带历史的模块（提示词、笔记）用 `capacityExceeded` **不锁定模块**。

| 存储 | 目录 / 主文件 | 备份 / 锁 | schemaVersion | 容量与要点 | DEBUG 隔离参数 |
|---|---|---|---|---|---|
| Prompt Vault | `PromptVault/templates.json` | `templates.backup.json`、`.prompt-vault.lock` | 写 2、读 1/2 | 16 MiB；每模板 500 版本 | `--cosmos-prompt-fixture-root /private/tmp/CosmosPromptVaultPhase1-<UUID>` |
| 学习中心 | `Learning/learning.json`（主题 + 记录同一文档） | `learning.backup.json`、`.learning.lock` | 1 | 16 MiB；单条记录 ≤1 MiB | `--cosmos-learning-fixture-root …/CosmosLearningPhase1-<UUID>` |
| AI 工作台交接 | `AIWorkspace/handoffs.json` | `handoffs.backup.json`、`.handoffs.lock` | 1 | 16 MiB；同 ID 幂等重试 | `--cosmos-ai-handoff-fixture-root …/CosmosAIHandoffPhase3-<UUID>`；`--cosmos-ai-workspace-history` |
| Projects | `Projects/projects.json` | `projects.backup.json`、`.projects.lock` | 1 | 16 MiB；单段 ≤1 MiB | `--cosmos-projects-fixture-root …/CosmosProjectsPhase1-<UUID>` |
| 个人笔记 | `PersonalNotes/notes.json` | `notes.backup.json`、`.notes.lock` | 1 | 16 MiB；正文 ≤1 MiB；≤500 版本、≤200 引用 | `--cosmos-notes-fixture-root …/CosmosPersonalNotesPhase1-<UUID>` |
| 我的知识库来源 | `KnowledgeSources/sources.json` | `sources.backup.json`、`.sources.lock` | 1 | 1 MiB、最多 32 个来源；索引仅内存 | `--cosmos-knowledge-sources-fixture-root /private/tmp/CosmosKnowledgeSources-<UUID>`；隔离下仅可登记 /private/tmp 文件夹 |
| 核心恢复控制 | `CoreRestore/state.json`、`payload-<sourceID>.json` | `.restore.lock`（非阻塞 flock） | — | journal fsync + 原子 rename | `--cosmos-core-restore-fixture-root …/CosmosCoreRestorePhase1-<UUID>` |
| 资产中心 / 资料读取 | （只读，不是存储） | — | — | 单份文本 2 MiB；32 MiB LRU | `--cosmos-asset-fixture-root /private/tmp/CosmosAssetPhase1-*` |

- 内容导出**没有持久化存储**（无导出记录）。
- 知识库来源只登记规范化路径，不新增业务 UserDefaults 键；索引仅在内存，核心备份仍为 V3。来源登记与外部知识库内容均不随核心备份。
- 隔离启动同时要求：隔离 Bundle ID 前缀 `com.wangyucosmos.cosmostoolbox.persistenceui.`、`--cosmos-store-phase1-suite`（UUID suite）与上述 UUID 根；缺失或无效一律失败关闭，不回退正式位置。Release 不含这些参数（历次 Release 二进制扫描为 0 命中）。
- 本地工作文件：`~/Documents/Cosmos OS/Workspaces/卓望/<省份>/<活动>/`（`01_需求整理`…`06_客服文档`、`Assets`；历史目录名保持可读）。实际路径使用 `ZhuowangProvince.pathName = directoryName ?? name`，省份改名不改路径；活动名仍参与路径。

### 4.3 核心备份格式

- `manifest`：`format=CosmosCoreMetadata`、`version`、`exportedAt`、`exclusions`、逐源条目（id / present|missing / 路径 / 字节 / SHA-256 / transformation）。未压缩 ZIP，只接受固定路径白名单，CRC32 + SHA-256；单源 16 MiB、包 128 MiB、清单 256 KiB；发布用 `renamex_np(RENAME_EXCL)`。
- **V1（10 源）** campaigns、workspace、workflows、providers、connections、tools、routes、prompts、learning、handoffs；**V2（11 源）** + projects；**V3（12 源，当前导出版本）** + notes（`data/notes.json`）。V1 / V2 按各自固定源清单与原排除说明继续校验，不把新源硬套入旧包；未知版本（≥4）拒绝；V3 条目上限 13（manifest + 12 源）。
- 普通业务 JSON 原字节；AI 配置按白名单脱敏（Provider 排除 configurationIdentifier；Connection / Tool / Route 排除自由配置、endpoint、adapter、notes）；不读 Keychain，不整域导出 UserDefaults。恢复后 AI 配置均为禁用 / needsSetup。
- **空环境恢复的“非空”判定：** 固定 7 个 UserDefaults 主键及 `.backup` 必须不存在；Prompt / Learning / AIWorkspace / Projects / PersonalNotes 五个根下主文件、备份、写锁均不存在；任何有效空载荷、错类型、损坏、不可读、未知恢复控制数据都算非空而拒绝。根视图先进入数据启动保护；“创建新环境”先持久化 started 标记，之后不能再作空环境恢复。

---

## 5. 兼容与回退限制（集中记录，勿丢）

1. **提示词库 schema 2：** 新版首次成功写入后写 schema 2，旧程序读到 `unsupportedSchema` 并禁止保存（不会静默丢历史）；读 schema 1 不写盘。`templates.backup.json` 是**滚动备份**（每次成功保存前被“写前主文件字节”替换），**不能**当永久降级副本；只有用户另行保留的 schema 1 副本才能供旧程序使用，回退会丢失升级后的新版本。
2. **核心备份当前 V3：** 旧 App 校验 / 恢复 V3 会因版本 / 源清单拒绝；新 App 读 V1 / V2 / V3，旧包恢复预览明确提示“不含 Projects / 个人笔记”，不建空库；V3 包中笔记引用只含登记记录。
3. **文件引用实体不随备份打包**（Campaign 引用、Projects 引用、笔记引用只备份登记的路径 / 链接）；登记路径仍依赖原文件，不是完整换机恢复。备份不加密、不签名，哈希只防意外损坏。
4. **内容导出 ZIP / .md 不是核心备份**：`exportFormat=CosmosContentExport`、`isCoreBackup=false`，核心备份校验与恢复均拒绝；不能用于恢复。
5. **App 回退副本只回退程序，不保证数据格式可降级**（见 1、2）。
6. 恢复是“带持久化收据、启动门控和协作锁的协议”，不是文件与 UserDefaults 的跨进程原子事务；同卷 hardlink 是文件发布前提（跨卷 EXDEV 安全失败）。
7. 所有独立存储的协作 flock 只协调本 App 的写者，不防非协作外部进程在检查后写入，也不承诺断电耐久。
8. 版本显示 1.0（构建 1）不代表 PRD V1.0（需连续使用 30 天等使用类标准）。
9. 本轮只新增知识库来源登记 schema 1；回退到第一步 App 会忽略 `KnowledgeSources/sources.json`，无害。来源登记与知识库内容不随核心备份，换机后重新添加来源；`UnifiedSearchSource.knowledgeDocument` 是新枚举 case，旧代码不识别，但不改变已有业务数据格式。

---

## 6. 部署

- 命令（仓库根目录）：`/usr/bin/python3 scripts/deploy-macos.py`。固定 Xcode 工程 / scheme，构建 **Universal Release（arm64 + x86_64）**，校验双架构与正式身份，注入元数据（commit、`CosmosBuildDirty`），本地 ad-hoc 签名并 `codesign --verify --deep --strict`；独立 flock。
- Bundle ID：`com.wangyucosmos.Cosmos-Toolbox`。安装位置：`~/Applications/Cosmos Toolbox.app`。
- 旧 App 通过 `NSRunningApplication.terminate` **正常退出**（不强杀、不绕过未保存保护；被阻止即停止并报告）；已有同身份 App 先移到**回退副本目录** `~/Applications/Cosmos OS Rollbacks/Cosmos Toolbox-<时间>-<唯一标识>.app`，再以 `RENAME_EXCL` 发布新版；启动失败保留安装与回退副本。
- **最近一次回退副本：** `Cosmos Toolbox-20261011-024243-b63b66a3.app`；历史副本不自动清理。第二步不改变已有业务数据格式，副本可回到部署前的第一步界面；新增来源登记文件会被旧 App 忽略，无害。历史 schema 降级风险仍按 §5。
- 脚本不读写业务数据；正常启动沿用 App 既有行为，可能写窗口偏好。无公证、无自动更新、无安装器。

---

## 7. 验证与安全基线

- **只用隔离数据**：测试和 UI 验收只用合成数据、`/private/tmp/…` UUID 根、独立测试身份 / 随机 UserDefaults suite；隔离依赖缺失时失败关闭；不读写正式业务数据，不操作正式 App 窗口做验收。
- **禁止按同名 App 使用 System Events**：2026-10-10 一次 UI 自动化尝试因隔离 App 与正式 App 同名，误改了正式 App 窗口位置 / 大小（已按原值恢复位置与大小，前台状态无法还原，未发点击输入，未做业务数据全面审计）。此后 UI 自动化只能定位**唯一进程名的隔离拷贝**，无法确认目标时放弃该 UI 操作。
- **DEBUG 隔离模式下打开 Campaign 详情窗口可能写入正式 Workspace**（`onAppear` 的恢复 / 迁移调用不受隔离；归档 §13 todo 4）；因此隔离验收不打开合成活动详情，统一检索也拒绝隔离下的 Campaign 详情。
- 测试数量按**唯一测试**去重，不把“首轮 + 修复后重跑”重复计数；报告区分**本轮实测**、**沿用证据**、**未覆盖**。真实窗口点击 / 保存面板 / Finder 的交互在多数模块仍为未覆盖缺口，工具无法安全完成时记录缺口，不要求用户逐步点击。
- 每阶段最多一轮集中测试 + 一轮集中修复（AGENTS §23）。
- 知识库文件夹：除用户点击触发的 `git fetch origin`、`git pull --ff-only` 外一律不写；Git 只走固定命令枚举与参数数组，`GIT_TERMINAL_PROMPT=0`、60 秒超时，读状态加 `--no-optional-locks`。敏感排除是硬规则。
- Documents 目录在 XCTest 宿主中可能触发权限弹窗；真实库冒烟不得放入测试宿主。隔离接线显式禁用默认 Documents 建议目录，失败关闭时也不探测该目录；测试只用 /private/tmp 合成来源，无真实 fetch / pull。
- 隔离测试遗留的空 suite plist 可能残留于 `~/Library/Preferences`，清理需单独授权。

---

## 8. 已知风险 / 技术债

**P0 / 高**
- 卓望核心业务数据（Campaign / Workspace / Workflow / AI 配置）仍在 UserDefaults；仅进程内锁 + 读回，无跨进程事务、自动恢复、备份轮换、断电耐久；长期应迁移到更稳健的结构化存储（需单独规划）。
- Workspace 主键缺失但有备份时，加载会重新初始化默认配置而不查备份（既有行为，历史仍在磁盘与其他存储）。
- 数据格式降级不受保护（见 §5：提示词 schema 2、备份 V3）。
- 任何 JSON 存储在“检查后被非协作进程改写”的竞态下无保证。

**P1**
- 活动改名会改变推导的活动目录（省份已用 `directoryName` 固定路径，活动未处理）。
- DEBUG 隔离未隔离 Campaign 详情写 Workspace（见 §7）。
- 交付包 ZIP 创建 / 哈希 / 解压校验在选择面板动作中同步执行，大交付集可能卡 UI。
- 进程内解析：PDFKit / ImageIO 在 Cosmos 进程内，限制只降低风险；更强边界需 XPC / 独立进程 Renderer。HTML Preview 允许内联脚本与 `data:`/`blob:` 资源（兼容边界，放宽需单独威胁评估）。
- Provider 覆盖窄：只有 DeepSeek Harness 完成端到端；`DeepSeekHarnessAdapter` 仍写死用户特定 `npx` 路径（运行时发现层仅限 DeepSeek）；Figma / Pixso 自动执行、Claude Desktop / ChatGPT / Codex 在 Cosmos 内直接执行均未实现。
- Step 06 仅 Harness → Markdown，未采用结果仅存会话内；其验收只覆盖 2026-09-29 一轮，不证明后续 Harness 版本的约束。
- Artifact 持久化模型仍偏 HTML；二进制 / 外部文档的采用、恢复、持久化引用（安全书签）未做。
- 多处同步或 UI actor 上的读取 / 解码 / 线性搜索（资产中心、统一检索缓存）在大数据量下的性能未测；仪表盘 2.0 除交付计数外的读取 / 解码 / 聚合在后台，合成数据测试已通过。
- 真实 UI 交互验收普遍缺口（点击、保存面板、关闭 / 退出提醒、重启）；Swift 6 迁移 actor / Sendable warning 保留。
- 知识库扫描：文件名含 token / secret 等可能误伤正常文档（偏安全）；.gitignore 只支持子集且只读来源根目录；Git 仓库判定只看来源根。索引全量驻内存，超大库扫描 / 列表性能仍需实际数据验证。

---

## 9. 非阻塞待办（按模块，去重）

- **体验升级第二步 A：** 统一过渡采用稳定外层容器，模板预填不落盘；自动测试与浅深色离屏图已验证。实时侧栏切换手感、玻璃按钮形变 / 暗色合成、帧率、跨窗口主题与面板交互待用户体验；长内容按设计滚动。
- **我的知识库（第二步 B）：** 真实添加来源 / 阅读 / 点击与真实 GitHub fetch、pull 待验收；后续另定 FSEvents、独立阅读窗口、大列表分页；token / secret 误伤、.gitignore 子集与来源根仓库判定限制见 §8。
- 仪表盘“可以交付”在主线程计算，复用工作台交付检查；活动数量大时可能卡顿，后续需要把交付候选检查改为可后台执行（涉及业务层，需单独确定范围）。

- **卓望 / 推进工作台：** 指标卡把列表挤出首屏；摘要每次渲染重算；省份概览与首页残留占位；活动列表行不标省份停用；路由请求在编辑中到达不重放。
- **资产中心：** F1–F5（打开的详情保留旧快照、详情与搜索共用代次、窗口身份被 Campaign Review 共用、读不到正文的资产在正文搜索中缺席无提示、隔离根过滤 / Review 关闭 / 并发测试覆盖不足）；失败读取不缓存。
- **Prompt Vault / 提示词版本：** 解析警告位置文案未插值；任何替换阶段失败都按 `uncertainWrite` 保守锁定；窗口持有旧 Store 列表可能过期；无历史差异比较 / 导入 / 历史删除 / 历史变量填充。
- **学习中心：** 条目不可删 / 归档；链接仅复制；窗口标题不随改名；侧栏名仍是“AI 学习中心”。
- **省份 / 月度会员促活：** 普通活动与月度活动不可互转；登记只追加；10 槽掌厅文案无结构化编辑；把 Word / Figma / 链接成品登记为受管 Artifact 是后续阶段。
- **首页：** 大 Workflow 解码成本未测；AI 检测状态使用已有内存缓存，不在首页自动触发检测。
- **AI 工作台：** Codex / Claude 内置路径随应用升级可能变；多安装只取第一个可运行者；交接历史无分页；资料正文大段直接 Text 呈现。
- **核心备份 / 恢复：** 内存中处理接近上限时有内存成本；配置自由字典全部排除（需扩展白名单才可保留）。
- **Mac 概览：** 无内存压力、电池循环 / 健康容量。
- **Projects / 笔记 / 内容导出：** 列表一次渲染全部记录（超大库需分页）；批量包为不压缩 ZIP；导出无“排除引用位置”开关；强制退出可能残留隐藏 `.part` 或系统临时目录。
- **部署：** 未实机触发“未保存阻止退出”与回退分支。

---

## 10. 暂缓事项（未明确恢复者不得自行恢复）

- **全局 UI / Motion 美化：** 第一步已接受；第二步 A / B 已完成集成，待用户体验验收；第三步卓望大页面待定，不自动开始。

- **Word WIP：** 本地分支 `wip/markdown-word-export-phase1-20260930`（提交 `2d26b2a`，未合并、未推送、部分 UI 验收、未接受）。
- **Step 06 Harness：** 不运行；不重复采用；不再触发真实 Harness。
- **客服文档 V1 重新采用 / 导入：** 不做；事故文件 `客服文档 _ AI 采用结果_V1.md` 不导入。
- **Evidence / Quarantine：** 四个文件保持原样（均在正式 Workspace 与知识库路径之外，31,878 字节，SHA-256 `a198eb7d2336c4487683360bc3f008fd94f569601d3a1850d65a412e67aaa9ec`），不删除、不覆盖、不恢复、不自动导入。
- **旧 P3**（Store Phase 2 / 细分错误枚举 / 内置模块删除规则 / 整 Store `@MainActor` 迁移 / 陈旧冲突重载 / 重复 `allowsMutations` 守卫等）、**F1–F5**（见 §9）、Browser / 桌面宽度 Preview、批注 / 评论、persistent draft / revision、外部引用 Renderer（Figma / Pixso / URL）、通用 AI Runtime Adapter 层、通用多 Workspace 重构、Artifact 窗口性能与 DeepSeek 子进程权限优化。
- 远端另有分支 `wip/pdf-renderer-phase1-20260902`（归档未记录，不处理）。
- 内容导出本期明确不做：Word / PDF / 富文本导出、导入、历史删除、云分享、自动 / 定时导出、持久化导出记录。

---

## 11. 不得回退

- 01–04 Workflow 恢复能力；完整策划案当前采用 V1；产品原型采用 V3 的选择未经用户明确更改不覆盖。
- **Figma 是 Tool，不是 AI Provider**；原型步骤（`prototypeDesign`）保持工具无关；Workflow Step = AI Provider + Tool → Artifact。
- Artifact 保留全部历史版本，每个逻辑 Artifact 恰有一个当前采用版本；后续步骤只消费当前采用版本；采用后才落盘并解锁下一步。
- 本地工作文件不是一次性数据；原生业务详情窗口保持原生独立窗口；用户已于 2026-10-10 启动体验升级；美化不得改变业务逻辑与数据格式；不过早做通用多 Workspace 重构。
- 数据安全：不清空 / 重置 UserDefaults 或工作区作为修复捷径；元数据恢复幂等且不删用户文件；新增 Codable 字段保持旧数据可解码。
- 首页不显示编造的任务 / 健康数；任何位置不显示学习百分比进度（三态手动）。
- 引用（Campaign / Projects / 笔记）只登记，不读取、复制、移动、删除实体；登记不等于 Artifact 采用或交付资格。
- 测试与验收不触碰正式数据；不按同名 App 做 UI 自动化（§7）。
- 知识库内容只读，除用户点击触发固定 fetch / 快进 pull 外不写来源；敏感排除不可由 UI 绕过。来源不进核心备份，Documents 真库冒烟不进 XCTest 宿主。

---

## 12. 下一优先级

**先由用户体验验收集成的第二步 A / B。** 接受后用户单独授权 main 快进、推送与清理两个 worktree / feature 分支；当前不推送、不移动 main、不清理。第三步卓望大页面范围待定，暂不自动开发。
