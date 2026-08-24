# Cosmos OS Development Log

## 2026-08-24 Artifact Version Compare Phase 1

### 一、本次目标

- 在 Artifact Detail 的已纳管版本集合上提供双版本并排比较。
- 保持 Artifact、Workflow、Adoption、版本逻辑、Renderer Security Boundary 与真实业务数据不变。
- Phase 1 只实现基础 Compare，不包含 Diff、Annotation、Browser / Desktop Preview 或新 Renderer。

### 二、最终交互

- 同一 `versionGroupKey` 至少有两个已纳管版本时，Artifact Detail 显示可用的“比较版本”入口；数据只来自现有 Store 管理集合，不扫描本地目录。
- 左侧默认当前采用版本；右侧优先使用 Artifact Detail 当前选中的历史版本，否则选择最高版本号的其他已纳管版本。
- 当前真实基线默认 V3 | V4；Detail 选择 V1 后打开为 V3 | V1。
- 左右选择使用 Artifact UUID；选择对侧版本时自动交换，禁止两侧引用同一 Artifact。
- 两侧独立切换 Preview / Source、独立滚动；375px / 390px 为 Compare 全局共享 viewport。
- 当前采用版本有明确标记。Compare 不提供 Adoption、设为当前版本、Full Preview、Diff、Annotation 或审批备注。

### 三、实现架构

```text
managed Artifact version collection
→ ArtifactVersionCompareState
→ ArtifactVersionCompareWorkspace
→ left / right ArtifactReviewPane
→ ArtifactPreviewRendererRegistry
→ Renderer Security Boundary
→ secured WKWebView Preview / unchanged Source
```

- 从单版本 Workspace 抽取最小通用 `ArtifactReviewPane`；单版本和 Compare 共同使用，不复制 Renderer Registry 或 HTML 安全策略。
- Compare 状态只存在于当前窗口的 SwiftUI `@State`：左右 Artifact UUID、左右 Display Mode、共享移动 viewport。
- 每侧 Renderer Preview 使用 `document.id` 作为 SwiftUI identity；切换版本只重建目标侧，不保留上一版本 DOM / JavaScript 状态，也不影响另一侧。
- Compare 窗口身份固定为 `campaignID + versionGroupKey`；左右切换和交换不改变身份，重复打开时前置现有窗口。
- 初始窗口 1480×900，最小 1180×720，支持原生缩放、全屏和关闭。

### 四、ArtifactReviewDocument 身份硬化

- Adopted Artifact 构建的 Document 固定使用 `artifact.id`。
- Draft initializer 不再隐式生成随机 UUID，调用方必须继续显式传入 execution snapshot ID 或 task package ID。
- 未修改 Artifact Model、Artifact UUID、持久化结构或迁移逻辑；Draft Review 的现有窗口语义保持不变。

### 五、自动验证

- Unit Tests：59/59 passed，0 failed，0 skipped；在原 47 项基础上新增 12 项 Compare 覆盖。
- 新增覆盖包括默认组合、Detail 选择 V1、UUID 交换、独立 Display Mode、共享 viewport、Document / content / provenance、当前采用标记不变、Renderer Security Policy、Source 原文、Registry fallback、稳定窗口身份、双 WKWebView JavaScript 状态隔离和 Fixture 仅含 V1 / V3 / V4。
- Universal macOS Debug Build：`BUILD SUCCEEDED`，arm64 + x86_64，`CODE_SIGNING_ALLOWED=NO`。
- `git diff --check`：通过。
- 沙箱内首次测试因 Swift Preview 宏插件 `sandbox-exec` 权限失败；同一测试命令在沙箱外复跑成功，确认不是源码编译失败。

### 六、只读 UI Smoke Test

- 默认 Compare 为 V3 | V4；Detail 选择 V1 后为 V3 | V1。
- 可切换版本组合；选择对侧版本会交换左右，当前采用 V3 标记正确。
- 左右 Preview / Source 独立；Source 显示对应 Artifact 原始 HTML。
- 375px / 390px 同步作用于 Preview；两侧长页面可独立滚动。
- 左侧登录交互后，右侧仍保持未登录，证明两个 WebView 的 JavaScript 状态不串联。
- 切换右侧版本时，左侧滚动与页面交互状态保持；目标侧重新加载正确 Document。
- Compare 窗口原生全屏、退出全屏、关闭、重开与 Window 菜单前置正常；稳定窗口 identity 未随版本组合变化。
- 单版本 V1 / V3 / V4 Review 正常，V4 Full Preview 可进入和退出。
- 未运行 Harness，未生成新 Artifact，未点击“设为当前版本”。

### 七、真实数据不变证明

- Cosmos Toolbox UserDefaults 域前后 SHA-256：`3eab3d620b6a267ddb7ced411f5c706c2e3e45fa8a7ac26b913de975b9250b7c`。
- V1：`99aa1cf0db2f030a629e813d42744c60335a6175e619f798833c4dcd18c17823`
- V2：`4587af3ecda7e1823b50567619dbf40c559f1bba6b22d2bfb3a1ac9937036eb6`（未纳管，仍在原位）
- V3：`d8150faf51bac2f1b8ec11a4a007c4e70c5dcd821619c5d34531eb4dae0264ed`
- V4：`6911e40666e459f6afa42fa08690d167503644de65565b45eedaba7f0d0bc489`
- 产品原型当前采用仍为 V3；Workflow 01–05 已确认、06 可开始；UserDefaults 与四个本地 Artifact 文件哈希均未变化。

### 八、边界与剩余风险

- 未修改 Workflow / Artifact 持久化 Model、Transition、Version Logic、Adoption、logical key / versionGroupKey、Harness / AI Adapter、HTML Adapter / Validator、Workspace File Manager、UserDefaults 或 Renderer Security Policy。
- 未纳管 V2 未进入 Compare 集合或测试 Fixture，未被导入、修改或删除。
- Compare Phase 1 不包含文本 / 语义 Diff、差异高亮、Annotation、Browser / Desktop Preview 或其他 Renderer。
- 双 WebView 自动测试与真实 UI 交互均通过，未观察到 WKContentRuleList 并发问题；未来扩大 Renderer 或网络能力时仍需重新核对该安全边界。
- 本轮未 commit、未 push、未创建 Tag，也未进行暂存。

---

## 2026-08-24 Artifact Preview Abstraction Layer Phase 1

### 一、本次目标

- 解除 Artifact Review 对单一 `String content` 和固定 Mobile Viewport Renderer 接口的硬依赖。
- 只在 Review 投影与 Renderer 输入层建立类型化边界，不修改持久化 Artifact、UserDefaults Schema、Workflow、Adoption、Recovery 或 Workspace File Manager。
- 保持现有 HTML 单版本 Review、Version Compare 和 Renderer Security Boundary 完全兼容。

### 二、最终数据流

```text
legacy Artifact / Draft
→ ArtifactReviewDocumentProjector
→ ArtifactReviewPayload
   ├─ inlineText
   ├─ localFile
   └─ unavailable
→ ArtifactPreviewInputResolver
→ typed ArtifactPreviewInput
→ ArtifactPreviewRendererRegistry
→ Renderer capabilities
→ secured HTML Preview or safe fallback
```

- Payload 只表达权威内容种类和只读引用，不隐藏文件 I/O。
- Resolver 只读取 Artifact 明确指向、媒体提示一致且受支持的本地文本文件，不扫描目录、不搜索主目录、不自动把 `location` 推断为外部 URL。
- PDF、图片和其他二进制在本阶段保留 typed local-file 引用，但不执行 UTF-8 解码，进入安全 fallback。
- 文件缺失、不可读、类型未知或 UTType / MIME / extension / legacy type 冲突均 fail safely。

### 三、Renderer 与 Workspace

- Registry 从只按 `ZhuowangArtifactType` 选择，升级为按 typed Preview Input 和 Media Type 选择。
- Renderer 明确声明 Preview、Source、Full Preview、Mobile Viewport 四项最小 capabilities。
- HTML Renderer 继续支持全部四项能力，并只进行 typed input 适配；CSP、WKContentRuleList、non-persistent store 和 Navigation Policy 均未修改或复制。
- Unsupported / unavailable fallback 不提供 Source、Full Preview 或 Mobile Viewport，不运行脚本或网络。
- 单版本 Workspace 和 Compare 根据 capabilities 显示控件；非法 Source / Full Preview 临时状态自动回退到 Preview / Workspace。
- Compare 两侧分别按自身 typed input 选择 Renderer；两个 HTML 侧继续共享 375px / 390px，其他侧只接收自己声明支持的能力。

### 四、修改文件

- `Apps/CosmosOS/Cosmos Toolbox/ArtifactReviewModels.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactPreviewRenderer.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactHTMLRenderer.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactReviewWorkspace.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ArtifactVersionCompareWorkspace.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ArtifactReviewWorkspaceTests.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ArtifactVersionCompareWorkspaceTests.swift`
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-08-24_Cosmos_OS_Development_Log.md`

未修改 Xcode project、持久化 Model、Store、Transition、Adoption、Recovery、File Manager、Task Package、Harness / AI Adapter 或 Renderer Security Policy。

### 五、自动验证

- Universal macOS Debug Build：`BUILD SUCCEEDED`，arm64 + x86_64，`CODE_SIGNING_ALLOWED=NO`。
- Unit Tests：70/70 passed，0 failed，0 skipped；在 59 项基线上新增 11 项 Review projection / typed input / capabilities / mixed Compare 覆盖。
- 新增覆盖包括：inline HTML、Markdown 和 plain text 原文；本地 UTF-8 HTML 引用与受控解析；二进制不调用 UTF-8 reader；缺失和冲突媒体 fallback；URL 字符串不被推断为外部引用；Document 稳定 ID；Artifact 不变；capability 状态规范化；mixed Compare 单侧 Source 回退；双 HTML Mobile Viewport 能力保持。
- 现有 HTML CSP、内容规则编译、Navigation Policy、内联按钮交互、Source 不变、双 WKWebView 隔离、Adoption / Recovery 和版本逻辑测试全部继续通过。
- 沙箱内首次测试仍会因 Swift Preview 宏插件 `sandbox-exec` 权限失败；同一命令在系统 Xcode 环境中复跑成功，不是源码编译失败。

### 六、只读 UI Smoke Test

- 单版本 V1、V3、V4 Preview 均打开正确版本；V3 Preview / Source、375px / 390px、Full Preview、滚动和本地按钮交互正常。
- Source 显示原始 HTML；Renderer 注入的 Preview CSP 未出现在 Source 中。
- Detail 选择 V1 后 Compare 为 V3 | V1；选择当前 V3 后默认 Compare 为 V3 | V4。
- Compare 左右 Preview / Source 独立，375px / 390px 共享；左右页面独立滚动，左侧签到反馈未改变右侧 DOM 状态。
- Compare 原生全屏、关闭和重开正常；当前采用标记始终为 V3。
- 真实业务数据中没有 unsupported/unavailable Artifact，因此该 UI fallback 使用独立 Fixture 构建 Workspace 验证，没有向 Store 注入测试数据。
- 未运行 Harness，未生成 Artifact，未点击 Adoption 或“设为当前版本”。

### 七、真实数据复核

- V1：`99aa1cf0db2f030a629e813d42744c60335a6175e619f798833c4dcd18c17823`
- V2：`4587af3ecda7e1823b50567619dbf40c559f1bba6b22d2bfb3a1ac9937036eb6`（未纳管，未导入、修改或删除）
- V3：`d8150faf51bac2f1b8ec11a4a007c4e70c5dcd821619c5d34531eb4dae0264ed`
- V4：`6911e40666e459f6afa42fa08690d167503644de65565b45eedaba7f0d0bc489`
- 上述文件哈希与实施前完全一致；历史目录中的 V1 / V2 副本哈希也未变化。
- UI 实时确认产品原型当前采用仍为 V3，Workflow 01–05 已确认、06 可开始。
- 应用偏好 plist 包含 `NSWindow Frame` 和 split-view 状态，真实 UI smoke 后文件被 macOS 重新序列化，whole-file SHA-256 从 `137df849...` 变为 `f05bf4f3...`。本轮未调用业务 Store 写入；实时 Workflow / adoption 状态未变化。后续若要求 UserDefaults 字节级证明，应在启动前分别快照业务键的 canonical value，而不能以包含窗口状态的整个 plist 文件哈希作为唯一证据。

### 八、范围与后续

- Phase 1 没有新增 Image、PDF、Figma、Pixso、External URL 或 External Document Renderer。
- 没有修改持久化 `ZhuowangArtifact` 或 Codable Schema，也没有迁移、回写历史 Artifact。
- 推荐下一最小阶段为 Image Renderer Phase 1：复用 typed local-file input，增加受限 ImageIO 解码、fit / original size / zoom 和无 Source 能力，继续暂缓持久化 payload descriptor。
- 本轮未暂存、未 commit、未 push、未创建 Tag。
