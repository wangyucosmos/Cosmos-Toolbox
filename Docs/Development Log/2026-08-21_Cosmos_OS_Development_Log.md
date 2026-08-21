# Cosmos OS Development Log

## 2026-08-21 Step 05 真实闭环验收与 Harness Runtime 技术债记录

### 一、本次目标

- 验收 Step 05 第一条真实产品原型闭环。
- 确认 Cosmos OS 与 Harness Web 共用已配置的 credentials store。
- 记录 DeepSeek Harness runtime 版本解耦技术债，不实施版本重构。

### 二、真实运行结果

```text
Task Package
→ DeepSeek Harness
→ HTML Prototype Adapter
→ real HTML Artifact Draft
→ HTML preview and source review
→ human adoption
→ versioned .html Artifact V1
→ Step 05 approved
→ Step 06 ready
```

- `MISSING_CREDENTIAL` 不再出现。
- 实际 headless runtime：`@deepseek-ai/dsh@0.1.0-rc.6`。
- 实际 `DSH_HOME`：`$HOME/.dsh-rc8-clean`。
- API Key 未进入 Cosmos OS、Swift、UserDefaults、Task Package 或 Git；Harness 通过自己的 local credentials service 完成解析。
- DeepSeek 返回完整、可运行的单文件 HTML。
- HTML 的 DOCTYPE、`html`、`head`、`body`、UTF-8、内联 CSS / JavaScript 均通过检查。
- HTML 预览、源码查看与基础登录交互验证通过。
- 人工采用成功；正式 HTML Artifact V1 已落盘并登记为当前采用版本。
- Step 05 已确认，Step 06 已解锁为可开始。

### 三、Harness Runtime Compatibility Layer

此前成功运行基线：

```text
Swift Adapter
→ npx @deepseek-ai/dsh@0.1.0-rc.6
→ DSH_HOME=$HOME/.dsh-rc8-clean
```

该链路已经通过真实验收，但 Swift Adapter 绑定具体 release-candidate 版本会带来升级维护风险。本次按 DeepSeek-only 范围加入兼容层：

```text
Cosmos OS
↓
Harness Runtime Adapter
↓
当前环境可用 Harness Runtime
```

实现结果：

- 自动发现环境指定、PATH、`~/.local/bin`、Homebrew 常用位置中的 `dsh`；
- 通过 runtime 自身读取版本并检查 `--profile headless` 能力；
- 优先从当前进程环境读取 `DSH_HOME`，其次读取 Harness LaunchAgent，最后使用官方默认 `~/.dsh`；
- 正常路径直接调用发现到的 runtime，不固定 `rc.6`、`rc.8` 或其他具体版本；
- 发现失败时保留不带具体版本号的 npx 兼容 fallback；
- 输出 runtime 来源、路径、版本与 `DSH_HOME` 日志；
- Workflow、Artifact、HTML Adapter 与 Step 05 业务链路均未修改；
- 未实现 Claude、ChatGPT/Codex、Gemini 或通用 AI Runtime Adapter Layer。

### 四、验证与变更边界

- macOS Debug Build：`BUILD SUCCEEDED`。
- Unit Tests：11/11 通过，其中新增 2 项覆盖 runtime 版本/headless 发现与 LaunchAgent `DSH_HOME` 解析。
- 未修改 Workflow、Artifact、HTML Adapter、Harness 配置、credentials 或 API Key。
- 未启动 App，未执行真实 Harness 任务；兼容层后的 Step 05 运行态 smoke test 待人工完成。
- 未 commit。
- 未 push。

## 2026-08-21 Prototype Fidelity Control

### 一、本次目标

- 为 `prototypeDesign` 增加工具无关的 Prototype Execution Profile。
- 支持 Low-fi / Mid-fi / High-fi 与四种原型风格，并约束有效组合。
- 将用户选择持久化到 Workflow Step，并冻结到执行快照与 Artifact provenance。
- 由 Tool / Route-specific Execution Specification 将 Profile 映射为当前 HTML Route Prompt，不把 Step 05 绑定为 HTML。

### 二、实现结果

- 新增 Codable `ZhuowangPrototypeFidelity`、`ZhuowangPrototypeStyle` 与 `ZhuowangPrototypeExecutionProfile`。
- 历史 Workflow 缺少 Profile 时默认 High-fi + 高保真活动页，保持已验收行为。
- Workflow Store 持久化 Profile；冲突组合自动切换到对应保真度的推荐风格。
- Snapshot 冻结 Fidelity / Style；AI Run 与 Artifact 保存可选 Profile provenance。
- UI 仅按 `requiredCapabilities.contains(.prototypeDesign)` 展示配置，不依赖 Step Kind。
- Task Package Preview 明确展示 Fidelity / Style，并更新完整冻结提示。
- DeepSeek Harness → HTML Prototype Route 已映射 Low-fi / Mid-fi / High-fi 与四种风格要求；原有 HTML 执行契约、内部策划标记转换规则和质量校验保持不变。
- Artifact logical key 不包含 Fidelity / Style，不会拆分历史版本链。

### 三、验证与边界

- macOS Debug Build：成功。
- Unit Tests：30/30 通过。
- `git diff --check`：通过。
- 未修改 HTML Adapter、HTML Validator、Runtime Adapter、Artifact Version Logic 或 Workspace File Manager。
- 未启动 App，未执行 Harness，未 commit，未 push。
- 待人工验收：Profile 控件持久化、Preview 冻结信息，以及 Low-fi / High-fi 两种真实生成效果。

## 2026-08-21 Artifact Review Workspace Phase 1

### 一、本次目标

- 将 AI Result 中的小尺寸 HTML Preview 升级为独立 Artifact Review Workspace。
- 建立 Artifact 类型无关的 Renderer / Registry 边界，Phase 1 只接入 HTML Renderer。
- 支持 375px / 390px 真实 WebView 手机 viewport、Preview / Source 和完整预览模式。
- Review 信息仅使用 Draft、冻结 Execution Snapshot 或 Artifact provenance，不读取 Workflow 当前选择。

### 二、实现结果

- 新增不可变 `ArtifactReviewDocument`，可从 Draft + Snapshot 或历史 Artifact 构建 Review 输入。
- 新增 `ArtifactPreviewRenderer` 与 Registry；未知 / 未接入类型使用安全 fallback，不崩溃。
- 新增 HTML Renderer，使用 non-persistent `WKWebView` 原样加载 Artifact HTML，不补写、不替换、不缩放截图。
- 新增独立、可缩放、支持 macOS 全屏的 Artifact Review Workspace 窗口。
- Workspace 支持 Preview / Source、375px / 390px 手机框和隐藏元数据的 Full Preview 状态。
- AI Execution Result 不再承载小尺寸 HTML Preview / Source Tabs，改为 Draft 摘要与“打开完整预览”入口。
- 历史 Artifact 缺少 provenance 或内嵌内容时可安全显示默认信息，并只读加载现有本地内容。

### 三、验证与边界

- macOS Debug Build：成功。
- Unit Tests：37/37 通过，其中 Artifact Review Workspace 7/7。
- `git diff --check`：通过。
- 未修改 Workflow Model、Artifact Model、HTML Adapter / Validator / Normalizer、Runtime Adapter、Artifact Version Logic、Workspace File Manager 或 logical key。
- 未启动 Harness，未重新生成或修改 V1/V2 Artifact，未 commit，未 push。
- 待人工验收：独立窗口尺寸、375/390 页面滚动与点击、Full Preview 交互、源码阅读和深浅色外观。

## 2026-08-21 Artifact Detail 接入 Review Workspace

### 一、本次目标

- 将已经采用的 V1 / V2 / V3 Artifact 从旧源码正文入口接入统一 Artifact Review Workspace。
- 保留文件信息、版本历史、provenance 与显式源码查看。
- 让 Draft 与 adopted Artifact 最终使用同一个 `ArtifactReviewWindowManager`。

### 二、实现结果

- Artifact Detail 默认展示 Preview Workspace 入口，不再把 HTML 源码作为默认正文。
- 用户仍可切换“查看源码”，原有只读正文展示保持可用。
- 切换 V1 / V2 / V3 时恢复 Preview 默认态，并以当前选中 Artifact 构建 `ArtifactReviewDocument`。
- adopted Artifact 与 AI Result Draft 均调用 `ArtifactReviewWindowManager.shared.open(...)`。
- HTML 继续由既有 HTML Renderer 渲染；未支持类型继续使用 Registry fallback。
- 老 Artifact 缺少 provenance 时继续显示安全默认信息，不读取当前 Workflow 选择补写来源。

### 三、验证与边界

- macOS Debug Build：成功。
- Unit Tests：39/39 通过；新增覆盖 adopted HTML V1 / V2 / V3 与 Artifact Detail 默认 Preview。
- `git diff --check`：通过。
- 未修改 Artifact 数据模型、版本逻辑、Renderer Registry 架构、HTML Adapter、Workflow 或 AI Execution 流程。
- 未启动 Harness，未生成或修改 Artifact 文件，未 commit，未 push。
- 待人工验收：Artifact Detail 切换版本后打开的窗口是否对应当前版本、Preview / Source 切换，以及旧 Artifact 的 fallback 展示。

## 2026-08-21 当前阶段 Milestone 收尾

### 一、Milestone 范围

本阶段完成了四条连续能力：

1. Step 05 Prototype Generation：`prototypeDesign` 经 Provider / Connection / Tool / Route 冻结快照进入 Coordinator，DeepSeek Harness 返回 HTML，经 Normalizer、Validator 形成 Draft，人工采用后版本化落盘并解锁 Step 06。
2. Prototype Fidelity Control：工具无关的 Fidelity / Style Profile 持久化到 Workflow Step，执行时冻结到 Snapshot 与 provenance，再由具体 Tool / Route 映射为执行要求。
3. Artifact Review Workspace：建立 `ArtifactReviewDocument → Renderer Registry → Review Workspace` 的统一预览边界，Phase 1 接入 HTML Renderer、真实移动 WebView、Preview / Source 与 Full Preview。
4. Artifact Detail 接入：Draft 与 adopted V1 / V2 / V3 Artifact 统一通过 `ArtifactReviewWindowManager` 打开同一 Review Workspace。

### 二、当前架构关系

```text
Workflow Step
→ declares Capability
→ persists user execution profile and selections
→ freezes Execution Snapshot
→ selected Tool / Route resolves execution specification
→ Coordinator produces Artifact Draft
→ adoption creates versioned Artifact + provenance
→ ArtifactReviewDocument isolates review input
→ ArtifactPreviewRendererRegistry selects Renderer
→ ArtifactReviewWorkspace presents Draft or adopted Artifact
```

Workflow 不关心 HTML；`prototypeDesign` 是 Capability，不是 Artifact 类型。HTML 只是当前 Tool + Adapter + Renderer 的第一条实现。Artifact 保存版本与 provenance，Renderer 只负责展示，Review Workspace 不读取当前 Workflow 状态覆盖历史执行信息。

### 三、自动验证基线

- macOS Debug Build：成功。
- Unit Tests：39/39 通过。
- `git diff --check`：通过。
- Step 05 首条真实 HTML V1 闭环已人工验收；Fidelity UI 与 adopted Artifact Detail 最新入口仍需下一次人工 UI 验收。

### 四、未完成事项

- Browser / desktop-width Preview。
- V1 / V2 / V3 并排对比或内容 diff。
- Review Annotation、锚点批注、审批备注与标记。
- Figma / Pixso / Image / PDF Renderer。
- Figma / Pixso 正式 Artifact adoption 前所需的 Artifact Abstraction Layer。
- 更广泛的持久化、UI 与恢复回归测试。

### 五、Git 交接状态

- 当前分支：`main`，状态行显示 `main...origin/main`，未显示 ahead / behind。
- 工作树非 clean；本阶段源码、测试和文档尚未 commit。
- 未 commit，未 push。
- 建议一次性提交本 milestone，避免拆分后造成 Xcode 项目引用、新文件、测试和文档不完整。

## 2026-08-21 Artifact Review Renderer Security Boundary Phase 1

### 一、本次目标

- 将 HTML Preview 的信任边界从生成期 Artifact CSP 提升到 Renderer / Preview 层。
- 让新生成、历史版本、本地恢复、缺少 provenance 或没有 CSP 的 HTML 使用同一只读预览安全策略。
- 保持 Source、Artifact 内容、本地文件、Workflow、版本逻辑与真实业务数据不变。

### 二、根因与安全架构

此前 HTML Adapter 会给新生成结果补充 CSP，但 `HTMLArtifactPreviewRenderer` 直接把 Artifact 原文交给 `WKWebView.loadHTMLString`。因此 Renderer 本身没有独立 CSP，历史或恢复内容的安全性依赖文件是否已有策略；non-persistent data store 和顶层导航取消也不能阻止子资源、fetch/XHR/WebSocket、表单等全部边界。

本轮建立以下 Preview-only 链路：

```text
ArtifactReviewDocument.content 原文
→ ArtifactHTMLPreviewSecurityPolicy
→ 内存 secured Preview HTML
→ WKContentRuleList 成功安装
→ non-persistent WKWebView
→ Navigation Policy
```

- Adapter CSP：仅是新 Artifact 的生成期质量 / 安全基线，不再被视为 Review 信任边界。
- Renderer CSP：无论原文是否已有 CSP，都在内存 Preview 副本中独立加入；覆盖 default/connect/form/base/frame/object/worker/script/style/image/font/media 边界，不允许 `unsafe-eval`。
- 兼容范围：保留现有原型必需的 inline CSS、inline JavaScript / event handlers；图片允许 `data:` / `blob:`，字体允许 `data:`，媒体允许 `data:` / `blob:`。
- WebKit 内容规则：跨资源类型阻断 HTTP、HTTPS、WS、WSS 与 file；规则安装成功前不加载 Artifact，失败时只显示受控错误页。
- non-persistent store：只负责会话数据不持久化，不替代网络隔离。
- Navigation Policy：只允许 `about:`；HTTP、HTTPS、file、mailto、data、blob 与未知 scheme 导航均取消。`data:` / `blob:` 只保留为 CSP 允许的局部子资源。

### 三、实现与测试

- `ArtifactHTMLRenderer.swift`：新增可测试 Preview Security Policy、内存 CSP 处理、WebKit 内容规则编译、fail-closed 加载顺序和导航 scheme allowlist。
- `ArtifactReviewWorkspaceTests.swift`：增加无 / 有 CSP、完整指令、内容规则、导航、真实 WKWebView 内联交互、Source / Artifact / Fixture 不变、无 head / provenance 历史降级与 Registry fallback 覆盖。
- Unit Tests：47/47 passed，0 failed，0 skipped。
- 测试结果包：`/tmp/CosmosToolboxRendererSecurityTests/Logs/Test/Test-Cosmos Toolbox-2026.08.21_16-36-40-+0800.xcresult`。
- Universal macOS Debug Build：`BUILD SUCCEEDED`（generic macOS，arm64 + x86_64，`CODE_SIGNING_ALLOWED=NO`）。沙箱内首次运行因 Swift 宏插件 `sandbox-exec` 权限失败；同一命令在沙箱外复跑成功，确认不是源码编译错误。
- `git diff --check`：通过。

### 四、只读 UI Smoke Test

- `浙江活动测试` Workflow 01-05 仍为已确认，06 客服文档仍为可开始。
- 完整策划案当前采用仍为 V1；产品原型当前采用仍为 V3。
- Artifact Detail 纳管 V1 / V3 / V4，三者 Preview 均可打开；选择历史版本只用于查看，未点击“设为当前版本”。
- V3 Preview / Source、375px / 390px、页面滚动、现有按钮状态切换与 Full Preview 正常。
- Source 首部仍显示原始 Artifact CSP，未出现 Renderer Preview marker，证明 Source 未被 secured Preview 副本替换。
- 未运行 Harness，未生成新 Artifact，测试后已退出 App。

### 五、数据不变证明

- V1 SHA-256：`99aa1cf0db2f030a629e813d42744c60335a6175e619f798833c4dcd18c17823`
- V2 SHA-256：`4587af3ecda7e1823b50567619dbf40c559f1bba6b22d2bfb3a1ac9937036eb6`（未纳管，仍在原位）
- V3 SHA-256：`d8150faf51bac2f1b8ec11a4a007c4e70c5dcd821619c5d34531eb4dae0264ed`
- V4 SHA-256：`6911e40666e459f6afa42fa08690d167503644de65565b45eedaba7f0d0bc489`
- 上述哈希与验收前完全一致，文件大小与 mtime 未变化。
- Cosmos Toolbox UserDefaults 域验收前后导出 SHA-256 均为 `3eab3d620b6a267ddb7ced411f5c706c2e3e45fa8a7ac26b913de975b9250b7c`。

### 六、边界与剩余风险

- 未修改 Workflow / Artifact Model、版本或 logical key、Validator、Harness / AI Adapter、Adoption、Recovery 或 Workspace File Manager。
- Renderer 仍为兼容现有交互原型而允许 inline JavaScript / event handlers 及有限 `data:` / `blob:` 子资源；这是受限 Artifact Preview，不等同于通用 Browser sandbox。
- Browser Preview、Version Compare、Annotation、新 Renderer 与“待确认 / TBD”质量校验均未处理。
- 未 commit，未 push，未创建 Tag。
