# Cosmos OS Development Log — 2026-10-11

## 体验升级第一步 — 主要源码保留，构建阻塞，未部署

- 正式仓库 `/Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox`，干净基线 `93e25a86017040c07dbc648fe90c300ed37f396b`；未 pull / reset / stash / add / commit / push / merge。读取 AGENTS（重点 §23、§10–12）、Current Status 全文、当日已有日志、UI 基线状态说明及本模块依赖；旧验收不重跑。跨日后按用户时间使用本日志。
- 用户 2026-10-10 恢复全局 UI / Motion 分步升级，本模块为设计系统、外壳、Settings、仪表盘 2.0、工作台指标和统一检索呈现。用户进一步明确：交付候选检查、Workspace 路径服务、ZhuowangCampaignProgress 及其它业务层不动；仅“可以交付”允许主线程聚合，后台其它来源发布后单独计算，加载 / 错误仅在这张卡片显示。后续后台交付检查需另定范围。
- 新增：`CosmosUIPreferences.swift`（六个 cosmos.ui. 偏好、非法值只读回退、NSApp.appearance、减少动效）、`CosmosNavigator.swift`（目的地与工作台过滤、设置标签、检索词、UUID 请求）、`CosmosDesignComponents.swift`（字体 token、标题 / ⓘ、Button 卡片、数字指标、图表容器、空态、玻璃操作组）、`CosmosNavigationSurfaces.swift`（外部工作台导航和知识库子分段接线，复用原页面）、`CosmosSettingsView.swift`（三个 Settings 标签；复用原备份 ViewModel、恢复 View、保存面板行为，不修改备份 / 恢复源文件）、`DashboardHomeSnapshot.swift`（非隔离的后台只读数据投影 DTO、来源错误隔离、近 7 天 / 8 周次数、真实分布、最多八条最近记录）、`CosmosUIUpgradeTests.swift`（16 个新增测试方法，未执行）。
- 修改：`CosmosDesignSystem.swift`（兼容样式采用系统填充并遵循减少动效）、`Cosmos_ToolboxApp.swift`（原生 Settings scene 与 UI 环境）、`DashboardView.swift`（中文分组、英文名称偏好、底部设置、统一导航及既有精确打开）、`DashboardHomeView.swift`（真实指标 / Charts / 快捷操作 / 最近记录 / Mac 与已有 AI 缓存）、`DashboardHomeViewModel.swift`（生产首页后台 load 分支、合并刷新、后台结果发布后用既有 ProgressBuilder 默认 DeliverableCounter 主线程交付计数；原首页投影接口保留给历史测试）、`UnifiedSearchView.swift`（搜索焦点、⌘F、来源胶囊、按来源分组与命中高亮，原读取 / 搜索模型 / 导航未动）、`ZhuowangCampaignWorkbenchView.swift`（指标筛选 / 再点取消 / 外部筛选；增加仅由隔离外壳关闭详情的安全开关）。
- SDK 确认：当前 Xcode 27.0 / SwiftUI SDK 包含 glassEffect、GlassEffectContainer、glass 按钮样式、numericText；仓库目标仍 macOS 26.5 / Swift 5 / 默认 MainActor，不改工程配置。先前边界探针仅在 /private/tmp，后台调用主 actor 方法得到警告，未修改业务层。
- 集中验证：先 `build-for-testing`（Debug、独立 Bundle ID `com.wangyucosmos.cosmostoolbox.persistenceui.UIUpgradeTestHost`、`CODE_SIGNING_ALLOWED=NO`、DerivedData `/private/tmp/CosmosUIUpgrade-01a1267e/DerivedData`）。沙箱内官方 SwiftUI 宏插件无法启动，产生既有文件级联宏错误；同命令获自动批准后沙箱外执行，得到有效编译诊断。这是环境重试，不宣称通过。
- 一次集中修复：MacEnvironmentViewModel 的主 actor 默认参数改为可选后在初始化内部构造；Workflow 状态接线改为 workflowPersistenceState；自查同步修正最近活动行的 campaignID、交付发布代次检查、后台 Workspace 解码辅助的隔离声明、Settings 重复打开以及离屏夹具 Provider 初始化。修复未涉及业务层。
- 修复后构建仍 FAILED：`CosmosNavigationSurfaces.swift:17` 的 `ScrollView {}` 在 SDK 上匹配 `init(_:showsIndicators:content:)` 与 `init(_:content:)`，报 `ambiguous use of init`。**按用户附件 §5 / §9“集中修复后仍构建失败或核心测试失败”停止；不继续第二轮修复、不部署。** 最小下一范围是消除该新增外壳的重载歧义并继续必要验证；是否还有其它诊断尚不确定，不保证只需改一行。
- 证据：`/private/tmp/CosmosUIUpgrade-initial-build.log`（有效首轮，覆盖了环境失败日志）、`/private/tmp/CosmosUIUpgrade-fixed-build.log`（修复后失败）。新增 16 方法只是源码静态计数，**本轮唯一测试执行数 0**；既有受影响类也未执行。未生成 xcresult 或 36 组合截图；截图测试代码中的目标 `/private/tmp/CosmosUIUpgrade-01a1267e/screenshots` 仅是计划路径，不能作为已生成证据。真实点击 / hover / 动效、窗口主题传播未覆盖。Swift 6 actor / Sendable 警告仍在（业务层既有警告与新增数据源捕获 / Workspace Codable 警告），不宣称已消除。
- 文档：更新 Current Status 的阻塞检查点 / 进行中模块 / UI 偏好 / 风险与后续主线程交付待办；更新 AGENTS §11 的已确认设计方向，§23 及其它章节保持字节不变；UI Design 仅追加状态说明，不改历史正文。
- 部署：未执行脚本；既有安装与回退副本均未触碰。当前模块没有业务 schema / 格式变更，但尚无新版回退或启动证据，不声称已部署。
- 可复用：交付数必须沿用既有交付候选检查，不用 Workflow 完成数代替；导航按源类型 + UUID + 活动归属交给原 UnifiedSearchNavigator；仅 UI 偏好使用 cosmos.ui.。后续步骤优先考虑 Projects、提示词与 AI 工作台套用组件，共享设计 token / 偏好 / 导航 / 外壳由单一负责人修改，集成与部署串行。

## 用户追加集中修复 — 导航复用既有 Store，验证及部署完成

- 用户授权处理导航架构、同轮编译与测试夹具问题。删除 CosmosWorkbenchDestinationView，CosmosNavigationSurfaces 仅保留知识库原页面接线，不创建卓望 Store。仪表盘 `.workbench(metric)` 写入 CosmosNavigator.pendingWorkbenchMetric 并设置侧栏 `.zhuowang`；DashboardView 始终构造原 ZhuowangWorkspaceView。工作台 onAppear / onChange 消费请求、清除原局部筛选、应用指标后清空待应用请求；指标点击使用同一 applyMetric，重复点击取消。
- ZhuowangWorkspaceView 仅增加 5 行：第 8 行 Environment；第 106 行初次出现时切 workbench；第 109–111 行监听待应用请求并调用原 selectNavigation(.workbench)。原 Store 初始化、内容、ScrollView 与业务数据流未改。隔离保护在工作台内部使用传入 Store 的配置：禁详情、默认交付计数注入 0；生产仍用原默认 DeliverableCounter。
- 编译诊断：父页面内三元闭包参数触发 ScrollView 歧义及 failed-to-produce-diagnostic，移回工作台内显式类型计算属性解决，父页面恢复原构造参数。最终 Debug build-for-testing 成功：/private/tmp/CosmosUIUpgrade-round-build.log；截图夹具更新后的最终构建亦成功：/private/tmp/CosmosUIUpgrade-offscreen-build.log。
- 测试身份为独立 Bundle ID；随机 Store suite 与七个临时根通过 xctestrun CommandLineArguments 注入。第一次临时 xctestrun 移出 Products 导致相对路径找不到产品（0 测试），放回 Products 后执行。集中测试 95 个唯一测试通过、0 失败：CoreBackup 12、CoreRestore 14、CosmosUIUpgrade 16、DashboardSnapshot 24、MacEnvironment 11、UnifiedSearch 10、ZhuowangCampaignWorkbench 8。结果 /private/tmp/CosmosUIUpgrade-isolated-tests.xcresult。
- 首轮离屏图的 List 不完整，改为挂接不显示的 NSWindow。中间夹具关闭窗口时异常退出，设置 isReleasedWhenClosed=false 后只重验截图方法，最终 1/1 通过（属于上述 95 个，不重复计数），结果 /private/tmp/CosmosUIUpgrade-offscreen-final.xcresult。合成来源 writeCount 为 0 断言通过；玻璃组指定系统前景色。
- 36 张 PNG：/private/tmp/CosmosUIUpgrade-01a1267e/screenshots；亲自查看四张 9 图联系表，浅 / 深 × 1180×760 / 900×620。检索分组、命中高亮、工作台选中态、指标换行、图表与空态可见；900 宽下 Dashboard 图表自动两列并可滚动。原生玻璃 / Settings 标签栏在位图中仍出现纯色块与低对比，无法作为实际窗口效果证据；不再为此搭建 UI 自动化或重复夹具。真实点击 / 悬停 / 动画、快捷键、跨窗口主题及面板 / 重启未覆盖。
- diff --check 通过；git diff --name-only 匹配 Store / FileStorage / CoreBackup / CoreRestore / CampaignProgress / WorkspaceFileManager 无结果。AGENTS 除 §11 外保持原文；Current Status 仍低于 40 KB。业务格式与交付 / 路径 / 并发隔离源文件未改，无正式业务数据测试。保留既有与新增 actor / Sendable 的 Swift 6 迁移警告，不扩大业务层修改。
- 部署：/usr/bin/python3 scripts/deploy-macos.py 成功；Universal Release arm64 / x86_64、ad-hoc 签名及安装身份按脚本核对。旧 App 正常退出，回退副本 Cosmos Toolbox-20261011-005043-613eac70.app。正式安装 /Users/rainiesmac-15/Applications/Cosmos Toolbox.app 已启动，PID 32087；Info.plist commit 93e25a86017040c07dbc648fe90c300ed37f396b，dirty=true。构建日志 /var/folders/fh/13jx00z13ln1d46vx35pgljc0000gn/T/CosmosOS-ReleaseDeploy-fls0mosm/build.log；部署输出 /private/tmp/CosmosUIUpgrade-deploy.log。本模块无业务格式变化，回退可恢复旧界面；历史 schema 降级风险仍保留。
- 本轮结论：可交用户体验验收。未 add / commit / push / merge；文档在部署确认后收尾，App 源码未再改动。下一步可复用组件至 Projects、提示词与 AI 工作台；共享设计 / 偏好 / 导航 / 外壳单一负责人，知识库接入另定范围。


## 体验升级第二步 A / B 串行集成 — 验证完成，进入部署

- 用户已实际体验并接受第一步范围。第一步提交 `b57d5aa1eaf3c3a424cb57f9b69bf7d08b00f1d5`（parent `93e25a86017040c07dbc648fe90c300ed37f396b`）按指定 19 文件提交并正常推送，main / origin/main / 远端 main 一致、0/0、正式目录干净。
- A 独立 worktree `/Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox-worktrees/step2a-pages`，分支 `feature/ui-upgrade-step2a`；22 文件（18 修改、4 新增）逐个暂存并提交 `7d783bb6689591b8433bd03e28b5ed592f8f5bbd`（`feat: 改版项目、AI 工作台、提示词库等页面并统一动效`），不推送。
- B 分支 `feature/knowledge-sources-step2b`，独立 worktree `/Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox-worktrees/step2b-knowledge`，本地提交 `c8d33499d9105b2324bcd158db50b10346b21936`。正式目录从干净 main 创建 `integration/ui-step2`；A 用 ff-only 合并，B 用 no-ff 合并，合并提交 `6ba3fb939321a190f2bb57e8b0973d4411afc2a7`，无冲突。main 始终保持 b57d5aa，两个 worktree / 分支保留，不删除、不 prune、不推送。
- A 页面改版：项目目标 / 下一步 / 进展卡片与模板上手、AI 活动 / 目标 / 预览三步引导与短复制反馈、紧凑工具状态、提示词三栏与变量模板、学习三态、Mac 分组 Gauge、笔记列表组件。模板只进入原生未保存编辑会话，不写库，用户显式保存才创建；原独立窗口与存储语义不变。
- 动效根因：原 DashboardView 在外层 ZStack 上 `.id(selection)` 会重建动画宿主；改为稳定外层宿主，仅内部目的地更换 identity。统一 opacity / scale 0.98 / blurReplace / offset 6，smooth 0.38s；卡片 32ms 错峰最多 8 张；选中侧栏 SF Symbol 单次 bounce；玻璃组 GlassEffectContainer / glassEffectID / matchedGeometry；分段指示 matchedGeometryEffect，指标 numericText，卡片悬停与按下反馈。所有新过渡遵循系统 / App 减少动效；页面进入可取消异步等待后调用原读取，不改变 Store 所有权和读取口径。API 已对当前 SDK 接口核实。A 单线 179 唯一测试通过与40截图为此前证据；本轮重跑受影响类，统计不累计历史执行次数。
- B 只读来源登记 schema 1：KnowledgeSources/sources.json、sources.backup.json、.sources.lock；1 MiB /32来源；索引仅内存，无新增业务 UserDefaults，不进核心 V3 备份。仅文本类读正文，附件列名称；除用户手动触发固定 `fetch origin` / `pull --ff-only` 外不写来源。来源登记与正文均不随备份，换机重新添加；旧 App 忽略新增登记文件，无害，既有 schema 降级风险仍保留。
- 共享接线提交 `02b7a099ee07bffe9cacfbe0269f9c14615cbcbe`（`feat: 接入我的知识库并完成第二步集成`）：DashboardHomeView 穷尽图标 case；CosmosNavigator 增加 sources；CosmosNavigationSurfaces 增加第三分段与 KnowledgeSourcesRootView；DashboardView resolve / 传递来源位置、精确打开 reader roots / blocked、监听 OpenCenter.pending 自动切页；UnifiedSearchView 接入来源 roots / blocked 并补标题 / 路径 / 标签的元数据口径。外壳按隔离配置或不可用登记位置显式禁用 Documents 建议目录（suggestedFolder:nil），避免测试宿主探测 ~/Documents。
- 新增 CosmosStep2IntegrationTests 两方法：挂载外壳后投递请求、切至 sources 并消费一次、不写合成业务源；集成离屏截图与来源正文 / 登记文件前后字节一致。测试代码只用 /private/tmp 合成根和随机 UI suite，不访问真实库，不在测试宿主中访问 Documents，不对真实知识库 fetch/pull，未使用 System Events，DEBUG 隔离未打开 Campaign 详情。
- Debug build-for-testing 成功：`/private/tmp/CosmosStep2Integration-initial-build.log`、`/private/tmp/CosmosStep2Integration-tests-build.log`。DerivedData `/private/tmp/CosmosStep2Integration-DerivedData`，Bundle ID `com.wangyucosmos.cosmostoolbox.persistenceui.Step2IntegrationTestHost`，唯一主进程 `CosmosStep2IntegrationTestHost`；xctestrun 注入随机业务 suite 与八个合规临时根，隔离缺失失败关闭。
- 集中串行验证 250/250 唯一测试通过：KnowledgeSource32、UnifiedSearch12、CosmosUIUpgrade16、CosmosStep2A9、Integration2、Projects12、DashboardSnapshot24、PersonalNotes24、PromptVaultState8、PromptVersionHistory14、LearningState23、AIHandoff15、TaskPreparation10、TaskReferences14、ToolProbe24、MacEnvironment11。结果 `/private/tmp/CosmosStep2Integration-tests.xcresult`、日志 `/private/tmp/CosmosStep2Integration-tests.log`。无核心测试失败，保留既有 Swift 6 actor / Sendable 警告。
- 一轮集中修复仅补新增离屏宿主的显式窗口背景，消除透明区域在位图里变黑的夹具问题；产品源码不变。修复后 build-for-testing 成功 `/private/tmp/CosmosStep2Integration-fixture-build.log`，只复测 Integration2/2 通过 `/private/tmp/CosmosStep2Integration-fixture-retest.xcresult`，不重复累计。A 的 ProjectsTests 旧V2/4根夹具已在A线对齐V3/5根，与V1固定来源 / 排除项；本轮Projects12/12通过，未改备份实现。
- 截图：`/private/tmp/CosmosStep2Integration-screenshots` 根目录18张（9状态×浅深色，1180×760）：知识库三分段 / 空来源、合成来源浏览和阅读、统一检索知识库文档、仪表盘、项目、AI；其下B目录13张阅读 / 原文 / 排除 / Git状态与窄窗；已亲自查看两张根目录联系表与B联系表，合成阅读及检索结果可见。A40张和第一步36张随受影响测试重生成，历史覆盖仍区分。暗色原生玻璃分段在离屏位图中低对比，不能证明实时合成 / 形变 / 帧率，需用户体验。长正文滚动属于设计行为。
- diff --check通过；逐文件核对所有 KnowledgeSource*.swift 与 B 的 UnifiedSearch Models / Reader / Navigation / Tests 与B原提交字节相同；业务 Store、存储/Workflow/Artifact/交付检查/路径、ZhuowangWorkspaceView与大页面、AGENTS未改。自查由实施工具完成，不称独立第三方复审。
- 文档：Current Status更新当前检查点、模块、来源存储 / 兼容 / 安全 / 技术债 / 非阻塞待办 / 分步美化状态，以及用户2026-10-10多公司工作区决定；仅Current Status与本日志改动，体积低于40KB。仪表盘主线程交付计数待办保留；token/secret误伤、.gitignore子集 / 只读来源根、Git判定仅来源根、FSEvents、独立阅读窗口、大列表分页均记录，不扩展实现。
- 部署：下一段执行授权的 `/usr/bin/python3 scripts/deploy-macos.py`；本段尚无Release/回退/启动结论，成功后追加实际结果。真实添加来源、真实点击、真实GitHub拉取与动态手感仍待用户体验，不能用合成测试替代。
- 可复用：共享接线由单一负责人修改；验证使用独立身份、临时根、串行测试与按方法去重；禁用隔离下Documents建议，避免权限弹窗卡住XCTest。用户体验接受后再单独授权main快进、推送和清理两个worktree，不自动进行第三步。


### 第二步部署实测与最终检查点

- 授权脚本 `/usr/bin/python3 scripts/deploy-macos.py` 执行成功，Universal Release（arm64 / x86_64）构建通过，ad-hoc 签名及安装身份按脚本核对。构建日志 `/var/folders/fh/13jx00z13ln1d46vx35pgljc0000gn/T/CosmosOS-ReleaseDeploy-ui5zf22d/build.log`；部署日志 `/private/tmp/CosmosStep2Integration-deploy.log`。
- 旧 App 正常退出（未强杀），回退副本 `~/Applications/Cosmos OS Rollbacks/Cosmos Toolbox-20261011-024243-b63b66a3.app`；正式位置 `/Users/rainiesmac-15/Applications/Cosmos Toolbox.app` 已启动，PID 40445。Info.plist 记录 `CosmosBuildCommit=e53f10ed8c94ce16f76fd3abb9dfe6303b0b6f0d`、`CosmosBuildDirty=false`、Release、版本1.0（构建1）。此为部署时文档提交；部署后只把实测补入同一份本地文档提交，App源码与接线提交02b7a09一致，无需重部署。
- 第二步未改已有业务数据格式；新增只有 KnowledgeSources 来源登记 schema1，第一步回退程序会忽略该文件，无害。旧程序不会因此重置已有业务库；本轮未以真实数据执行回退冒烟，已有提示词schema2与备份V3的历史降级限制仍适用。
- Current Status 已改为“第二步 A/B 已集成并部署，在 integration/ui-step2 等待用户体验验收；main未变”，低于40KB。文档之外未再修改文件，AGENTS及§23不动。
- 最终结论：可交用户体验第二步集成版本；没有合并冲突、构建或核心测试阻塞。250个唯一测试通过，集中夹具复测不重复计数。main / origin/main仍为b57d5aa；A为7d783bb，B为c8d3349，正式目录在integration/ui-step2；两个feature worktree保留且干净，无推送、无清理。第三步不自动开始。

- 第二步正式收尾：用户实际体验并接受声明的验收范围；main 从 b57d5aa 快进到 a0cd690 并正常推送，HEAD/main/origin/main/远端 main 一致、0/0、工作区干净；以非强制方式移除 step2a-pages、step2b-knowledge 两个 worktree，prune 后用 branch -d 删除 feature/ui-upgrade-step2a、feature/knowledge-sources-step2b、integration/ui-step2，并删除空父目录；指定 Word/PDF WIP 引用未变；本次仅更新验收文档，不重建、不测试、不部署，文档单独提交并正常推送。
