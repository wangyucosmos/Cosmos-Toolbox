# 2026-10-13 Cosmos OS Development Log

## Mac 原生化第二批验收与 main 收尾（仅 Git / 文档 / 清理）

- 用户已实机体验部署版217120f，接受声明验收范围，授权快进main、两份文档提交与正常推送，以及推送确认后移除干净window-factory worktree和用-d删除三个已合并分支。不改代码、不构建、不测试、不部署；沿用第二批669唯一测试/72对矩阵与正式数据指纹证据，不追加验收。
- 基线实测：正式目录native/batch2=2617433ddb6dc1559610e35b8003b7262013f6c0且工作区干净；main/origin/main=8d4107fa0eda682f033e440bdbebb298d8ba5d58；git ls-remote origin refs/heads/main确认远端仍为8d4107f。三个merge-base --is-ancestor检查成功：main、native/batch2-windows=4f61f25caad78601ee7969b605c387ebfbc3ca4e、native/window-factory=0bfff23706f3cd8bab9fa47a81ab23cfdeb9a8e9均包含于native/batch2。
- /Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox-window-factory检出native/batch2-windows；git -C status --porcelain --untracked-files=all为空，无未跟踪文件，符合安全清理前提。Word本地WIP与PDF远端WIP保留。
- git switch main与git merge --ff-only native/batch2成功，main从8d4107f快进到2617433，无新增合并提交。更新Current Status §1/§3/§12，§9现有非阻塞待办原样保留；第三批3.1详情toolbar、3.2 List(.sidebar)、3.3个人笔记/知识库，3.4统一检索.searchable继续延后，本轮不启动。
- 部署二进制保持217120f，回退副本Cosmos Toolbox-20261012-213020-7e4b6733.app不动；本次文档不重新部署，不修改其他项目文档或外部知识库。逐文件add，验收文档提交信息“docs: 记录Mac原生化第二批验收与合并”。
- 推送/清理执行协议：先正常git push origin main，再ls-remote确认远端与本地HEAD一致、main...origin/main领先/落后0/0；只有确认后才worktree remove（无force）与依次branch -d native/batch2、native/batch2-windows、native/window-factory。任一步被拒绝立即停止，不改用rm/prune/-D/reset/clean/stash/force。下段将在实际执行后追加结果，不把协议当成成功证据。
- 可复用：用户接受范围后只沿用既有验证；worktree先确认干净与分支已包含，再在远端推送确认之后安全移除和删除分支。


### 推送与清理实际结果

- 验收文档提交a7e66fae498292b2d322c3accd2cbcaf843d1914完成；git push origin main成功（8d4107f→a7e66fa），随后git ls-remote实际返回a7e66fa refs/heads/main，与本地main一致；main...origin/main为0/0，工作区干净。清理前再次核对远端与worktree干净，全部通过。
- git worktree remove /Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox-window-factory成功（未使用--force）；随后依次git branch -d native/batch2、native/batch2-windows、native/window-factory全部成功（删除前分别2617433、4f61f25、0bfff23）。无rm/prune/-D操作。
- git worktree list仅剩正式目录/Users/rainiesmac-15/Documents/GitHub/Cosmos-Toolbox [main]。本地保留main与wip/markdown-word-export-phase1-20260930=2d26b2a；origin/wip/pdf-renderer-phase1-20260902保留且未触碰。
- Current Status为38,403字节（≤40KB），§9非阻塞待办保留原文；部署版217120f及回退副本保持。本次未构建/测试/部署/改代码。此段仅文档追加，另提交并正常推送；最终HEAD与第二次ls-remote/0/0/干净状态由最终报告给出，不自引用提交哈希。


## 第三批3.1前置幂等核对：触发停止条件

- 授权范围为活动详情 / Artifact详情原生toolbar与窗口工厂；基线main / origin/main / HEAD=a16dded、工作区干净、仅正式目录一个worktree。部署App的Info.plist确认217120f892443ea95966bad2a3a6583b3896fe34、Release、dirty=false；旧回退副本Cosmos Toolbox-20261012-213020-7e4b6733.app存在。创建并切换native/batch3-campaign-detail-20261013，未改main和两个WIP。
- 本轮只新增ZhuowangWorkspaceFilesIsolationTests.swift中3项隔离测试，没有窗口 / Store / schema / 业务 / 恢复迁移代码改动。全部使用内存数据源、独立身份、UUID临时Workspace根。
- testRecoveryRepeatedCallsPreserveWorkflowAndPayload通过：同一活动恢复后第二 / 第三次didRecoverAnything=false，Store编码和持久化字节不变，无重复产物。testLegacyMigrationRepeatedCallsPreserveWorkflowAndFile通过：迁移后第二 / 第三次返回0，Store编码 / 持久化字节 / 文件字节 / mtime不变，无重复产物。
- testRepeatedAppearRecoveryThenMigrationPreservesFirstPass失败（3断言）：合成活动有无location、未采用的旧Markdown产物；首次recover发现无文件，随后migrate生成文件。第二次recover发现该文件，虽不新增产物，仍把brief步骤改approved、将旧产物选为当前版本、更新元数据并持久化，didRecoverAnything=true。视图1361处恢复方法据此再次显示“已从本地工作目录恢复”提示。onAppear=先recover后migrate（93–94）；恢复方法恢复状态在Store2175–2208，fallback采用在2212之后，changed写盘在2374之后；迁移存在文件则跳过（2439之后）。第三次顺序调用的稳定性仅据独立重复测试与代码分析推断，本轮组合夹具只实测第二次，不宣称组合第三次已实测。
- 判断：单方法固定输入幂等与整个appear序列幂等不同；迁移改变下一次恢复的文件输入。只加UI单次保护能挡同一实例重复appear，不能解决关闭重开。按用户停止条件停止实现，不修改恢复 / 迁移逻辑、不加保护、不进行toolbar迁移，不将失败测试改成通过预期以绕过门槛。
- 构建：沙箱外原project / scheme，Debug build-for-testing成功；PRODUCT_BUNDLE_IDENTIFIER=com.wangyucosmos.cosmostoolbox.persistenceui.NativeBatch3Idempotency，CODE_SIGNING_ALLOWED=NO；实际宿主Info.plist已核对。xctestrun注入全套新UUID suite / 临时根，再test-without-building，仅运行ZhuowangWorkspaceFilesIsolationTests，7唯一测试6通过1失败（3断言），exit65；不运行全量 / Release / Provider / Harness，未进行修复轮。
- 证据：/private/tmp/CosmosNativeBatch3-idempotency-build.log、CosmosNativeBatch3-idempotency-tests.log、CosmosNativeBatch3-idempotency-tests.xcresult；DerivedData=/private/tmp/CosmosDD-native-batch3-idempotency。正式指纹before.json与after-idempotency.json完全一致：14文件path / size / mtime_ns、defaults export的5现存主业务Data键SHA-256；不输出业务正文。
- 未提交 / 推送 / 合并 / 部署；日常App与旧回退副本不动。未新增窗口验收或截图。测试失败夹具留在工作区供审查。
- 最小待决定范围：先单独确定旧产物迁移后是否应自动确认步骤 / 采用；若保留现行为，需授权调整初始化顺序或限定恢复触发条件，并验证首次 / 重开一致；本轮不擅自作该产品决定。后续3.2含资产中心过滤进toolbar，3.3个人笔记+知识库，3.4.searchable延后。
- 可复用：重复恢复和重复迁移要分别验证，同时覆盖生产调用顺序；单次UI保护不能代替跨窗口恢复语义核对。

### Current Status本次压缩前的已收尾信息（历史保留）

## 1. 当前检查点

- **日期 / 分支：** 2026-10-13，`main`。第二批部署版 `217120f` 已由用户实机体验并接受声明的验收范围；由 `8d4107f` 快进合入第二批 `2617433`，本次验收文档随 main 正常推送，远端确认与清理实际结果见当日日志。
- **范围：** 分类栏、三个 sheet 与修改意见、设置 Form、窗口工厂 / 位置记忆、八类窗口原生化、两处详情窗口位置记忆。身份键、关闭保护、Store / schema / 采用选择保持。
- **沿用验证：** 第二批 Debug / Universal Release 构建成功、隔离全量669/669、72对切页通过，开工 / 测试后 / 部署前后14文件与5业务键指纹一致。本轮仅Git / 文档 / 清理，不构建、不测试、不部署；离屏截图缺口与非阻塞待办保留§9，不追加验收。
- **日常 App：** 保持 `217120f`（Release、dirty=false），回退副本 `Cosmos Toolbox-20261012-213020-7e4b6733.app` 保留。第三批范围见§12，本次不启动。


- **原生化第二批：** 集成与自动验证已完成；分类栏玻璃/横滚、三个sheet与修改意见toolbar、设置Form、各窗口工具栏/标题/位置记忆/同类错开、未保存关闭提醒、减少动效与深浅色仍待用户实机验收。离屏分类玻璃、比较左窗格/资产外层黑块、设置TabView标签和原生toolbar缓存缺口保留；笔记历史/引用页与导出面板未新增视觉验收，不反复截图。设置原数据位置/恢复标题略重复是非阻塞细节。

- **第一批：** 现场玻璃/动效已由用户接受声明范围；`KnowledgeHubView` 因 PersonalNotesTests 引用保留。活动详情打开即执行恢复的既有P1留第三批接线前核对，本批不处理。


- **体验升级第二步 A：** 统一过渡采用稳定外层容器，模板预填不落盘；自动测试与浅深色离屏图已验证。用户已接受声明范围；实时动效 / 玻璃合成 / 帧率、跨窗口主题与面板交互仍不视为自动测试证据，后续问题另定范围；长内容按设计滚动。

- **第三步详情呈现与验收：** 概览“当前采用产物”最多列 5 项（全部列表仍可进入）；标签条位于内容区，未使用系统标题栏 toolbar；现场动效与玻璃合成已随第一批由用户接受声明范围；详情窗口真实点击、复用 / 缩放、月度登记、交付保存面板及 HTML Review 实际渲染仍沿用既有未覆盖边界。旧 B 标签已在第一批换为原生 segmented，不沿用旧玻璃标签截图判断。

- 本轮Current Status压缩后字节数：37992（低于38,000字节）；旧边界原文已移至本日志，不改旧日志。


## 第三批3.1恢复限定修复与详情窗口原生化（继续开发）

- 用户明确决定：迁移旧产物只写文件，不确认步骤 / 采用；恢复用于磁盘文件的缺失元数据。授权只改recoverWorkflowFromLocalFiles，本轮不回滚已确认正式步骤、不改schema / 格式 / 路径 / migrate / discover / 其他业务算法。
- 续做基线符合：native/batch3-campaign-detail-20261013、HEAD=a16dded，无新提交；未提交只有上节三文件。保留原测试与文档。重新记录CosmosNativeBatch3-resume-before.json，和原before一致。
- 根因：已登记产物也被加入recoveredStepIDs，所有无采用组都进入fallback；appear先恢复后迁移，迁移生成文件被下一次恢复当作确认依据。修复只对新append产物加入步骤恢复集合，新增本次导入ID集合限定fallback与歧义组；已有采用组不动，Step06仍只找回未采用。无新导入时不重建下一步，避免重复调用修改任何字段。
- 第一层实测：Debug build-for-testing成功，实际隔离宿主com.wangyucosmos.cosmostoolbox.persistenceui.NativeBatch3Idempotency；运行前Info.plist核对，全套UUID suite / 临时根注入；隔离11项与既有Step06 12项共23/23通过。修复与测试逐文件add，单独提交235ad62（fix: 恢复只对新导入产物恢复步骤与兜底采用）。正式after-recovery指纹一致。
- a：testRepeatedAppearRecoveryThenMigrationPreservesFirstPass通过：recover→migrate→recover→migrate，第二轮Store / 持久化字节 / 写计数不变、didRecoverAnything=false（视图由此不弹恢复提示）、无重复产物，迁移旧草稿未采用、所属步骤保持。
- b：testMissingMetadataRecoversHighestVersionAndAmbiguity通过：只留磁盘V1 / V3，导入2项、恢复1步骤approved、采用V3，歧义提示含需求整理；再次恢复不写、不改。保持原无元数据恢复行为。
- c：testPartialMetadataPreservesRegisteredDraftAndRecoversMissingGroup通过：已登记草稿的产物不变，缺失另一个组找回并恢复 / 采用。集中自查发现既有“下一可执行步骤”分支仍可能将已登记.failed / skipped / notStarted改ready；本轮集中修复增加旧产物所属步骤排除门控，测试扩展needsRevision / failed / skipped / notStarted四状态矩阵，最终受影响重验见后段。只改同一授权函数。
- d：testCustomerServiceRecoveryDoesNotApproveOrAdopt与既有testRecoveryImportsCustomerServiceFileWithoutApprovalOrAdoption通过：Step06只导入未采用，restoredSteps=0、不approved、无歧义fallback。
- e：testAdoptedPlanV1PrototypeV3CustomerServiceV1SurviveRepeatedRecoveryAndMigration通过：完整策划V1 / 原型V3 / 客服V1三采用ID在恢复与迁移两轮后保持；补一个客服V2孤儿文件，新找回后也不覆盖客服V1。
- f：testRecoveryRepeatedCallsPreserveWorkflowAndPayload、testLegacyMigrationRepeatedCallsPreserveWorkflowAndFile与原4项隔离测试通过；重复恢复 / 迁移含第二、第三次，保持Store / 文件字节与mtime，无重复产物。
- 第二层：活动与Artifact详情接CosmosWindowFactory（默认fullSizeContentView、title / toolbar桥接）；活动identifier=campaign.id.uuidString，controllers仍按UUID，route和windowWillClose不变；Artifact identifier=campaignID.uuidString+"::"+artifactName，controllers / 清理仍按windowKey；frameMemoryKey分别campaignDetail / artifactDetail，旧位置偏好不迁移。工厂接线与删自绘header / toolbarStrip同一提交4ae21c9（feat: 原生化活动与产物详情窗口工具栏及窗口工厂）。
- 活动标题navigationTitle(campaign.name)，副标题范围·日期；概览内容保留原进度环、状态与月度标识，内部实现不动。principal为原生Picker.segmented；disabled=isEditing或活动缺失，tabSelection也拒绝编辑态切换。编辑按钮 / 菜单及菜单子项各自以!store.persistenceState.allowsMutations禁用；删除仍是原confirmationDialog。取消接cancelEditing；保存接saveChanges，主操作+defaultAction，以空名称或持久化不可写禁用。产物页非编辑态显示原导出sheet按钮，工作文件隔离根失效时单项禁用。
- Artifact标题artifactName、副标题版本数；只在所选产物未采用时显示“设为当前版本”，仍接原setSelectedAsCurrent，主操作样式，workflow缺失时单项禁用；footer内容保持。原生关闭按钮 / ⌘W采用系统关闭路径，无自制关闭按钮。活动“关闭”及删除成功后经弱windowContext调用performClose，delegate仍属Manager。
- 视图@State didInitializeWorkspace只限制同一实例loadDraft / recover / migrate首次执行，路由每次appear仍可消费；不能替代Store修复。删除标签自制withAnimation / offset转场，内容identity替换；原生控件与既有scrollTransition由CosmosMotionPolicy控制减少动效，顶部软scrollEdge保持。
- 组件：CampaignUISegmentedTabs在本轮基线已不存在；删除唯一未再使用的CampaignUITabItem定义，新增ZhuowangDetailWindowContext（弱引用 / performClose）与ZhuowangCampaignDetailNativeTests两项（关闭代理否决、弱引用）。无第三方依赖 / Provider调用。
- 自查证据CosmosNativeBatch3-method-audit.json：23个private方法逐字不变；deleteCampaign只替换dismiss→windowContext.close；活动列表、路由清理、创建页面逐字不变。恢复之外的Store / schema / 发现迁移代码未改。参与实现者的自查不称独立复审。
- 修改文件：ZhuowangWorkflowStore.swift、ZhuowangWorkspaceFilesIsolationTests.swift、ZhuowangCampaignView.swift、ZhuowangCampaignDetailView.swift、ZhuowangCampaignDetailUIComponents.swift、新增ZhuowangCampaignDetailNativeTests.swift、Current Status、当日日志。其他源码 / 工程 / scheme / xcconfig未改。


### 集中验证结果与部署前检查

- 本轮全量test-without-building仅运行一次，官方xcresult摘要678 total / 678 passed / 0 failed / 0 skipped。678=既有669+恢复7+窗口关闭2，不重复计入先前23项或修复后23项；宿主com.wangyucosmos.cosmostoolbox.persistenceui.NativeBatch3Idempotency，全套独立suite / 临时根，原project / scheme，不改配置。TestHostBundleIdentifier和实际App Info.plist均核对一致。
- 一次集中修复为已登记步骤不参与next-actionable状态改写；修复后增量Debug测试构建成功，只运行恢复隔离11项+既有Step06 12项，23/23通过，含四状态矩阵；未重跑全量。集中修复提交5f26645（fix: 恢复时保护已登记产物所属步骤状态）。所有测试用内存 / 合成文件，未运行真实Harness / Provider。
- 官方摘要CosmosNativeBatch3-full-summary.json；本轮build / full-tests / repair-build / repair-tests.log与各xcresult在/private/tmp。既有Swift6隔离警告、WebKit缓存 / 选择状态 / QoS警告无失败，未扩大处理范围。沿用历史的是既有验收边界与部署协议，678项与本轮23项均为本轮实测。
- 正式数据resume-before / after-recovery / full-progress / after-full / after-repair均一致（14文件path / size / mtime_ns + 5主业务键Data SHA-256）；不读业务正文到日志，不做正式数据回滚或迁移。
- Liquid Glass / titlebar / 真实动效 / frame记忆与同类错开 / 编辑取消保存 / 删除对话框 / 导出保存面板 / Artifact真实采用与重开仍需实机验收。此次不以离屏缓存黑块判断缺陷，不新增截图；不要求用户逐步执行自动验证。
- 3.2（含资产中心过滤进toolbar）、3.3（个人笔记+知识库）未实施；3.4.searchable继续延后；所有WIP和暂缓项不动。下一步按授权先复制217120f回退副本，再用既有脚本构建Universal Release并部署本分支clean提交；以下只在执行后补记实际结果。


### 第三批3.1部署实际结果

- 两份验证文档逐文件提交399f90043de1a4fc180a4a6c20859e20d01a007a（docs: 记录第三批详情原生化与恢复限定修复验证），工作区干净，部署从此提交构建，dirty=false。未合并 / 推送；main / origin/main保持a16dded。
- 部署前shell指纹CosmosNativeBatch3-before-deploy.json与resume-before完全一致。用户指定先复制旧App：217120f已复制为Cosmos Toolbox-20261013-134238-prebatch3-bbdf9046.app，Info.plist原字节校验一致；不删除旧副本。
- /usr/bin/python3 scripts/deploy-macos.py沙箱外执行成功（exit0），原工程Universal Release BUILD SUCCEEDED，arm64+x86_64由lipo校验，ad-hoc签名与codesign --verify --deep --strict通过。正常退出旧App（未强杀），安装启动~/Applications/Cosmos Toolbox.app，PID41660。
- 部署脚本另保留第二批旧App为Cosmos Toolbox-20261013-134418-9b2b4420.app；该副本、预复制副本、原Cosmos Toolbox-20261012-213020-7e4b6733.app实际均存在。旧回退全部保留。
- 实际安装Info.plist：正式Bundle=com.wangyucosmos.Cosmos-Toolbox，CosmosBuildCommit=399f90043de1a4fc180a4a6c20859e20d01a007a，CosmosBuildDirty=false，CosmosBuildConfiguration=Release。源代码与两项功能均包含；后续仅部署记录文档不重新构建。
- 部署后CosmosNativeBatch3-after-deploy.json与resume-before / before-deploy等完全一致：14文件path / size / mtime_ns + 5业务Data键SHA-256。正式采用选择没有改动，没有执行数据回滚 / 迁移；不把UI窗口偏好变化算作业务数据变化。
- Release日志/var/folders/fh/13jx00z13ln1d46vx35pgljc0000gn/T/CosmosOS-ReleaseDeploy-3y1u7vmf/build.log；部署输出/private/tmp/CosmosNativeBatch3-deploy.log；预复制路径记录/private/tmp/CosmosNativeBatch3-precopy-backup.txt。仅一次Release构建，既有脚本先构建校验后发布，不重复跑Release。
- 本次Current Status合并第一 / 第二批清单行、压缩已收尾边界，下面保留原行；3.1已部署并待用户实机验收。恢复限定修复的产品规则稳定：已有登记不因文件存在而确认 / 采用；已确认的数据不回滚；元数据丢失仍能恢复。后续先验收再授权main收尾，不自行启动3.2 / 3.3 / 3.4。

压缩前模块行：

| 原生化第二批 | 分类栏 / sheet / 设置 / 八类窗口与详情记忆 | 已验收、已合入 main | 217120f；部署文档2617433 | 2026-10-12 / 13 开发日志 | 接受声明验收范围；身份/关闭保护与业务格式保持；离屏缺口保留§9 |
| Mac 原生化第一批（1.1–1.6） | 全局工具栏 / 内容按钮 / 分段 / 表面 / 系统动效 | 已验收、已合入 main | 00671aa | 2026-10-12 开发日志 | 641唯一测试与72对切页通过；独立窗口工具栏接入留第二批；KnowledgeHubView因测试引用保留 |

- 最终Current Status为37,841字节（低于38,000）；部署记录仅更新此文件与当日日志，逐文件提交。未覆盖项按上段实机边界，不追加验证；Git最终状态以提交后报告为准。


## 第三批3.1用户实机验收与main收尾

- 用户明确宣布3.1实机验收通过，授权快进main、正常推送、用-d删除功能分支及两份文档提交 / 再推送。不修改代码、不重新构建 / 测试 / 部署，沿用本阶段隔离678/678、集中修复后23/23及Universal Release / 签名实测；用户实机验收与自动验证分开记录。
- 开工实测：正式目录native/batch3-campaign-detail-20261013、HEAD=228ee6fd844324fa121dba8468bd2220d63e4e03，工作区干净；main / origin/main=a16dded，仅正式目录一个worktree。日常App Info.plist确认399f90043de1a4fc180a4a6c20859e20d01a007a、dirty=false，未重新部署。
- git switch main成功；git merge --ff-only native/batch3-campaign-detail-20261013成功，main从a16dded快进至228ee6f，无新增merge提交。
- git push origin main成功（a16dded→228ee6f）；git ls-remote origin refs/heads/main实际返回228ee6fd844324fa121dba8468bd2220d63e4e03，与本地一致。确认后git branch -d native/batch3-campaign-detail-20261013成功（was228ee6f），未使用force / -D / prune / reset / clean / stash / rebase。
- 正式数据由shell记录closeout-before / closeout-after.json，14文件path / size / mtime_ns + defaults export的5主业务Data键SHA-256完全一致，和实现开工指纹一致；不输出正文，未回滚或迁移正式数据。
- Current Status更新3.1已验收并main收尾、沿用验证口径、保持部署399f900；§12明确下一步3.2卓望二级栏List(.sidebar)（含资产中心过滤进toolbar），由Codex做；3.3个人笔记+知识库在3.2之后；3.4继续延后。本次不自动开工3.2。
- 仅更新Current Status与本日日志，逐文件add、中文文档提交到main后再正常push；文档提交 / 最终远端确认在最终报告给出，不自引用提交hash。Current Status为37859字节（低于38,000）。
- WIP保留：本地wip/markdown-word-export-phase1-20260930=2d26b2a及远端PDF WIP未触碰；回退副本全部保留。正式目录仍唯一worktree。
- 可复用：接受实机验收后只沿用受影响代码未变的验证；先快进 / 正常推送并实际核对远端，再安全删除已合并分支；文档补记结果后再推送核对。


## Mac原生化第三批3.2：卓望原生侧栏、活动Table与资产筛选

- 基线实测：main / origin/main / HEAD=bd4f67f，工作区干净、仅正式目录一个worktree；日常App=399f900、dirty=false，旧回退保留。shell指纹CosmosNativeBatch32-before.json为14文件path / size / mtime_ns与5主业务Data键SHA-256，和3.1收尾基线一致。按授权创建native/batch3-zhuowang-sidebar-20261013。
- A：内部侧栏ScrollView/VStack换原生List(selection:)+sidebar样式，Section总览 / 福利中心 / 其他工作 / 公共资料，count用badge(Int)，关注用SF Symbol与辅助说明；保留彩色省份首字图标与停用副标题，空省份管理入口保留。无自绘选中 / 悬停。
- UI选择枚举ZhuowangWorkspaceSidebarSelection映射原selectedNavigation + publicResources：workbench / province(UUID) / module(String)对应原导航，assets只设publicResources并清assetDestination，保持上次导航与分类；导航选择维持旧guard、overview重置、清assetDestination、退出publicResources、停用自动展开、assetModel.refresh时机。已有navigator同步与pendingWorkbenchMetric不动。提示词库是Button+selectionDisabled，调用promptVault动作分支只回调，不改变内容选择；枚举getter不会返回promptVault。
- B：卡片分支保留原adaptive网格和卡片；list分支换5列Table（名称 / 范围 / 日期 / 状态 / Workflow进度）。排序与选择只@State，不新增持久化；名称 / 开始日期 / 状态阶段rank可正反排序，UUID作为并列项稳定兜底。primaryAction用于双击 / 回车，contextMenu只有原打开详情，接原openCampaignWindow。Table在现有外层ScrollView中采用180–480pt有界高度，行多时原生表格滚动，不改外壳。
- C：活动页与推进工作台搜索改roundedBorder TextField加放大镜前缀，绑定 / 过滤逻辑不动；不加searchable。
- D：资产过滤因四种复用场景（五个调用点）保留内容区；4个Picker网格换原生筛选Menu与系统Label条件摘要，可清除。固定scope的省份隐藏、固定类型禁用、固定活动隐藏；UI绑定还强制保护province / module / step及固定type / campaign，非固定维度可编辑；清除恢复fixedScope或默认Filter。版本与搜索仍可筛选。model.filter / includes / matches / 只读检索未改，未采用组查看全部与bordered刷新保留。
- E：五个本轮源码内无残留内容glass/glassProminent或强制foregroundStyle(.primary)，无需额外机械改动。CosmosWorkspaceNavigationRow及其剩余使用方留3.3，不改不删。
- 代码自查17项通过，证据/private/tmp/CosmosNativeBatch32-boundary-audit.json：sidebarMinimum与HSplitView / CosmosNativeSplitWidth / preferences.workspaceSidebarWidth、detail.id(contentIdentity)、toolbar显隐与navigator监听原样；没有新增toolbar / searchable；活动详情Manager及后续创建视图、推进工作台动作 / 时间线 / 进度不变；六个只读文件、三个Store、Asset模型与ViewModel逐字不变。参与实现者自查不是独立复审。
- 资产调用方全部未改：Workspace公共资料与概览资产（2点）、ZhuowangCategoryContentView、CosmosNavigationSurfaces、PersonalNotesView（各1点），后两者共享知识库用途；四种复用场景、五调用点编译与原固定scope契约保持。没有新建生产卓望Store、schema / 路径 / 采用 / 导出 / 备份恢复变化。
- 新增ZhuowangNativeSidebarTests八项：testSidebarMappingRoundTripsWorkbenchProvinceModuleAndAssets；testNavigationResetsCategoryAndAssetDestinationAndRequestsRefresh；testPromptVaultOnlyCallsActionAndPreservesContentSelection；testStoppedProvinceSelectionExpandsWithoutCollapsingOnLaterNavigation；testAssetsSelectionKeepsLastNavigationAndCategoryAndClearsDestination；testTableSortsNameDateStatusAndStableTiesInBothDirections；testFixedAssetDimensionsCannotEscapeAndResetPreservesScope；testUnfixedAssetDimensionsStayEditableAndResetRestoresDefaults。既有测试未删除 / 弱化 / 改写断言。
- 第一次Debug build-for-testing唯一阻塞在新排序测试漏传必需now参数及其类型推断；一次集中修复补now和Array反序集合，并明确提示词Button不可选中。修复后增量测试构建成功；产品源码首轮已编译，无工程 / scheme / xcconfig改动。所有xcodebuild沙箱外执行。
- 隔离宿主com.wangyucosmos.cosmostoolbox.persistenceui.NativeBatch32，实际Info.plist与xctestrun宿主核对；全套新UUID suite / 临时fixture roots注入，参数记录CosmosNativeBatch32-isolation.json。未运行真实Provider/Harness、未按同名App做UI自动化。正式after-build指纹与before一致。
- 修改文件：ZhuowangWorkspaceView.swift、ZhuowangCampaignView.swift、ZhuowangCampaignWorkbenchView.swift、ZhuowangWorkspaceUI.swift、ZhuowangAssetCenterView.swift、新增ZhuowangNativeSidebarTests.swift、Current Status、当日日志。
- 未覆盖：实机系统玻璃 / List选中与键盘 / VoiceOver、分栏拖动与重启宽度记忆、Table双击 / 回车 / 点击列头排序 / 横纵滚动、筛选Menu / 清除与深浅色 / 减少动效。离屏List/sidebar缓存不完整是既有边界，不以缓存黑块判缺陷；自动逻辑与用户实机证据分开。
- 下一轮3.3：个人笔记List+searchable、知识库横条toolbar、CosmosWorkspaceNavigationRow剩余使用方；3.4统一检索继续延后，分类内容接入与三栏NavigationSplitView不做。WIP及暂缓项不动。


### 3.2集中验证结果

- 唯一一轮全量test-without-building，官方xcresult摘要686 total / 686 passed / 0 failed / 0 skipped；686=3.1基线678+新增8，不重复计入构建或历史测试。ZhuowangWorkspaceUITests、ZhuowangCategoryBarTests、ZhuowangCategoryPageTests、ZhuowangAssetCenterTests等既有测试全通过，断言未改。前置构建夹具修复后首次运行全量，无第二次全量或追加修复。
- 本轮生成既有浅深 / 两宽夹具截图；只查看campaign-list-1180-light.png和assets-1180-light.png作参考，五列Table与内容区筛选可读。分类栏缓存黑块和List离屏表现不算实机缺陷证据，不反复截图。真实选择 / 键盘 / 菜单 / Table操作未自动覆盖。
- 正式after-tests与before / after-build指纹完全一致。证据/private/tmp/CosmosNativeBatch32-{build,build-repair,tests}.log、tests.xcresult、summary.json、isolation.json与boundary-audit.json。既有Swift6 / Picker / WebKit / QoS警告保留，不扩大本轮。
- 下面仅记录Current Status压缩前的已收尾段落，完整历史保留；本轮实现 / 测试与文档将逐文件提交后才进行Release部署。不得合并 / 推送或删除功能分支。

## 1. 当前检查点

- **日期 / 分支：** 2026-10-13，`main`。3.1用户实机验收通过；main由a16dded快进至228ee6f并正常推送，远端已确认；功能分支已用-d删除，仅正式目录一个worktree。本次只做Git / 文档收尾。
- **第三批3.1：** 活动 / Artifact详情接窗口工厂，标签与操作进原生toolbar；身份与位置记忆键保持，关闭走performClose；视图单次初始化保护。恢复只对本次新导入产物恢复步骤 / 兜底采用，已登记草稿不自动确认 / 采用，Step06规则保持，已有数据不回滚。
- **沿用实现验证：** Debug测试构建成功，隔离全量678/678（0失败 / 跳过）；一次集中修复后只重验受影响恢复 / Step06，23/23通过。采用选择与已登记四种步骤状态保持；正式指纹一致。
- **部署：** Universal Release / 双架构 / 签名校验通过，399f900（dirty=false）已安装启动；正式14文件与5业务键前后全一致。新旧回退副本全部保留；用户实机验收通过。本次不构建 / 测试 / 部署，收尾前后正式指纹一致。
- **历史基线：** 第一 / 第二批已接受声明范围并main收尾；历史隔离669/669、72对切页与构建 / 指纹证据不算本轮实测，未覆盖见§9。


- **体验打磨轮：** 用户已接受声明的验收范围；后续若反馈问题，重点关注省份/模块重入与仪表盘筛选优先、Prompt冷/暖切换、短窗口设置与原生工具栏、超宽滚动条和深色控件。AppKit主侧栏在离屏缓存中未完整绘制，已改回完整原生List选中；侧栏与仪表盘快捷进入检索均不主动聚焦，页面提示按⌘F开始搜索；⌘F申请焦点，非空关键词跳转保留预填与既有焦点实现。取消快捷聚焦属于用户需求调整。真实拖动光标、重启宽度记忆未增加工具验证，用户接受该边界。Prompt外部修改须手动刷新显示快照；保存/恢复仍重读revision拒绝冲突。原生化的当前优先级统一见 §12。


- **历史证据：** 3.1隔离678/678与修复后23/23、Universal Release及用户实机验收沿用，不计入本批唯一测试数；无数据回滚或业务格式变化。

- **原生化第二批：** 用户已接受声明范围并完成main收尾；离屏分类玻璃、比较左窗格 / 资产外层黑块、设置TabView标签 / toolbar缓存及笔记历史 / 引用 / 导出面板缺口保留。设置标题略重复属非阻塞；完整验收边界见10月12 / 13日日志。


### 3.2提交与部署实际结果

- 实现 / 测试 / 两份文档逐文件提交51e32a742942886a4309a30ce58518a0adfb277e（feat: 原生化卓望二级导航与活动表格及资产筛选），工作区干净；main / origin/main保持bd4f67f，未合并 / 推送 / 删除功能分支，WIP不动。
- 部署前正式before-deploy指纹与before / after-build / after-tests一致。按用户要求先复制当前399f900程序为Cosmos Toolbox-20261013-143800-prebatch32-e6a515da.app，Info.plist字节一致；预复制路径/private/tmp/CosmosNativeBatch32-precopy-backup.txt。
- /usr/bin/python3 scripts/deploy-macos.py沙箱外成功（exit0）；仅一次Universal Release构建，先构建 / 校验双架构arm64+x86_64及ad-hoc签名 / codesign --verify --deep --strict，再正常退出旧App（未强杀）、发布并启动~/Applications/Cosmos Toolbox.app，PID45956。
- 部署脚本另保留旧399f900程序为Cosmos Toolbox-20261013-143937-7674edb0.app；预复制副本 / 此副本及原Cosmos Toolbox-20261012-213020-7e4b6733.app均实际存在，所有旧回退不清理。
- 实际安装Info.plist复核：正式Bundle=com.wangyucosmos.Cosmos-Toolbox，CosmosBuildCommit=51e32a742942886a4309a30ce58518a0adfb277e，CosmosBuildDirty=false，CosmosBuildConfiguration=Release；本次部署代码已全部提交。后续仅补部署记录文档，不重新构建或部署。
- 正式after-deploy与before及所有阶段指纹一致（14文件path / size / mtime_ns + 5现存主业务Data键SHA-256），未覆盖浙江活动测试的V1 / V3 / 客服V1采用选择、未运行真实Harness / Provider、不做数据回滚或迁移。不把UI偏好变化当业务数据变化。
- 构建日志/var/folders/fh/13jx00z13ln1d46vx35pgljc0000gn/T/CosmosOS-ReleaseDeploy-_mr23pyq/build.log；部署输出/private/tmp/CosmosNativeBatch32-deploy.log。旧Swift6隔离 / Sendable等警告保留；无构建错误 / 单测失败 / 阻塞。
- Current Status最终37869字节（低于38,000），只与本日日志一起补记部署结果并逐文件提交。用户实机验收边界按上述保留：List选中 / 键盘 / VoiceOver、Table主操作 / 列头排序、固定筛选菜单 / 清除、深浅 / 减少动效与重启宽度记忆。
- 可复用：保留现导航副作用的统一UI选择投影，提示词不可选中动作行；Table排序用视图投影和@State，组件复用过滤留内容区并锁定固定scope；先真实数据指纹再clean提交 / 回退复制 / 既有部署脚本。本批不自动扩展3.3或3.4。


## 第三批3.2用户实机验收与main收尾

- 用户明确宣布3.2实机验收通过，授权快进main、正常推送、用-d删除功能分支及两份文档提交 / 再推送，最后fetch核对。只做Git / 文档，不构建 / 测试 / 部署；沿用本阶段隔离686/686、Universal Release / 双架构 / 签名证据，用户实机证据与自动验证分开。
- 基线实测：正式目录native/batch3-zhuowang-sidebar-20261013、HEAD=60d4f11603a6ecbfb74399313d200181928d4357，工作区干净；main / origin/main=bd4f67f，仅正式目录一个worktree。日常App实际Info.plist确认51e32a742942886a4309a30ce58518a0adfb277e、dirty=false，未部署新App。
- git switch main成功；git merge --ff-only native/batch3-zhuowang-sidebar-20261013成功，main由bd4f67f快进至60d4f11，无新增merge提交。
- git push origin main成功（bd4f67f→60d4f11），git ls-remote origin refs/heads/main实际返回60d4f11603a6ecbfb74399313d200181928d4357，与本地一致。确认后git branch -d native/batch3-zhuowang-sidebar-20261013成功（was60d4f11）。未使用force / -D / reset / clean / stash / prune / rebase。
- shell正式指纹CosmosNativeBatch32-closeout-before / closeout-after.json完全一致：14文件path / size / mtime_ns + defaults export正式域5主业务Data键SHA-256，和3.2部署后基线一致；不输出正文、无数据回滚或迁移。
- Current Status记录3.2用户验收 / main收尾，日常App保持51e32a7；§12下一步3.3个人笔记List+searchable、知识库横条toolbar、CosmosWorkspaceNavigationRow剩余使用方原生化，由Codex做；3.4继续延后。本次不启动3.3，资产过滤内容区决定与暂缓事项保持。
- 本段仅随两份文档逐文件add、中文提交到main后再正常push；最后只fetch origin main核对最终main / origin/main / FETCH_HEAD，结果由最终报告给出，不自引用提交hash。Current Status为37870字节，低于38,000。
- 本地Word WIP=2d26b2a与远端PDF WIP不动，旧回退副本全部保留，正式目录仍唯一worktree。
- 可复用：用户接受范围后沿用代码未变化的实测；快进 / 正常推送确认后安全删除已合并分支；文档结果正常推送后只fetch目标main并核对一致。


## Mac原生化第三批3.3：知识库工具栏与个人笔记List

- 基线实测：main / origin/main / HEAD=cfdba2a，工作区干净，只有正式目录一个worktree；日常App=51e32a742942886a4309a30ce58518a0adfb277e、dirty=false，回退全部保留。创建native/batch3-knowledge-notes-20261013，仅本工具修改。
- shell正式基线CosmosNativeBatch33-before.json：14文件path / size / mtime_ns与defaults export的5主业务Data键SHA-256。额外记录PersonalNotes/notes.json与notes.backup.json、KnowledgeSources/sources.json与sources.backup.json的path / size / mtime_ns及缺失状态；笔记主备份均缺失，来源主文件310字节，来源备份缺失。只读元数据、不输出正文，不在XCTest访问真实库。
- A：CosmosKnowledgeDestinationView删内容顶部HStack / Divider，分区Picker.segmented进ToolbarItem.principal，原accessibilityLabel保持。绑定仍写navigator.knowledgeSection，三个子页构造及参数不变；sectionBinding共享实际生产Binding供双向测试。
- B：PersonalNotesView改原生List.inset；标题 / 归档标记、分类·版本·时间及240字符有界两行预览保持。行Button单击原Manager.open，List.primaryAction回车 / 双击原打开；favorite星标受cosmosSymbolReplacement减少动效控制；归档 / 恢复进List右键与swipeActions（禁fullSwipe），原note-row / note-favorite / note-archive UUID标识保持。无自制卡片 / cosmosScrollReveal入场。
- 个人笔记searchable绑定原search，不加keyboardShortcut；notes-search保留在searchable容器。分类 / 收藏 / 当前归档进筛选Menu，活动筛选摘要 / 清除位于List顶部；过滤仍委托PersonalNotesQuery，四个原@State不迁移。计数含0条、错误 / 读取 / CosmosEmptyState / 底部说明保持。工具栏新建 / 导出 / 刷新及disabled条件保持，canSave=false禁新建 / 收藏 / 归档；共享实时UI门控只拒绝不可写请求，仍接原Store方法，不改Store或编辑器。
- C：KnowledgeSourcesRootView来源Picker.menu与管理进toolbar，保持knowledge-source-picker及switchSource链路；添加!canSave / 重扫enabledSources.isEmpty原条件保持，来源在无启用者时禁用，管理只在原browser可出现状态显示。sourceInformation保留扫描 / 文档附件计数 / 排除popover与knowledge-exclusions / 截断提示，无背景横条。knowledge-search改roundedBorder，原FocusState / 清空 / 隐藏⌘F字节保持；文件夹树collapse改smooth系统动画受reduced控制。我的知识库不用searchable，保留⌘F，避免统一检索冲突，3.4再处理。
- D：全仓Swift（含测试）确认CosmosWorkspaceNavigationRow只有定义无调用后删除；同文件其它类型逐字不变。KnowledgeHubView因旧测试引用保留，完全未改。
- 28项源码边界核对通过，/private/tmp/CosmosNativeBatch33-boundary-audit.json：统一检索 / Dashboard / CosmosPageMotion / navigator、Notes Store / Models / FileStorage / Editor、Knowledge Store / FileStorage / Scanner / Search / Git / Reader / Markdown / Renderer及卓望文件无diff；KnowledgeSourceViews的Reader / Actions / OpenCenter / toast / 后续子视图逐字保持，隐藏⌘F行不变；searchable仅新增个人笔记，笔记不加⌘F。这是参与实现者自查，不称独立复审。
- 新增CosmosKnowledgeNativeTests六项全部首轮通过：testNoteFilterCombinationsMatchExistingQuery（64组合）；testClearNoteFiltersRestoresCurrentUnfilteredDefaults；testBlockedNoteStoreCannotRequestCreateFavoriteOrArchive；testNoteActionsUseLiveSaveGateAndPreserveRequestedIdentity；testKnowledgeSectionBindingIsBidirectionalAndLeavesSearchFocusUntouched；testNativeNotesListAndToolbarMountPreserveTemporaryLibrary。全部临时根 / 随机suite或内存navigator，无真实Documents探测。
- 首次Debug build-for-testing成功，无生产编译修复。唯一一轮全量官方摘要692 total / 690 passed / 2 failed / 0 skipped；未把日志3条失败断言当作3用例。失败1：CosmosStep2ATests.testNativeKnowledgeSegmentUpdatesBindingWithoutPreferenceWrites仍在NSHostingView内容区找三段控件，迁移后找不到；失败2：AIWorkspaceToolProbeTests.testRunnerCancellationTerminatesChild的PID字符串转Int32失败（临时脚本创建文件与写PID存在时序窗口），进程源码与测试均未改。
- 一次集中修复仅同步CosmosStep2ATests原夹具：改CosmosWindowFactory桥接的独立隔离窗口，orderBack创建原生toolbar；从toolbar视图 / 标题栏或AppKit原生三项NSToolbarItemGroup取实际分段控件，仍发送原生action，保持原nav.sources与偏好motion不变断言，没有换成直接写binding或弱化断言。没有System Events / 同名App定位。框架两种原生表示的适配属于同一集中修复；增量测试构建成功。
- 修复后只跑上述2失败用例，官方摘要2/2通过（CosmosNativeBatch33-repair-summary.json），取消测试未改源码。未重跑全量，692唯一用例均有通过证据（690+2），不宣称首轮全量全部通过。不扩展处理PID时序待办。
- 测试宿主实际Info.plist与xctestrun确认com.wangyucosmos.cosmostoolbox.persistenceui.NativeBatch33，新UUID suite与全套临时fixture roots记录CosmosNativeBatch33-isolation.json；所有xcodebuild沙箱外。证据/private/tmp/CosmosNativeBatch33-{build,tests,repair-build,repair-final-build,repair-tests}.log及xcresult / summary；新增测试6不与重验2重复计数。
- 正式after-build / after-tests / after-repair与before一致；额外笔记 / 来源主备份元数据（包括missing）同样一致。未运行真实Provider / Harness、未回滚或迁移任何正式数据。
- 查看既有矩阵本轮生成的notes-light-1180x760.png仅作参考，原生列表正文 / 星标 / 底部说明可读，工具栏和searchable不在内容缓存里，不算缺陷，不反复截图。真实toolbar玻璃 / 搜索位置 / 行单击回车 / 收藏右键滑动 / 来源切换 / ⌘F / 深浅色与减少动效待用户实机验收。
- 修改：CosmosNavigationSurfaces.swift、PersonalNotesView.swift、KnowledgeSourceViews.swift、CosmosWorkspaceUI.swift、新增CosmosKnowledgeNativeTests.swift、既有CosmosStep2ATests.swift夹具、Current Status、当日日志。其他文件未动，既有断言未删弱。
- 下一步在3.3验收后由用户确定；3.4统一检索仍延后，编辑窗口 / 历史引用 / 资产中心 / 读取渲染 / 分类接入 / 三栏与所有WIP暂缓不动。下面保留Current Status压缩前已收尾细节。

## 1. 当前检查点

- **日期 / 分支：** 2026-10-13，`main`。3.2用户实机验收通过；main由bd4f67f快进至60d4f11并正常推送，远端已确认；功能分支已用-d删除，仅正式目录一个worktree。本次只做Git / 文档收尾。
- **3.2实现：** 二级栏原生List.sidebar，选择映射原导航，提示词按钮不可选中；列表布局换五列Table，排序仅视图内存；两处搜索roundedBorder；资产筛选因复用保留内容区Menu，固定维度受保护，可清除。卡片、宽度记忆、外壳与Store保持。
- **沿用实现验证：** Debug测试构建成功；隔离全量686/686（0失败 / 跳过），新增8项通过，既有断言未改。17项边界核对通过，正式14文件与5业务键指纹一致。一次修复仅新夹具必需now参数 / 集合类型与提示词按钮选择保护。
- **部署：** 51e32a7（dirty=false）Universal Release已安装启动，双架构 / 签名校验通过，部署前后正式指纹一致。新旧回退保留；用户实机验收通过。本次不构建 / 测试 / 部署，收尾前后正式指纹一致。
- **历史证据：** 3.1构建 / 测试 / 用户验收沿用，不算本批实测；恢复规则与既有数据保持。


- **原生化第二批：** 已接受声明范围并main收尾；离屏玻璃 / toolbar、比较 / 资产缓存、笔记历史 / 引用 / 导出缺口与设置标题细节保留，完整边界见10月12 / 13日志。

- **第一批：** 用户已接受声明范围；`KnowledgeHubView`因测试引用保留。恢复风险已按用户决定限定修复，见§1 / §12。

- **第三批3.2：** 用户已实机验收并接受声明范围；自动与用户实机证据分开。离屏List / 分类栏缓存边界保留，不据黑块扩大修复；后续反馈另定范围。

- **第三步详情呈现与验收：** 概览采用产物最多5项，可进入全列表；详情原生toolbar已在3.1完成并经用户实机验收。第一批已接受现场玻璃 / 动效声明范围；真实点击、复用 / 缩放、月度登记、保存面板、HTML Review渲染未覆盖。旧B标签已换原生segmented，不用旧截图判断。


### 3.3提交与部署实际结果

- 实现 / 测试 / 两份文档逐文件提交5d3814718e724bbb0bc1a4a9e9fae6cf7eab22e2（feat: 原生化知识库分区与笔记列表及来源工具栏），部署前工作区干净；main / origin/main=cfdba2a未动，功能分支保留，未合并 / 推送，WIP保持。
- 部署前业务before-deploy与before一致，个人库metadata-before-deploy同样一致。按授权先复制旧51e32a7 App为Cosmos Toolbox-20261013-153827-prebatch33-50961446.app，Info.plist原字节相同；预复制路径/private/tmp/CosmosNativeBatch33-precopy-backup.txt。
- 既有/usr/bin/python3 scripts/deploy-macos.py沙箱外成功（exit0）；只一次Universal Release BUILD SUCCEEDED，双架构arm64+x86_64、ad-hoc签名及codesign --verify --deep --strict通过；正常退出旧App（未强杀），发布启动~/Applications/Cosmos Toolbox.app，PID51695。
- 部署脚本另保留旧51e32a7为Cosmos Toolbox-20261013-154045-f2e2f566.app；此副本、预复制副本与原Cosmos Toolbox-20261012-213020-7e4b6733.app实际均存在，旧回退全保留。
- 实际安装Info.plist复核：正式Bundle=com.wangyucosmos.Cosmos-Toolbox，CosmosBuildCommit=5d3814718e724bbb0bc1a4a9e9fae6cf7eab22e2、CosmosBuildDirty=false、CosmosBuildConfiguration=Release。后续仅部署结果文档提交，不再构建 / 部署。
- 正式业务after-deploy与before / after-build / after-tests / after-repair / before-deploy均一致（14文件path / size / mtime_ns + 5主业务Data键SHA-256）；额外四个笔记 / 来源主备份路径元数据也全一致，包括笔记主 / 备份缺失与来源备份缺失。真实笔记库未自动新建，来源登记未写，不回滚 / 迁移正式数据；未运行真实Harness / Provider。
- Release日志/var/folders/fh/13jx00z13ln1d46vx35pgljc0000gn/T/CosmosOS-ReleaseDeploy-pw0m1uox/build.log；部署输出/private/tmp/CosmosNativeBatch33-deploy.log。既有Swift6 / Sendable警告与PID取消夹具时序风险非本期阻塞，未扩大修复。
- Current Status最终37842字节（低于38,000）；只与本日日志一起逐文件提交部署结果。用户实机验收还需工具栏 / 搜索位置、单击回车 / 收藏 / 归档右键滑动、来源管理 / 排除popover、知识库⌘F / 统一检索⌘F、深浅与减少动效，不将代码核对当实际键盘验收。
- 可复用：工具栏迁移后夹具必须从桥接的原生窗口工具栏查找控件，保留实际action与旧断言；笔记变更入口共享实时只读门控；正式文件不存在也须作为指纹状态保留。3.1–3.3实现完成，下一步由用户确定；3.4继续延后，不自动开工。

## 第三批3.3用户实机验收与main收尾

- 用户确认3.3实机验收通过并授权收尾。基线：功能分支759dfd2、工作区干净；main / origin/main=cfdba2a，只有正式目录一个worktree；日常App=5d38147、dirty=false。
- git switch main与git merge --ff-only成功，main从cfdba2a快进到759dfd2；正常推送成功，ls-remote确认远端759dfd2。git branch -d成功删除native/batch3-knowledge-notes-20261013。
- Mac原生化第三批（3.1–3.3）全部完成。Current Status记录验收与收尾结果；§12下一步：待用户确定下一模块（候选：3.4 统一检索 .searchable；卓望分类内容接入；卓望数据迁移到受保护文件存储）。不自动开工。
- 非阻塞待办：PID取消夹具时序不稳定，文件创建与PID写入有窗口；开发阶段受影响重验通过，未扩大修复。沿用首轮692项690通过及两失败项重验2/2证据，不宣称首轮全量全通过。
- 收尾前后正式14文件 / 5业务键指纹一致。本次只执行Git、两份文档与数据核对，不重新构建 / 部署 / 跑测试；日常App保持5d38147，回退副本保留，Word / PDF WIP不动。
