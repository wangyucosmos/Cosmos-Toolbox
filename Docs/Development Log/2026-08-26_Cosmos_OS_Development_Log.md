# Cosmos OS Development Log

## 2026-08-26 Image Renderer Phase 1

### 一、本次目标

- 在 Artifact Preview 类型化抽象上接入首个非 HTML Renderer。
- 只支持显式本地文件引用的单帧静态 PNG / JPEG 只读预览。
- 保持持久化 Artifact、Workflow、Adoption、Recovery、Workspace File Manager、Task Package、Harness / AI Adapter、HTML Security Policy 与真实业务数据不变。

### 二、最终数据流

```text
ArtifactReviewPayload.localFile
→ ArtifactPreviewInputResolver
→ typed local-file Preview Input
→ ArtifactPreviewRendererRegistry
→ ArtifactImagePreviewRenderer
→ ArtifactImagePreviewLoader
→ ImageIO validation + bounded decode
→ Renderer-local CGImage + minimal metadata
→ Image Preview UI
```

- Payload 和 Review Document 只保留类型化文件引用，不持有完整 `Data` 或 `CGImage`。
- Resolver 对图片只传递受控引用，不调用 UTF-8 Reader。
- Registry 只选择 Renderer；真实格式探测、预算检查、文件一致性和解码由 Loader 完成。
- 解码结果只存在于当前 Renderer / 窗口生命周期，不进入 Store、UserDefaults 或 Artifact 内容。

### 三、格式、安全与资源边界

- Phase 1 仅接受 ImageIO 实际识别为 PNG 或 JPEG 的单帧静态图片。
- GIF、APNG、多帧内容、HEIC / HEIF、WebP、TIFF、SVG、PDF 和外部 URL 图片均安全拒绝，不静默读取第一帧，也不回退到 WebView 或 `NSImage` 宽松解码。
- 声明的 UTType、MIME、扩展名与实际签名冲突时 fail closed；无扩展名但 typed media 明确为 Image 的 PNG / JPEG 可以按真实签名加载。
- 硬限制：50 MiB 文件、16,384 px 单边、36,000,000 总像素、224 MiB 预计峰值解压预算、Zoom 10%–400%。超限直接拒绝，不降采样。
- 使用溢出安全的 `alignedBytesPerRow × height × 1.5` 预算，并在方向变换前后复核尺寸。
- 保留可安全使用的嵌入色彩空间；缺失时受控转换为 sRGB；不展示或持久化隐私 EXIF。
- 解码前后比较文件大小、修改时间和 resource identifier；文件被删除、替换、截断或修改时丢弃结果并进入可恢复错误。
- 重型 ImageIO 解码通过共享 Actor 限制为同时一个；Task cancellation 和 document generation token 阻止过期结果发布。

### 四、Review 与 Compare 行为

- Image Renderer 支持 Preview、单版本 Full Preview、Fit、backing-scale-aware 100%、放大、缩小、重置、双向滚动和格式 / 像素 / 文件大小信息。
- Image 不支持 Source 和 375px / 390px Mobile Viewport；切换到 Image 时通用 Workspace 根据 capabilities 自动隐藏无关控件。
- 图片专属加载和缩放状态由各 Renderer 内部临时 View Model 持有，不进入通用 Preview Context 或持久化结构。
- Compare 支持 Image | Image、HTML | Image、Image | HTML 和 Image | Unsupported；两侧图片状态独立，HTML 侧继续使用原有 Preview / Source 与 Renderer Security Boundary，Mobile Viewport 只作用于处于 Preview 的 HTML 侧。
- Compare 仍不提供 Full Preview；版本 UUID 选择、当前采用标记、窗口身份和单侧重建规则未修改。

### 五、修改文件

- `Apps/CosmosOS/Cosmos Toolbox/ArtifactReviewModels.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactPreviewRenderer.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactImagePreviewLoader.swift`（新增）
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactImageRenderer.swift`（新增）
- `Apps/CosmosOS/Cosmos ToolboxTests/ArtifactImageRendererTests.swift`（新增）
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-08-26_Cosmos_OS_Development_Log.md`（新增）

未修改 `project.pbxproj`、持久化 Model、Store、Workflow Transition、Adoption、Recovery / File Manager、Task Package、Harness / AI Adapter、Artifact Version Logic、HTML Renderer / Security Policy 或真实 Artifact 文件。

### 六、自动验证

- Universal macOS Debug Build：`BUILD SUCCEEDED`，arm64 + x86_64，`CODE_SIGNING_ALLOWED=NO`。
- Unit Tests：91/91 passed，0 failed，0 skipped；在 70 项正式基线上新增 21 项 Image Renderer 覆盖。
- 覆盖内容包括 PNG / JPEG classification、Registry、二进制不进入 UTF-8、签名与声明冲突、损坏 / 截断 / 伪装 / 缺失 / 不支持 / 多帧、资源预算和整数溢出、方向、sRGB / Display P3、文件指纹变化、取消、共享解码门限、capabilities、Retina / 非 Retina 缩放、document identity、mixed Compare、左右状态隔离和临时 Fixture 清理。
- 全部既有 HTML CSP、WKContentRuleList、Navigation Policy、Source 原文、JavaScript 交互隔离、单版本 Review / Full Preview、Version Compare、Workflow / Adoption / Recovery 测试继续通过。
- `git diff --check`：通过。
- 沙箱内首次验证仍受 Swift Preview 插件与系统测试通知权限限制；相同命令在系统 Xcode 环境复跑成功，确认不是源码失败。

### 七、Fixture Window UI Smoke

- 测试 target 在系统临时目录动态生成 PNG / JPEG，并直接构建 typed `ArtifactReviewDocument`；没有调用真实 Store、Harness 或 Adoption。
- 独立 NSWindow Harness 成功构建并展示：单版本 Image Full Preview、Image | Image、HTML | Image、Image | HTML、Image | Unsupported。
- Light / Dark appearance、窗口扩展至不同尺寸、图片自适应画布、Full Preview 边界和 Compare 最小内容尺寸通过 smoke。
- Fit / 100% / 10%–400% Zoom、Retina / 非 Retina 计算、左右 View Model 状态隔离和 document identity 由自动测试验证。
- Fixture 窗口关闭后临时目录被删除，并断言不存在；仓库中没有遗留测试图片或生成物。
- 本次是自动化 Fixture Window smoke，不声称完成产品所有按钮的人工视觉点击验收；如需像素级视觉判断，后续由产品负责人使用独立 Fixture 进行人工验收。

### 八、真实业务数据不变证明

- 只读解析 `cosmos.zhuowang.workflows.v1` 后确认：01–05 为 `approved`，06 为 `ready`。
- 产品原型已纳管版本仍仅为 V1 / V3 / V4，V3 的 `isApprovedVersion` 为 true；V2 未进入 Store。
- Workflow 业务键 canonical Data SHA-256 记录为：`a7e3dd5f7e2dc1c62f62d0e7490b660df59b3947eb0f90e293d7ad617dd02b61`。未输出业务内容、凭据或敏感值。
- V1：`99aa1cf0db2f030a629e813d42744c60335a6175e619f798833c4dcd18c17823`
- V2：`4587af3ecda7e1823b50567619dbf40c559f1bba6b22d2bfb3a1ac9937036eb6`（未纳管，未修改）
- V3：`d8150faf51bac2f1b8ec11a4a007c4e70c5dcd821619c5d34531eb4dae0264ed`
- V4：`6911e40666e459f6afa42fa08690d167503644de65565b45eedaba7f0d0bc489`
- 四个规范路径文件哈希与实施前记录一致；未运行 Cosmos OS 真实业务流程，未生成或采用 Artifact。

### 九、剩余风险与范围

- ImageIO 已开始的单次底层解码不能被 Task 强制中断；当前通过硬预算、单并发门限和完成后丢弃取消结果控制资源风险。
- 文件指纹检查用于发现预览期间的变化，但不替代未来持久化层的 security-scoped bookmark、文件哈希或 Sidecar Manifest。
- Phase 1 没有 Image Adoption、持久化 Payload、Recovery、缩略图缓存、编辑、OCR、Annotation、动画播放或外部 URL 图片。
- PDF、Figma、Pixso 和外部文档 Renderer 仍未实现。
- 本轮未暂存、未 commit、未 push、未创建 Tag。

### 十、推荐下一步

- 先由产品负责人决定是否需要独立 Fixture 的人工视觉验收。
- 下一最小架构阶段建议为 PDF Renderer Phase 1 只读设计，继续保持 Persistent Payload / Adoption / Recovery 改造延期。
