# Cosmos OS Development Log

## 2026-08-19 P0 持久化稳定性收口

---

## 一、本次目标

- 检查 AI Provider、AI Connection、Tool Integration、Agent/Tool Route 的 UserDefaults 持久化链路。
- 将旧数据兼容、解码失败保护、backup 和防空数据覆盖提升到 Workflow Store 的安全级别。
- 不清空、不重置、不删除现有用户配置。
- 不改变已人工验收的 01-04 Workflow 状态与完整策划案 V1 采用状态。
- 统一 Development Log 目录并修正文档中过度描述 HTML Adapter 的内容。

---

## 二、人工验收基线

用户已在实际运行的 Cosmos OS 中确认：

- 01-04 Workflow 均为“已确认”；
- 完整策划案当前采用版本为 V1；
- 工作产物已通过本地灾备恢复重新出现；
- Figma 不再出现在“执行 AI”列表中，只作为 Tool 出现。

本次开发不重新生成前四步，也不启动 App 改写现有运行数据。

---

## 三、持久化安全实现

以下四类 payload 已加入向后兼容解码：

- AI Provider；
- AI Connection；
- Tool Integration；
- Agent/Tool Route。

对应 Store 现在会区分：

```text
存储键不存在
成功读取当前 payload
当前 payload 失败但 backup 可恢复
当前 payload 与 backup 均不可恢复，进入写锁
```

具体规则：

1. 只有存储键真正不存在时才写入默认配置。
2. 已保存的空数组属于有效用户数据，不会被自动替换为默认配置。
3. 当前 payload 解码失败时先尝试上一份 backup。
4. backup 可恢复时先保留 backup，下一次保存不会用损坏的当前 payload 覆盖它。
5. 当前 payload 与 backup 均不可恢复时锁定对应写入路径，保护原始字节和 backup。
6. 每次刷新 backup 前重新解码当前 payload；只有解码成功才允许覆盖 backup。
7. Workflow backup 刷新同样增加当前 payload 重新解码验证。
8. AI Provider 无法恢复时跳过默认 Provider 初始化、Provider ID 规范化和旧 Figma Provider 清理，避免间接改写 Workflow 引用。

---

## 四、文档整理

- 将 `Docs/2026-08-18_Workflow_Adapter阶段完成.md` 移动到 `Docs/Development Log/`。
- 保留原日志历史内容，不保留重复副本。
- 将 HTML Prototype Adapter 明确为“占位实现已完成、端到端执行尚未接通”。
- 更新 `Docs/07_Cosmos_OS_Current_Status.md`，记录本次 P0 安全边界、人工验收基线和剩余风险。

---

## 五、涉及文件

- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowModels.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowStore.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAIConnectionModels.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAIConnectionStore.swift`
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-08-18_Workflow_Adapter阶段完成.md`
- `Docs/Development Log/2026-08-19_Cosmos_OS_Development_Log.md`

---

## 六、构建与验证

执行：

```text
xcodebuild -project "Apps/CosmosOS/Cosmos Toolbox.xcodeproj" -scheme "Cosmos Toolbox" -configuration Debug -destination "generic/platform=macOS" -derivedDataPath /tmp/CosmosToolboxP0Build CODE_SIGNING_ALLOWED=NO build
```

结果：

```text
BUILD SUCCEEDED
```

构建为 arm64 + x86_64 macOS Universal App。

Codex 构建阶段没有自动启动 App。随后用户在更新后的实际运行环境中完成人工验收：

- 01-04 Workflow 仍为“已确认”；
- 05「产品原型设计」仍为“可开始”；
- 完整策划案当前采用版本仍为 V1；
- “执行 AI”列表中没有 Figma；
- Tool 中仍正常存在 Figma；
- 工作产物和历史版本均正常。

本轮 P0 修改未造成 Workflow 状态、当前采用版本、Artifact 或 Tool 配置回归。

---

## 七、剩余风险

- 业务数据仍主要依赖 UserDefaults，长期仍应迁移到更稳健的结构化存储。
- Campaign Store 与 Workspace Store 尚未具备同等级 backup / 写锁保护。
- 当前项目没有 Test Target，本次按要求没有临时引入测试架构；持久化回归自动化覆盖仍是技术债。
- HTML Artifact 尚未支持真实落盘、版本采用和灾备恢复。

---

## 八、Git 状态

- 本轮只包含 P0 持久化保护、Development Log 目录整理和状态同步相关修改；
- 提交信息：`fix: 完善 AI 与工具配置持久化保护`；
- 推送目标：`origin/main`。

---

## 九、下一步建议

P0 持久化边界已具备进入 Step 05 的安全基础。

下一阶段仍应采用最小完整闭环：

```text
AI Provider
+
Tool
→ Task Package
→ Adapter orchestration
→ human review
→ versioned Artifact
→ local file
→ disaster recovery
```

不要把占位 HTML Adapter 视为已经完成该闭环。

---

## 2026-08-19 Step 05 第一条真实 HTML 产品原型闭环

### 一、本次目标

- 以 DeepSeek Harness + HTML Prototype 验证通用 AI Provider + Tool 架构。
- 打通 Task Package、不可变执行快照、Coordinator、双 Registry、HTML Draft、人工审核、版本化落盘与 Workflow 状态推进。
- 不接入 Figma / Pixso 自动化，不迁移 SwiftData，不增加 sidecar manifest。
- 不启动 App，不清空或改写既有 01-04、Step 05/06 与完整策划案 V1 运行数据。

### 二、最终执行架构

```text
Workflow Step 05 / prototypeDesign
→ Provider + Connection + Tool + Route selection
→ immutable Execution Snapshot
→ ZhuowangWorkflowExecutionCoordinator
→ AI Execution Adapter Registry
→ DeepSeek Harness raw HTML
→ Tool Adapter Registry
→ ZhuowangHTMLPrototypeAdapter validation
→ HTML Artifact Draft
→ WebKit preview / source review
→ human adoption
→ versioned .html file
→ AI Run + Approval + Artifact provenance
→ Step 05 approved
→ Step 06 ready
```

View 不再判断具体 Tool；Coordinator 通过 Registry 查找 AI 与 Tool Adapter。Figma 仍仅为 Tool，本轮没有实现 Figma 自动执行。

### 三、数据安全与兼容

- HTML Tool、DeepSeek Connection、Figma Tool、DeepSeek HTML Route 使用稳定 UUID。
- 默认 Connection 不再包含历史 Figma Provider Connection；启动迁移只按历史内置 Connection 的精确 UUID 删除，不重置用户配置。
- Tool Integration capability 使用向后兼容解码；旧 Figma Tool 可推断 `prototypeDesign`。
- AI Run / Artifact provenance 均为可选字段，旧 Codable payload 保持可解码。
- Artifact 使用稳定 logical key；旧 Artifact 回退到显示名称分组。
- V1/V2/V3 文件追加写入，目标版本已存在时停止采用，不覆盖或删除历史。
- 只有 HTML 文件写入成功并创建采用事务后，Step 05 才进入已确认并解锁 Step 06。
- 新 HTML 写入 `05_产品原型`；灾备扫描兼容 `05_Figma原型`、`05_产品原型`、`05_原型设计`，不移动或重命名旧文件。
- 本次未启动 Cosmos OS，实际人工验收基线未被触碰。

### 四、HTML 结果与审核

- HTML Adapter 使用 AI 返回的真实内容，不再生成 Placeholder。
- 校验非空、UTF-8、完整 html/head/body 结构，并拒绝 Placeholder。
- 自动注入限制外部资源的 CSP；预览 WebView 使用 non-persistent data store 并阻止外部顶层导航。
- Result UI 支持真实 HTML 预览与源码切换；采用失败时保留审核界面并提示 Workflow 未改变。

### 五、测试与构建

新增最小 `Cosmos ToolboxTests` Unit Test Target，覆盖：

- HTML Tool stable ID 与 `prototypeDesign` capability；
- Execution Snapshot Codable round trip，包含 Provider / Connection / Tool / Route；
- Registry 找到 HTML Adapter；
- 真实 HTML 成功形成 Draft，并拒绝 Placeholder；
- V1 → V2 追加与切换当前采用版本时保留历史；
- HTML 历史原型目录灾备扫描；
- Step 05 采用前不解锁 Step 06，采用后才解锁。

验证结果：

```text
Universal macOS Debug Build: SUCCEEDED (arm64 + x86_64)
Unit Tests: SUCCEEDED (7/7)
git diff --check: PASSED
```

首次沙箱内 Build 仅因 Xcode `sandbox-exec: Operation not permitted` 失败；在获准的沙箱外使用相同命令重跑后成功，不属于代码编译失败。

### 六、涉及文件

- `Apps/CosmosOS/Cosmos Toolbox.xcodeproj/project.pbxproj`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAIConnectionModels.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAIConnectionStore.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangAIExecutionResultView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangCampaignDetailView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangHTMLPrototypeAdapter.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangTaskPackageBuilder.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangTaskPackagePreviewView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangToolAdapter.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowExecutionCoordinator.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowModels.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowStore.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowTransitionLogic.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkflowView.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangWorkspaceFileManager.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangStep05Tests.swift`
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-08-19_Cosmos_OS_Development_Log.md`

### 七、待人工验收与剩余风险

- 使用现有活动选择 DeepSeek Harness + HTML Prototype，验证真实 Harness 返回、HTML 预览、源码与修订交互。
- 采用 V1 后确认 `.html` 文件、Artifact provenance、Step 05 已确认与 Step 06 可开始。
- 再次执行并采用 V2，确认 V1 文件和历史版本仍存在；切换当前采用版本不删除其他版本。
- 业务数据仍基于 UserDefaults；Artifact sidecar manifest 与 SwiftData 迁移均按本轮边界延期。
- 自动测试覆盖纯逻辑与临时目录文件扫描，没有替代实际 Harness、WebKit UI 与用户工作区的人工验收。

### 八、Git

- 本轮未 commit。
- 本轮未 push。
