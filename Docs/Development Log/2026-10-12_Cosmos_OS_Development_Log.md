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
