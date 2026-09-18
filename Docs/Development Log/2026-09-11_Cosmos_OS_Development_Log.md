# Cosmos OS Development Log

## 2026-09-11 Artifact PDF Renderer Phase 1 正式收尾

### 一、基线与范围

- 稳定 `main` 基线：`30de1e07292fb66cd8111328b230ffaaa9c51b6c`。
- 开发分支：`wip/pdf-renderer-phase1-20260902`。
- PDF 实现与测试修复后的 WIP HEAD：`eeaa8f2f10e96499791971ccc371707e637c3969`。
- Phase 1 只扩展 Artifact Review 的 typed local-file Preview 边界，不修改 Store、Workflow、UserDefaults、Artifact Model、Adoption、Recovery、Workspace File Manager、Task Package 或 Harness。
- 不读取或导入真实业务 PDF；自动与人工 smoke 全部使用系统临时目录动态生成的 Fixture。

### 二、实现的数据流

```text
ArtifactReviewPayload.localFile
→ ArtifactPreviewInputResolver（只传递引用，不进入 UTF-8 Reader）
→ exact PDF media classification
→ ArtifactPreviewRendererRegistry
→ ArtifactPDFPreviewLoader
→ bounded Data memory snapshot + fingerprint checks
→ ArtifactPDFPreviewSecurityPolicy
→ PDFKit PDFDocument
→ ArtifactSecurePDFView
→ ArtifactPDFRendererBindingSession
→ Renderer-local transient state
```

- `ArtifactReviewModels` 与 Preview Input 保持 typed local-file 输入；PDF 二进制不会进入文本 Reader。
- Registry 只有在 payload、UTType、MIME、扩展名和 legacy hint 的 PDF 证据一致时选择 PDF Renderer；冲突或不支持的输入进入安全 fallback。
- Loader 读取受限 Data 内存快照，执行文件大小、文件指纹、取消、generation 和 timeout 协调，再交给 PDFKit 与安全策略。
- Security Policy 检查文档权限、页面和动作边界；安全失败以脱敏错误显示，不暴露完整绝对路径。
- Renderer 使用连续垂直 PDFKit Preview，支持 Fit Page、Fit Width、10%–400% 缩放、当前页 / 总页数、上一页、下一页、页码跳转、页面尺寸、页数、文件大小、文本选择、权限允许时复制，以及同一文档内部 GoTo。
- Review、Full Preview、PDF | PDF、HTML | PDF、Image | PDF 和 PDF | Unsupported 共用 Renderer Registry 与 Review Pane 边界。
- PDF | PDF 的两侧分别持有 PDFView、View Model、Binding Session、页码、缩放、滚动、delegate 和 observer；两侧状态不共享。
- PDF Renderer 不声明 Source 或 Mobile Viewport capability，因此不会显示 Source、375px 或 390px 控件。
- PDF Data、PDFDocument、加载状态、页码、缩放和绑定状态只存在于 Renderer 生命周期，不进入 Store、Workflow、UserDefaults 或 Artifact Model。

### 三、安全与资源边界

- 限制文件大小、页数、单页宽高和页面面积；超限 fail closed。
- 加密 PDF 拒绝；Phase 1 不支持密码输入或解密。
- AcroForm / Widget 拒绝。
- JavaScript、OpenAction、Additional Actions 拒绝。
- Launch、URI、RemoteGoTo 和不允许的 Named Action 拒绝；未知 Action fail closed。
- 附件、Sound、Movie、RichMedia 和 3D 内容拒绝。
- Runtime delegate 只允许同一文档内部 GoTo；HTTP / HTTPS、file、mailto、RemoteGoTo、Print 和其他外部动作不会启动外部程序。
- UI 不提供 Print、Save、Export 或 Annotation 编辑入口。
- 全 App PDF 重型加载 gate 的最大并发为一；完成后 active count 回到零。
- Loader 与 Binding Session 使用 cancellation、document generation 和文件 fingerprint changed 保护，旧任务、旧 generation 和 teardown 后通知不能回写当前状态。
- 错误提示只显示安全分类和脱敏文件信息，不显示完整绝对路径。

本边界不是进程级沙箱，也不表示可以安全处理任意恶意 PDF。PDFKit 与 Core Graphics 仍在 Cosmos OS App 进程内解析；当前层无法精确限制 PDF 内部对象数量、框架缓存或同步解析时间。逻辑 timeout 能阻止过期结果发布，但不能强制终止已经进入 PDFKit 的同步工作。更强安全边界需要未来 XPC 或独立进程 Renderer。

### 四、Renderer 生命周期机制

- View Model 强持有当前 `ArtifactPDFRendererBindingSession`。
- Session 弱引用 View Model 和 PDFView，强持有安全 delegate、observer tokens 和合并后的 deferred publication。
- Coordinator 强持有 Session；PDFView 强持有安全 delegate，同时只弱关联 Session。
- observer closure 只弱捕获 Session / PDFView。
- teardown 会失效 generation，取消加载和 pending publication，移除 observer，清空 PDFView document、PDFView delegate、Renderer 强持有 delegate，并断开 Session / View Model。
- cancel、dismantle 和重复 teardown 的顺序具备幂等性；安全边界不依赖 `deinit`，也不只依赖 `dismantleNSView`。
- currentScale 使用合并 deferred publication 和 epsilon 数值去重，避免 SwiftUI view update 中同步发布和布局反馈环。

### 五、调试过程中解决的问题

1. 安全 delegate 的递归调用曾造成栈溢出；最终明确区分 PDFKit delegate 转发与安全动作判定，消除递归路径。
2. PDF 缩放状态同步曾形成 SwiftUI 发布 / 布局反馈环；最终使用合并 deferred publication、epsilon 去重和 generation 校验。
3. 仅依赖 `dismantleNSView` 无法覆盖所有取消、关闭和 View identity 变化路径；最终引入显式、幂等的 Binding Session teardown。
4. Fixture Window smoke 最初使用同步 RunLoop 条件轮询，占用 XCTest 的 MainActor job，导致 Loader Task 和 timeout Task 无法开始，表面停留在 `loading`。根因不是 Renderer 加载死锁。
5. 条件等待最终改为 `@MainActor async` helper，使用 `ContinuousClock`、原有 8 秒总 deadline 和短间隔异步 sleep，使 MainActor job 真正挂起；没有延长超时或依赖固定完成时间。
6. 人工 smoke 初版 Fixture 的 WindowContext 未绑定实际 NSWindow，导致页面内关闭按钮无效；这只属于临时测试入口接线，不是生产 Window Manager 缺陷。绑定实际窗口后关闭路径验证通过，临时改动随后全部恢复。
7. 人工验收后的临时双栏缩放断言一度绕过正式 Fit / Zoom 控制链，并假设独立视图遍历顺序一致；改用真实 ViewModel 控制链和 PDFView 对应 Session 后通过。这是临时测试观测方式错误，不是 Renderer 缺陷。

### 六、修改文件

Phase 1 WIP 相对稳定 `main` 包含：

- `Apps/CosmosOS/Cosmos Toolbox/ArtifactPDFPreviewLoader.swift`（新增）
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactPDFPreviewSecurityPolicy.swift`（新增）
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactPDFRenderer.swift`（新增）
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactPreviewRenderer.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactReviewModels.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ArtifactPDFRendererTests.swift`（新增）
- `Apps/CosmosOS/Cosmos ToolboxTests/ArtifactReviewWorkspaceTests.swift`
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-09-11_Cosmos_OS_Development_Log.md`（新增）

未修改 `project.pbxproj`、持久化业务模型、Store、Workflow、UserDefaults 业务键、Adoption、Recovery、Harness 或真实 Artifact 文件。

### 七、正式自动验证

- Unit Tests：115/115 passed，0 failed，0 skipped。
- Universal macOS Debug Build：成功，包含 arm64 + x86_64，`ONLY_ACTIVE_ARCH=NO`，`CODE_SIGNING_ALLOWED=NO`。
- `git diff --check`：通过。
- 聚焦 Fixture Window smoke：连续 5 次通过。
- 人工验收收尾后的最终 Fixture smoke：通过，2.420 秒。
- PDF Security Policy 聚焦测试：5/5 通过。
- Renderer 生命周期测试：通过；delegate、document、observer、pending publication 和 Binding Session 在关闭后完成清理。
- Loader 实际进入全 App gate；最大并发为 1，最终 active count 为 0。
- 自动覆盖包括 typed classification、二进制不进入 UTF-8、资源限制、加密 / 表单 / 动作拒绝、内部 GoTo、外部动作拦截、加载取消、generation、fingerprint changed、错误脱敏、Review / Full Preview、PDF / mixed Compare、左右状态隔离和真实 teardown。

### 八、人工 UI Smoke 与验收分级

人工确认通过：

- 6 个业务形态 Fixture 窗口全部进入 ready，共捕获 7 个真实 PDFView；PDF | PDF 两侧各有一个独立 PDFView。
- PDF 页面真实显示，连续垂直滚动、上一页、下一页和页码跳转正常。
- Fit Page、Fit Width、100%、放大、缩小和 10%–400% 边界正常。
- PDF | PDF 两侧页码和缩放独立；自动验证同时覆盖滚动和完整 Renderer 状态隔离。
- Full Preview 页面内关闭、原生关闭、关闭后重开、窗口缩放和原生全屏进入 / 退出正常。
- HTML | PDF、Image | PDF 和 PDF | Unsupported 显示符合各 Renderer capability；蓝色图片是动态 Image Fixture，HTML Fixture 的静态内容不是 PDF 缺失。
- Light / Dark appearance 下布局与白色 PDF 页面画布可用。
- 临时 WindowContext 正确绑定实际 NSWindow 后，页面关闭按钮走正式窗口关闭路径并验证有效。
- 未发现 PDF Publishing warning、栈溢出、崩溃、卡死或异常高 CPU。

没有声称人工完全覆盖：

- “可预览但禁止复制”的 PDF；现有加密 Fixture 会被安全策略整体拒绝。
- 文本选择后系统剪贴板中的最终内容。
- 每一种危险 PDF Action 的逐项人工点击。

上述项目已有自动安全策略或权限测试覆盖，人工验收缺口被明确保留，不阻塞 Phase 1 当前只读 Review 范围，也不应被描述为所有安全场景都已人工验证。

### 九、非阻塞观察

- 一次聚焦组合测试记录了两条由其他 Compare 测试在未安装 View 时访问 SwiftUI `@State` 产生的 warning。
- 这两条不是 PDF Renderer 的 Publishing warning，没有造成测试失败，也没有影响 PDF Fixture ready、交互或 teardown。
- 本轮不扩大范围修改其他 Compare 测试；后续应单独核查并决定是否清理测试构造方式。

### 十、数据保护证明

- Workflow 业务键 canonical Data SHA-256：`a7e3dd5f7e2dc1c62f62d0e7490b660df59b3947eb0f90e293d7ad617dd02b61`。
- Workflow 状态保持 01–05 `approved`、06 `ready`。
- 当前 adopted Prototype 仍为 V3。
- Store 已纳管 V1 / V3 / V4；V2 继续未纳管。
- V1：`99aa1cf0db2f030a629e813d42744c60335a6175e619f798833c4dcd18c17823`
- V2：`4587af3ecda7e1823b50567619dbf40c559f1bba6b22d2bfb3a1ac9937036eb6`（未纳管）
- V3：`d8150faf51bac2f1b8ec11a4a007c4e70c5dcd821619c5d34531eb4dae0264ed`
- V4：`6911e40666e459f6afa42fa08690d167503644de65565b45eedaba7f0d0bc489`
- V1–V4 文件哈希保持既定基线。
- 未运行 Harness，未生成、导入或采用 Artifact，未修改业务 UserDefaults。

### 十一、剩余风险与明确未实现范围

- PDFKit / Core Graphics 仍在 App 进程内解析；没有进程级隔离。
- 当前层不能精确限制内部对象数量、缓存和同步解析时间；逻辑 timeout 不能硬终止已进入 PDFKit 的同步工作。
- 更强安全边界需要未来 XPC 或独立进程 Renderer。
- Phase 1 不支持密码 PDF、搜索、缩略图、Outline、表单交互、打印、保存、导出、Annotation 编辑或 PDF Adoption。
- 本阶段只读预览的 Renderer 状态不持久化，也不改变真实业务 Artifact。

### 十二、Git 状态与推荐下一步

- PDF 实现和异步测试等待修复已保存在 WIP 分支；本次正式文档收尾只留下 Current Status 与本日志的未暂存修改。
- 本轮不 commit、不 push、不 merge `main`，不创建 PR 或 Tag。
- 下一步应先审查本次文档 diff，再决定最终正式提交与 WIP → `main` 集成方式。
