# Cosmos OS Development Log — 2026-10-12

## 体验升级第三步 — C0 / A / B 串行集成与部署

- 开工自检：main=9a1afae、origin/main=f4cb257、A=71fb8ce（10 文件）、B=6d4a574（12 文件）；三个工作区干净，merge-base 为 C0，两线文件交集与禁改业务层 / Docs / AGENTS 文件为零。B 保留 C0 详情管理器注入，ZhuowangWorkflowConnections 供合成查询，生产 live Store 行为不变。
- 正式目录建立 integration/ui-step3；A ff-only，B no-ff，无冲突；合并提交 953467e6463870717ee8b6206afae95f5db5d525（merge: 合并活动详情窗口改版）。main 未移动，无 push，无 worktree / 分支删除。
- 首轮沙箱外原配置 Debug build-for-testing 成功：/private/tmp/CosmosStep3Integration-build.log。DerivedData /private/tmp/CosmosStep3Integration-DerivedData；测试 App 为唯一进程 CosmosStep3IntegrationIsolated、隔离 Bundle com.wangyucosmos.cosmostoolbox.persistenceui.Step3Integration、随机 UUID suite 和全部临时根。仅仓库外生成 xctestrun 夹具使用隔离 App；工程、scheme、xcconfig、仓库测试宿主配置未改。
- 首轮串行 296/296 通过：Isolation 4、Workspace UI 5、Detail UI 8、StoreBoundary 14、CampaignPersistence 13、WorkspacePersistence 13、Workbench 8、Delivery 15、Monthly 24、References 7、Review 27、Compare 15、Step05 30、Step06 12、HarnessBoundary 6、UnifiedSearch 12、KnowledgeSource 32、CosmosUIUpgrade 16、Step2A 9、Step2Integration 2、Dashboard 24。结果 /private/tmp/CosmosStep3Integration-tests.xcresult；日志同前缀 tests.log。
- 集中呈现修复：900 宽工作台固定表格撑宽右栏，scrollTo 后左侧裁切属实；overviewSection 用 ViewThatFits，宽空间保留原表格，窄空间用同数据 / 同动作紧凑行（保留采用冲突提示）。A 线玻璃控件标签按 colorScheme 明确前景色，修复深色离屏黑色标签；B 原生标签离屏仍有偏暗，按边界不改 B。
- 修复文件：ZhuowangCampaignWorkbenchView.swift（+35/-9）；ZhuowangWorkspaceView.swift、ZhuowangCampaignView.swift、ZhuowangAssetCenterView.swift、ZhuowangProvinceManagementView.swift（各 +3/-1）；ZhuowangWorkspaceUITests.swift（+82/-1）。新增一项集成截图 / 数据不变测试，合成工作文件与连接闭包。截图矩阵重复挂载需在每次 task 重发已消费的路由；此为截图夹具校正，不改路由业务行为。
- 复建成功 repair-build.log；受影响 UI6 + Workbench8 + Province18 + Asset15 = 47/47 通过（retest.xcresult）。校正路由夹具后仅重测新增项 1/1（fixture-build.log、fixture-retest.xcresult）。唯一总数 330：296 + 新增集成1 + 首轮未跑的 Province18 / Asset15；重复运行不累加。所有构建 / 测试使用上述同一前缀目录，无真实 Harness / Provider。
- 最终截图共126张：/private/tmp/CosmosStep3Integration-screenshots，A52、B54、Integrated20。A 与集成覆盖浅/深色、1180×760 / 900×620；B 另含最小宽等诊断截图。已亲自查看六张联系表及裁切 / 控件 / Workflow 原图；最终集成 Workflow 与产物截图重发路由后确实显示目标标签，补足 B 矩阵中已消费路由导致部分图回概览的证据缺口。集成覆盖导航、省份概览、活动卡片、详情头部与标签、Workflow 时间线、产物、交付包、月度清单。Review 实际 HTML 渲染、真实点击、保存面板、Finder、窗口复用 / 缩放、现场玻璃 / 动效未实测；离屏截图不是体验验收。
- 正式数据只经 shell 核对：Workspace14 文件路径 / 大小 / st_mtime_ns；正式 UserDefaults cosmos.zhuowang.* 全部现存5键（Data 精确字节 SHA-256；其他键缺失状态以键集合核对），验证前 / 后、部署后均一致。文件 /private/tmp/CosmosStep3Integration-before.json、after-tests.json、after-validation.json、after-deploy.json；不输出业务内容，不在 XCTest 宿主访问 Documents 或标准连接域。
- 呈现修复提交：1d1ce51513b2408fbce1349d3b01baf2dea6cbb6（fix: 第三步集成后的呈现修正）。A/B 源码以外的业务层、B文件、AGENTS改动为零；数据格式不变。
- 部署命令 /usr/bin/python3 scripts/deploy-macos.py；从干净修复提交构建 Universal Release，签名验证与双架构检查成功。旧 App 正常退出；安装 ~/Applications/Cosmos Toolbox.app，新版安装路径的正式进程正常启动（脚本确认）。回退副本：Cosmos Toolbox-20261012-001037-0bc8876a.app；部署日志 /private/tmp/CosmosStep3Integration-deploy.log。部署源码 HEAD=1d1ce51、dirty=false；状态文档在确认部署后记录实际结果，不提前宣称成功，本日志的文档提交不改变部署代码。
- 文档：只更新 Current Status（小于40KB）和本日新日志；记录第三步已集成部署待验收、main/origin 与保留 feature/worktree、UI 偏好 cosmos.ui.workspace.campaignLayout、有效工作文件隔离根下可开详情、可注入连接查询、当前采用最多5项/非标题栏标签、实机验收待办。既有 P1：打开详情会把拥有本地文件的步骤恢复为已确认（包括需修改 / 失败），本轮不改算法，单独评估。
- 当前可收尾为“工程集成与部署完成，体验待验收”。验收建议：缩到900宽看工作台与活动卡片；查看详情标签、启用步骤与采用版本；体验深色原生控件及减少动效。正式活动打开会触发既有恢复，不为验收改变采用、不运行 Provider / Harness。
- 可复用：唯一测试去重、每次挂载重发截图路由、窄宽 ViewThatFits、shell 文件清单和逐业务键 SHA-256 闸门；源码部署与文档记录明确区分。

## 第三步正式收尾（用户体验已接受）

- 验收代码 1cc1e12 快进 main、正常推送；fetch / ls-remote 核对 main=origin/main=远端 main、0/0、干净；删除干净的第三步两个 worktree、prune 与三个已合并分支，空父目录删除，两个 WIP 不动。只更新状态与本日志，不重复构建、测试或部署。


## 体验打磨轮（追加集中处理完成，待用户体验验收）

- P0 已完成：第三步验收代码快进并推送；收尾文档 fee48c5697c1ab34d74ed66692de110d05079d11 已推送，main/origin/main/远端核对一致、0/0；阶段分支与干净worktree清理，WIP保留。本轮不重做P0、不移动main、不推送。
- P1 基于现有36个未提交草稿继续，在 polish/ui-round4 单独开发。功能提交 c76319b4ca74541ff7058b6afc9f182b9c53cf29：feat: 体验打磨（图表、响应式布局、导航与性能），共42个源码/测试文件。本轮修复工作台3处旧日期调用；全仓旧Self.fullDate/Self.shortDate调用为零，生产UI直接格式化日期收口CosmosDate。保留数值count.formatted()、文件名时间戳、ISO序列化与历史/交接正文，不改格式或生成业务语义。
- 14项：横向细圆角条和数量/左侧省份标签；语义色Workflow环图与数量图例；图表内容区等高225pt；宽屏图表最多三列铺满行；阅读上限2200与自适应指标/项目卡；省份首字及模块白符号稳定方块；主窗口隐藏重复标题、紧凑primaryAction工具栏；设置独立底部行；统一主页面Header；骨架与轻淡入；未接入分类说明和替代入口（不新增分类）；AI五阶段折叠引导与复制后下一步。
- 卓望根因：侧栏条件销毁页面，重入默认工作台；外壳blur/scale/offset、内部目的地和卡片错峰叠加。现保留一个子树，离开隐藏，外壳纯淡入，抑制内部重复入场；记住省份/模块/分类，外部指标优先。隔离事件/五张采样帧：首次过渡87.816ms、appear89.046ms；重入过渡27.284ms；每次一个shell事件、内部selection0次，重入appear0次。采样包含位图成本，不作为显示器帧率或真实显示延迟。证据 /private/tmp/CosmosRound4-navigation-timing.txt、navigation-frames。
- Prompt根因：页面重建Store和全库重读，固定等待380ms、重复过滤/全库变量解析、历史行提前创建。文件读取/解码原已在专用队列；未把它误报为主线程读取。外壳持有稳定会话；首次loadIfNeeded、手动刷新仍可用；页面离开仍清理变量。schema2、revision重读冲突、事务、窗口草稿、历史恢复保护均未改。新增测试证明外部磁盘更新不覆盖草稿；缓存显示快照可能外部过期，需手动刷新。
- 完整路径实测：冻结main原PromptVaultView/ViewModel于测试目标，重现普通动效380ms等待；同一120模板/4800版本约8MiB合成库，实际900×620完整页面NSHostingView+缓存位图。原冷/新冷/新暖：首帧131.199/49.301/45.054ms；真实列表帧1014.896/455.023/315.405ms；Store创建0.370/0.237/复用；读取6.238/1.098/无；解码校验139.715/117.995/无；宿主构造初布局67.416/21.109/14.227ms。分类每次约0.004–0.079ms，所选历史处理0.015–0.031ms。主线程可观察到数据666.763→294.104ms，暖已有数据。另一个独立同夹具实测协调16.347→0.187ms、storage.reload约118ms同量级。最大额外开销为固定等待和SwiftUI布局/位图缓存；新页冷暖先显示骨架，布局仍有成本。并发/重复渲染阶段不可简单相加；cacheDisplay与PNG编码在计时内，不等于Release显示器首帧/正式库用户体感。证据 /private/tmp/CosmosRound4-full-route-timing.txt，perf-before/after.log。
- 计时类/调用仅#if DEBUG；原页面基线仅测试目标，不加入Release启动参数。发布二进制nm核对无CosmosExperienceTrace/CosmosLegacyPrompt诊断符号。PromptVaultFileStorage仅新增DEBUG计时，不改变路径、校验、队列或写入事务。
- AI行为变化：每次App运行首次AI页自动一次既有--version探测；离开取消后不自动重试，需手动刷新；首页仍不检测。折叠状态仅cosmos.ui.aiWorkspace.guideCollapsed；提示词生成、资料上限、历史交接语义保持。
- 沙箱外原工程/原scheme Debug build-for-testing通过，不改工程、scheme、xcconfig或仓库宿主配置。唯一App/进程、随机suite与全部临时根，仓库外xctestrun。首次389项中387通过，两项新增夹具缺少Provider元数据导致原有默认初始化写入；已在setup初始化后取基线，没有修改业务算法。集中修复另含宽屏图表空列、首帧骨架、暗色标签。受影响复验105/105，通过；深色空状态共享标签最后局部17/17通过。合并按唯一方法去重389/389，不重复累加。
- 结果 /private/tmp/CosmosRound4-tests-extra.xcresult、tests-final.xcresult、tests-glass.xcresult；Debug日志build-extra-fixture.log、build-final.log、build-glass.log。日志/结果都在仓库外。测试未读取Documents或标准连接Store，未运行真实Provider/Harness。
- 最终54张页面PNG：/private/tmp/CosmosRound4-screenshots，七页三尺寸浅深42张+分类6张+外壳6张；另5张导航采样帧。已亲自查看六张联系表和图表/Prompt/AI/导航原图；图表等高、三尺寸布局和深色标签已检查。AppKit主侧栏/标题栏在离屏缓存中未完整绘制；真实点击、短窗口设置、原生toolbar/窗口缩放、现场玻璃、帧率仍需用户实机验收，不把截图当成实际交互验收。
- 正式数据shell清单：14文件路径/大小/mtime_ns；5现存cosmos.zhuowang业务键逐键SHA256。round4-before、extra-before、after-tests、final-validation、after-deploy.json完全一致；不输出业务正文。数据格式不变，没有迁移或恢复/采用算法修改。
- 原脚本 /usr/bin/python3 scripts/deploy-macos.py：从干净c76319b构建Universal Release，签名和双架构检查通过，旧App正常退出（或未运行），脚本确认新版安装路径启动，PID58554。回退副本 Cosmos Toolbox-20261012-005631-a7085e88.app；部署日志 /private/tmp/CosmosRound4-deploy.log；安装Info.plist确认commit=c76319b、dirty=false、Release。文档在部署后记录，不改变部署代码。
- 只更新Current Status与本日志，不改AGENTS，不写其他知识库。当前可收尾为实现/工程验证/部署完成，待用户体验验收。下一模块候选：卓望分类内容接入；既有打开详情会把有本地文件的失败/需修改步骤恢复为已确认的P1风险保留。
- 可复用：稳定页面/Store身份、一个外壳过渡、先出骨架的完整路径计时、同夹具前后比较、唯一测试去重与shell逐业务键完整性闸门。避免把缓存位图计时或默认元数据夹具初始化当作真实UI验收/业务回归。

本轮源码/测试文件：
- Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceHandoffHistoryView.swift
- Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceModels.swift
- Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceTaskPreparationView.swift
- Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceView.swift
- Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceViewModel.swift
- Apps/CosmosOS/Cosmos Toolbox/ArtifactReviewWorkspace.swift
- Apps/CosmosOS/Cosmos Toolbox/CampaignReferencesView.swift
- Apps/CosmosOS/Cosmos Toolbox/CoreRestoreView.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosDesignComponents.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosDesignSystem.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosNavigator.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosPageMotion.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosWorkspaceUI.swift
- Apps/CosmosOS/Cosmos Toolbox/DashboardHomeSnapshot.swift
- Apps/CosmosOS/Cosmos Toolbox/DashboardHomeView.swift
- Apps/CosmosOS/Cosmos Toolbox/DashboardSnapshot.swift
- Apps/CosmosOS/Cosmos Toolbox/DashboardView.swift
- Apps/CosmosOS/Cosmos Toolbox/KnowledgeSourceReaderView.swift
- Apps/CosmosOS/Cosmos Toolbox/KnowledgeSourceViews.swift
- Apps/CosmosOS/Cosmos Toolbox/LearningCenterView.swift
- Apps/CosmosOS/Cosmos Toolbox/MacEnvironmentView.swift
- Apps/CosmosOS/Cosmos Toolbox/PersonalNotesEditor.swift
- Apps/CosmosOS/Cosmos Toolbox/PersonalNotesView.swift
- Apps/CosmosOS/Cosmos Toolbox/ProjectsEditor.swift
- Apps/CosmosOS/Cosmos Toolbox/ProjectsView.swift
- Apps/CosmosOS/Cosmos Toolbox/PromptVaultFileStorage.swift
- Apps/CosmosOS/Cosmos Toolbox/PromptVaultView.swift
- Apps/CosmosOS/Cosmos Toolbox/PromptVaultViewModel.swift
- Apps/CosmosOS/Cosmos Toolbox/UnifiedSearchView.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignDetailUIComponents.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignDetailView.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignView.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignWorkbenchView.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangCategoryContentView.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangMonthlyChecklistView.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkspaceUI.swift
- Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkspaceView.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosExperienceTrace.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosExperienceUI.swift
- Apps/CosmosOS/Cosmos Toolbox/CosmosPromptSession.swift
- Apps/CosmosOS/Cosmos ToolboxTests/CosmosExperiencePolishTests.swift
- Apps/CosmosOS/Cosmos ToolboxTests/CosmosLegacyPromptBenchmark.swift


## 体验验收修正：统一页面切换与侧栏选中（be4b6f6）

- 基线 polish/ui-round4 @8255064，工作区干净；main/origin/main 均 fee48c5，未移动、未推送。
- 问题1根因实测：检索自动聚焦文本框，List非活跃选择变灰。行内部统一强调色背景，保留原生List选择、悬停、箭头键与AX selected；不取消自动焦点。浅/深焦点前后蓝色像素测试通过；Release实机验证焦点/蓝色选中、项目→Down知识库→Up项目、侧栏隐藏/显示。
- 问题2根因：原重建分支opacity transition与保留卓望opacity隐藏并行。统一内容替换无插入/退出动画，外层稳定容器以同一CosmosDesign token淡入；减少动效降级。Store持有位置与身份未改变，各页既有reload/task/cancel、Prompt首次加载及手动刷新、卓望共享Store发布刷新保持原样。
- 9页72对有向互切均1次fade begin与commit、0次shell host appear/disappear、0次workspace selection；保留工作区没有再次appear。矩阵 /private/tmp/CosmosAcceptance-matrix/matrix.csv。事件测量的是实际外壳动画事务和宿主生命周期，未声称离屏动画完成回调或显示器每帧均已验收。
- 问题3：旧titleVisibility仅隐藏AppKit标题，未移除SwiftUI默认toolbar标题；SDK确认toolbar(removing: .title)后接入。真实部署截图 /private/tmp/CosmosAcceptance-deployed-search.png，安装路径唯一PID61194、唯一窗口30268；重复标题消失，侧栏开合正常。系统采集胶囊遮挡红绿灯，CUA无障碍树可见原生关闭/最小化/全屏控件，直接位置核对缺口保留；独立Swift AX查询不可用，未重试或修改系统权限。
- 检索胶囊与两个筛选开关分行；胶囊横向滚动带渐隐，工具栏用紧凑图标。D复查发现嵌套HSplitView仍按最小尺寸扩张，改为按实际宽度分配二级分栏（不再支持分隔线拖宽）；AI工具横向滚动补渐隐。114张离屏截图覆盖900×620、1180×760、1440×900、2560×1440浅/深；900九页、其余宽度检索/项目/卓望/知识库带主侧栏，未见右侧溢出。截图 /private/tmp/CosmosAcceptance-screenshots，原生List离屏绘制缺口由真实窗口补充。
- Debug测试构建、Universal Release通过。串行111项唯一测试最终通过。首轮新矩阵测试失败源于未上屏动画完成回调与缺失Workspace初始化夹具；同轮集中修复改为动画事务提交计数、预置默认数据；未改业务Store、schema、恢复/采用、Provider/Harness、工程/scheme/xcconfig/测试宿主配置。相关复验见 /private/tmp/CosmosAcceptance-{tests,repair-tests,layout-tests}.log。
- shell快照：/private/tmp/CosmosStep3Integration-acceptance-{before,after-tests,after-deploy}.json；14工作文件路径/大小/mtime_ns、5业务键逐键SHA-256完全一致。无数据格式变化。
- 逐文件提交 fix: 统一页面切换与侧栏选中样式 @be4b6f69662cc8be67d43ca5535c9227a1c532ad（6文件）。原deploy-macos.py正常退出旧App、保留回退并启动新版Release dirty=false；回退 Cosmos Toolbox-20261012-012808-72175c3c.app；部署日志 /private/tmp/CosmosAcceptance-deploy.log。
- 修改：DashboardView.swift、CosmosExperienceUI.swift、UnifiedSearchView.swift、AIWorkspaceView.swift、ZhuowangWorkspaceView.swift、CosmosExperiencePolishTests.swift；正式文档仅Current Status与本日志。代码与文档本地提交，等待用户体验验收；无额外worktree，无push。


## 恢复原生选中与分栏：阶段部署及阻塞（5c37008）

- 基线 polish/ui-round4 @b864e29，工作区干净。main/origin/main fee48c5未移动、不推送；未新增worktree。
- A：删除CosmosSidebarSelection与额外行padding；List原生选择/焦点/AX行为恢复。导航内存新增显式搜索焦点请求，侧栏点击清除请求；⌘F、Dashboard search(空串)、携带关键词search申请焦点。占位提示“按⌘F开始搜索”。
- B：卓望恢复HSplitView，二级名lineLimit(1)/tail；目标宽度220–360，默认260，cosmos.ui.workspace.sidebarWidth只存UI偏好。观察原生split resize保存，未替换SwiftUI委托或业务Store；GeometryReader明确约束实际宽度并为内容留最小320。初版原生分栏离屏仍溢出，同轮集中修复后900/1440/2560浅深图边界正常。真实满宽窗口“推进工作台”仍有省略，不能宣称所有名称完整显示；未完成真实拖动光标、宽度持久化复核。
- 灰竖条根因：修复前真实AX树标识为scroll bar，截图可见圆角滑块；不是Divider。系统AppleShowScrollBars=Automatic，源码无强制常显。窄栏多行增高内容，滑块接近全高。保留系统策略，分隔线恢复原生thin（夹具dividerThickness<=1通过），不强制隐藏滚动条。
- C：Projects空状态原CosmosEmptyState至少130pt并居中，加padding制造大片间距；改为紧凑Label、说明和模板，控件下紧接；只改呈现。
- D：Prompt现有HSplit保留，分类/模板名称单行省略；学习列表原已单行，原生HSplit保留；我的知识库固定HStack/Divider改为HSplitView（窄窗两栏、宽窗三栏），有fixture截图。真实其它分栏拖动/光标仍未核实。
- 页面切换修复未改。72有向互切复跑两次均1次fade begin/commit、0外壳额外挂载、0卓望二次选中；/private/tmp/CosmosNativeAcceptance-matrix/matrix.csv。
- Debug构建通过；首轮108唯一测试通过，同轮分栏修复复验通过。138张离屏图 /private/tmp/CosmosNativeAcceptance-screenshots，重点浅/深图已查看。阶段逐文件提交 fix: 恢复原生侧栏选中并修复卓望二级栏宽度 @5c37008651c5c79696f8c53c8ae033ae865c0f46，11源码/测试文件。
- 原脚本Release构建、正常退出旧App、安装启动成功。PID65938、唯一窗口31379（安装路径校验），回退 Cosmos Toolbox-20261012-093816-9fb0695e.app。真实截图 /private/tmp/CosmosNative-deployed-search-sidebar.png 与 -command.png；侧栏进入不聚焦、原生单层蓝色正确；⌘F first responder为检索框。
- 阻塞：实机Dashboard快捷进入未成功聚焦。补充focus挂载时序尝试（Task.yield，未改切换），并把fixture窗口改为titled/key、加入native firstResponder断言。最后13项复验：UnifiedSearch12项通过；焦点测试1项失败（2断言）：事件247行出现了不期望的search.focus.true，251行请求后未收到新的focus.true；252行原生fieldEditor断言本身通过。带key的直接搜索宿主可能自动选首个textfield，夹具/真实入口时序需下一轮一起排查。停止继续修复/部署，未宣称完成。
- 停止时未提交2文件：UnifiedSearchView.swift、CosmosExperiencePolishTests.swift。保留尝试，不重置、不清理；当前安装仍阶段5c37008，未部署这些尝试。
- shell快照 /private/tmp/CosmosStep3Integration-native-{before,after-tests,stopped}.json：14工作文件path/size/mtime_ns及5业务键SHA-256完全一致。无格式/存储/Workflow/恢复算法变化；未运行Provider或Harness。
- 修改文件：CosmosExperienceUI.swift、CosmosNavigator.swift、CosmosUIPreferences.swift、CosmosWorkspaceUI.swift、DashboardView.swift、KnowledgeSourceViews.swift、ProjectsView.swift、PromptVaultView.swift、UnifiedSearchView.swift、ZhuowangWorkspaceView.swift、CosmosExperiencePolishTests.swift；正式文档仅Current Status与本日志。未改工程、scheme、xcconfig或仓库测试宿主配置。


## 本轮收口：检索聚焦与动态二级栏宽度（1e09b1c）

- 用户追加一轮集中收口，基线 polish/ui-round4 @e9ef4f3，两个未提交焦点尝试文件符合交接；按授权 git restore --source=e9ef4f3 恢复 UnifiedSearchView.swift 与 CosmosExperiencePolishTests.swift，不使用 reset/clean/stash。
- 用户明确取消仪表盘快捷进入检索自动聚焦，属于需求调整，不是削弱测试。空白关键词导航与侧栏进入均不主动聚焦，保留页面“按⌘F开始搜索”、⌘F聚焦；非空关键词跳转仍预填并沿用既有焦点实现，不再调时序。
- 卓望最小栏宽由实际最长行计算：当前文字大小字体、名称（以选中semibold测量）、图标、计数徽标、注意点、内边距和系统滚动条占位。渲染与测量使用同一字体；旧保存宽度低于新下限时按下限显示，常规上限360pt，必要下限优先。原生分栏拖动观察与页面切换修复不改。
- 源码/测试四文件：CosmosNavigator.swift、CosmosWorkspaceUI.swift、ZhuowangWorkspaceView.swift、CosmosExperiencePolishTests.swift；逐文件提交 `fix: 收口统一检索聚焦与卓望二级栏宽度` @1e09b1c7c08f70d147730182b680a3ac71247d33。UnifiedSearchView.swift恢复后无diff。
- Debug build-for-testing通过。串行23个唯一测试通过：ExperiencePolish受影响5项、UnifiedSearch12项、WorkspaceUI6项。保留侧栏不聚焦、命令聚焦断言，空白快捷入口预期为不聚焦；新增动态下限、文字大小、长名称、徽标、旧偏好与上限验证。
- 72对有向切换均 fade_begin=1、fade_commit=1、host_remount=0、workspace_second_selection=0，页面切换代码未动。矩阵 /private/tmp/CosmosCloseAcceptance-matrix/matrix.csv；测试日志 /private/tmp/CosmosClose-tests.log。
- 8张离屏图（900/1440宽 × 浅/深 × 标准/特大文字）已查看，推进工作台等名称完整单行、900宽无右侧溢出。目录 /private/tmp/CosmosClose-workspace-screenshots，拼图 /private/tmp/CosmosClose-workspace-review.png。离屏图不证明真实拖动光标与重启宽度记忆，这两项按用户要求列为待用户体验验收，不继续工具尝试。
- 原deploy-macos.py沙箱外构建Universal Release成功，正常退出旧App、保留回退并启动安装路径新版；源码1e09b1c，dirty=false，PID71068。回退 Cosmos Toolbox-20261012-101228-3221e7d2.app；日志 /private/tmp/CosmosClose-deploy.log。未修改工程、scheme、xcconfig或仓库测试宿主配置。
- 正式数据shell快照 close-before、close-after-tests、close-after-deploy：14工作文件path/size/mtime_ns及5个卓望业务键SHA-256完全一致。证据 /private/tmp/CosmosStep3Integration-close-*.json；无数据格式变化，不改业务Store/Workflow/恢复/采用，不运行Provider/Harness。
- 正式文档只更新Current Status与本日志，保留历史失败记录并消除当前阻塞描述。main/origin/main仍fee48c5，不移动、不推送、不删除分支/worktree。本轮可工程收口，等待用户体验验收。

- 正式收尾：用户已体验验收体验打磨轮并接受声明范围；开工polish/ui-round4 @bb722d2、干净、main/origin/main fee48c5且唯一正式worktree；main快进至bb722d2并正常推送，ls-remote一致、0/0、干净，git branch -d安全删除polish/ui-round4；未触碰两个指定WIP分支。下一步Mac版原生化改造（依据Claude Code原生化审计报告），之后卓望分类内容接入。此次只更新Current Status与本日志并以“docs: 记录体验打磨轮验收与合并”提交推送，不重新构建、部署或测试。


## Mac 原生化第一批 1.1–1.6（Codex 主开发 / 唯一部署负责人）

- 开工基线：main / 本地 origin/main / HEAD = 515c7955b76c56f200e4de75ff09ea9b297f1b4c，干净、唯一正式 worktree。保留本地 Word WIP 与远端 PDF WIP。创建 native/batch1；Git .git 写操作需要沙箱外权限，本轮不 push / merge / prune。未修改 Claude 窗口工厂文件或其 worktree。
- 审计入库：找到 /private/tmp/CosmosNativeAudit-report.md，原样复制到 Docs/Reviews/2026-10-12_Mac原生化审计.md，只加来源路径 / e9ef4f3 头；正文逐字节核对相同。实施以 515c795 实际代码为准，统筹 1.6 对系统动效的最新决定优先于旧审计的不使用 scrollTransition 建议。
- 1.1：删除 CosmosGlassToolbarGroup（源码与 benchmark 12 处定义 / 使用）；10 页相关动作改 ToolbarItem / ToolbarItemGroup，仪表盘主操作与刷新用 ToolbarSpacer 分组。设置、仪表盘、来源页、卓望原在内容中的动作移到系统 toolbar，其他页拆除嵌套组；系统默认按钮材质，不再叠加玻璃。外壳下传 cosmosPageToolbarVisible = selection == .zhuowang，保留工作区身份与 ZStack；共享 cosmosGlassNamespace / pageGlass 无其他使用者，一并删。
- 1.2：59 个显式玻璃按钮样式（19文件；含原工具栏 3 处）：内容改 bordered / borderedProminent，原工具栏用默认样式；11 个黑白字色覆盖及 2 个 primary 强制覆盖删除。实际逐文件数量见下表。显式玻璃白名单仅 KnowledgeSourcesRootView 底部 toast：真实浮在内容上方的只读消息，不加可点击 interactive；置于 GlassEffectContainer，以 glassEffectID / matchedGeometry 形变，减少动效用 identity；工具栏由系统提供玻璃，不写 glassEffect。
- 1.3：五套自绘分段（AI 工作台、Projects、知识库分区、卓望工作分类、活动详情标签）换 Picker(.segmented)。保留原 Binding / 选项值、分类选择清理 assetDestination、isEditing 禁用、UI 偏好键及持久化逻辑；活动详情标签仍在内容区，挪入窗口 toolbar 留第三批。删除 CosmosSegmentedControl / CampaignUISegmentedTabs / sectionButton / tab 绘制实现，CampaignUITabItem 作为数据项保留。
- 1.4：CosmosEmptyState 保留签名，以 ContentUnavailableView label / description / actions 薄包装；KnowledgeHubView 搜索命中 PersonalNotesTests.swift:715 的实际渲染测试，因此按提示词保留，未伪称无引用。
- 1.5：CosmosDesign.surface=controlBackgroundColor、surfaceRadius=14；卡片样式、交互卡片、CosmosContentPanel、campaignUICardSurface 共用语义填充，去装饰描边 / 阴影 / 悬停缩放位移（键盘焦点轮廓保留）。删除 CosmosEntrance / campaignUIEntrance 两套实现与 28 次调用、entranceDelay / interval / limit、sidebarPulse 与 bounce；保留图表、时间线、进度环、产物与状态组件及轻背景 hover。没有修改业务 Store、schema、路径、恢复 / 采用 / 交付算法或渲染器 / 安全策略。
- 1.6：33 个 ScrollView 的 soft top edge；31 个网格 / 卡片 / 行挂载系统 scrollTransition（opacity 0.82、scale 0.98、y 4，仅非 identity，减少动效全为原样）；共享指标数字使用 numericText 与已存在的 value 动画，覆盖仪表盘 / 卓望工作台；4 处图标替换调用（笔记收藏、任务准备完成、省份启停、Workflow 状态）遵循减少动效；仪表盘 / Mac 正在刷新 rotate、AI 正在检测 pulse，静止时关闭。暂无头图 / 大色块，不加 backgroundExtensionEffect；五套选择已全部原生，没有剩余自绘滑块需要 matchedGeometry。未使用 macOS 不可用 API。
- 集中验证：沙箱外 Xcode27、macOS27SDK；原工程 / Cosmos Toolbox scheme、Debug、CODE_SIGNING_ALLOWED=NO、独立 DerivedData /private/tmp/CosmosDD-batch1-dd1104c9-718e-4771-b72f-bbef521fda33、Bundle ID com.wangyucosmos.cosmostoolbox.persistenceui.NativeBatch1。首轮 parse 失败（设置 toolbar 的 help 接在 if 块外），唯一集中修复移到 Button 上，并清理无关业务文件尾空行。受影响复建 build-for-testing 成功 /private/tmp/CosmosNativeBatch1-repair-build.log。全量 test-without-building 仅一次，641 唯一测试全部通过，0失败，/private/tmp/CosmosNativeBatch1-tests.xcresult、tests.log；不按重复输出累加。
- 隔离：生成 xctestrun 注入随机 suite 与 workspace-files / prompt / learning / handoff / projects / notes / sources / restore / assets 九个 UUID 临时根，C0失败关闭；不运行真实 Provider / Harness，不从 XCTest 访问正式 Documents / 业务域，不按同名 App 使用 System Events。保留隔离配置 /private/tmp/CosmosNativeBatch1-isolation.json。
- 72 对有向页面互切一次：1 fade_begin、1 fade_commit、0 host_remount、0 workspace_second_selection；原生 NSHostingController sceneBridgingOptions 只加在矩阵夹具，不改生产 10 个窗口创建点。NSToolbar 实际项名检查：卓望选中有且仅有1个“管理工作区”，其他页面0。/private/tmp/CosmosNativeBatch1-matrix/matrix.csv。
- 新增 / 调整测试只涉及空状态映射渲染、系统 segmented 实际 NSSegmentedControl action 更新知识库 Binding、减少动效及工具栏显隐；既有 preference roundtrip / 数据保护测试本轮沿用全量执行。未改 Prompt init / StateObject 身份和检索焦点逻辑。
- 静态 rg：CosmosGlassToolbarGroup=0；CosmosEntrance / entranceDelay=0；symbolEffect(.bounce)=0；CosmosSegmentedControl / CampaignUISegmentedTabs / sectionButton / tab=0；buttonStyle(.glass…)=0；foregroundStyle/foregroundColor 强制 white / black / primary=0。白名单显式 glassEffect 仅知识库 toast。证据 /private/tmp/CosmosNativeBatch1-static.json；git diff --check 通过。没有新建窗口工厂文件。
- 离屏截图：本轮既有隔离夹具输出中选取仪表盘、卓望省份概览、提示词库、设置数据页、活动详情概览各浅 / 深1张，共10张，亲自逐张查看，正文可读、系统按钮与分段可见。/private/tmp/CosmosNativeBatch1-screenshots/{dashboard,workspace,prompts,settings,campaign-detail}-{light,dark}.png；manifest含来源 / 本轮mtime / SHA-256。同步提示词夹具“data”图仍为loading，使用现有 async 夹具内容就绪图；不重复测试。设置 TabView 标签胶囊离屏显示纯黑 / 白，toolbar与标题栏、玻璃、动效不在截图验收范围，不据此判断实机缺陷。指标卡采用系统填充后浅色分界较轻，实机观感由用户验收。
- 正式数据仅 shell 读取：Workspace14文件路径 / size / st_mtime_ns 与 defaults export 正式域的5个现存业务主键 Data精确字节SHA-256，before / after-tests 完全一致。直接读取磁盘plist和偏好服务导出不同，权威闸门沿用历史 defaults export，不把差异归因于本轮数据变更。证据 /private/tmp/CosmosNativeBatch1-{before,after-tests}.json；不输出正文 / 凭据。
- 部署：准备在已提交、工作区干净的 native/batch1 执行原 /usr/bin/python3 scripts/deploy-macos.py；实际结果 / 回退名将在下一条追加记录。无强杀、推送或合并授权。
- 后续：用户实机逐页检查工具栏默认玻璃 / 分组、滚动边缘与滚动入场、指标变化、图标形变、忙碌效果、减少动效开关与深浅色。第二批窗口与sheet原生化另定范围；KnowledgeHubView仍有测试引用、离屏设置标签缺口与既有Swift6隔离警告列非阻塞待办，不扩大修复。
- 可复用：原生工具栏需条件显隐适配保留实例；NSSegmentedControl action 可验证真实绑定；defaults export 而非磁盘plist用于业务指纹；截图挑选异步内容就绪夹具；用户偏好保持“原生 + 精选华丽”。

### 本轮显式玻璃按钮替换数量（原工具栏回到默认，内容回到 bordered）

| 文件 | 原数量 | 新显式 glass 数量 |
|---|---:|---:|
| AIWorkspaceTaskPreparationView.swift | 3 | 0 |
| ArtifactReviewWorkspace.swift | 2 | 0 |
| ArtifactVersionCompareWorkspace.swift | 1 | 0 |
| CampaignReferencesView.swift | 6 | 0 |
| CosmosDesignComponents.swift | 1 | 0 |
| DashboardHomeView.swift | 1 | 0 |
| KnowledgeSourceReaderView.swift | 1 | 0 |
| KnowledgeSourceViews.swift | 3 | 0 |
| UnifiedSearchView.swift | 3 | 0 |
| ZhuowangAIExecutionResultView.swift | 10 | 0 |
| ZhuowangArtifactDeliveryPackageView.swift | 3 | 0 |
| ZhuowangAssetCenterView.swift | 1 | 0 |
| ZhuowangCampaignDetailView.swift | 14 | 0 |
| ZhuowangCampaignView.swift | 1 | 0 |
| ZhuowangProvinceManagementView.swift | 1 | 0 |
| ZhuowangTaskPackagePreviewView.swift | 4 | 0 |
| ZhuowangWorkflowUITimeline.swift | 1 | 0 |
| ZhuowangWorkflowView.swift | 1 | 0 |
| ZhuowangWorkspaceUI.swift | 2 | 0 |

### 本轮全部修改文件（UI与测试）

- `Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceHandoffHistoryView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceTaskPreparationView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceTaskReferencesView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/AIWorkspaceView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactReviewWorkspace.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactVersionCompareWorkspace.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CampaignReferencesView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CoreBackupSettingsView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CoreRestoreStartupView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CosmosDesignComponents.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CosmosDesignSystem.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CosmosNavigationSurfaces.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CosmosPageMotion.swift`
- `Apps/CosmosOS/Cosmos Toolbox/CosmosSettingsView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/DashboardHomeView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/DashboardView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/KnowledgeSourceReaderView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/KnowledgeSourceViews.swift`
- `Apps/CosmosOS/Cosmos Toolbox/LearningCenterView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/MacEnvironmentView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/PersonalNotesEditor.swift`
- `Apps/CosmosOS/Cosmos Toolbox/PersonalNotesView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ProjectsEditor.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ProjectsView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/PromptVaultView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/UnifiedSearchView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAIExecutionResultView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangArtifactDeliveryPackageView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAssetCenterView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAssetDetailView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignDetailUIComponents.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignDetailView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignWorkbenchView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangMonthlyChecklistView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangProvinceManagementView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangTaskPackagePreviewView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowUITimeline.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkspaceUI.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkspaceView.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/CosmosExperiencePolishTests.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/CosmosLegacyPromptBenchmark.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/CosmosStep2ATests.swift`

文档：`Docs/Reviews/2026-10-12_Mac原生化审计.md`、`Docs/07_Cosmos_OS_Current_Status.md`、本当日日志；按 §23 不重复维护 PROJECT_BRIEF / PAGE_MAP / DATA_MAP / CHANGELOG。
