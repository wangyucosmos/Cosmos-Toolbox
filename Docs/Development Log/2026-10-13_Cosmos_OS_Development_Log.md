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
