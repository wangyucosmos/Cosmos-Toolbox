# Cosmos OS Development Log

## 2026-08-20 Step 05 执行任务语义与 Preview 收口

### 一、本次目标

- 消除 Prototype 通用任务与 HTML Route 真实执行要求之间的语义冲突。
- 保持 Step 05 为 `prototypeDesign` 通用能力，不绑定 HTML。
- 在执行前明确展示冻结的 capability 与可读 Route。
- 不启动 App、不执行 DeepSeek Harness、不改写 Workflow、Artifact 或 UserDefaults 运行数据。

### 二、实现结果

- Prototype 核心任务改为：基于当前采用的上游 Artifacts，使用本轮所选 Tool 生成真实产品原型交付物，不改变已确认业务方案。
- 新增 `ZhuowangTaskExecutionSpecificationResolver`，由 capability + Tool ID + Route ID / adapter identifier 解析 Tool-specific instruction 与 Expected Outputs。
- DeepSeek Harness → HTML Prototype Route 明确要求完整、可直接运行的单文件 HTML，禁止 Markdown 围栏、说明文档替代、Placeholder 与再次等待确认。
- Preview Expected Outputs 改为真实 HTML Artifact，并逐项展示 `prototypeDesign（原型设计）` 与 `DeepSeek Harness → HTML Prototype`。
- 非 Prototype 步骤的 Task Package 文案不受影响。

### 三、验证

```text
Universal macOS Debug Build: SUCCEEDED (arm64 + x86_64)
Unit Tests: SUCCEEDED (9/9)
git diff --check: PASSED
```

新增测试覆盖 HTML Route execution specification，以及无具体 Tool 时 Prototype 核心业务目标仍保持 Tool-agnostic。

### 四、涉及文件

- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangTaskExecutionSpecification.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangTaskPackageBuilder.swift`
- `Apps/CosmosOS/Cosmos Toolbox/ZhuowangTaskPackagePreviewView.swift`
- `Apps/CosmosOS/Cosmos ToolboxTests/ZhuowangStep05Tests.swift`
- `Docs/07_Cosmos_OS_Current_Status.md`
- `Docs/Development Log/2026-08-20_Cosmos_OS_Development_Log.md`

`project.pbxproj` 仅被 Xcode 自动规范化对象段落顺序，没有 target、Build Setting 或依赖语义变化。

### 五、待人工验收

- 重新打开 Step 05 Task Package Preview，核对 Expected Outputs、Capability 与 Route。
- 确认最终任务正文不再包含“准备原型设计执行说明”或“等待用户确认后再制作”。
- 核对通过后再执行真实 DeepSeek Harness。

### 六、Git

- 未 commit。
- 未 push。
