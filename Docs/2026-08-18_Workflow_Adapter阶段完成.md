# Cosmos OS Development Log

## 2026-08-18 Workflow Adapter 阶段完成

------------------------------------------------------------------------

## 一、本次开发目标

完成 Cosmos OS 工作流执行架构第一阶段建设。

本阶段目标：

建立 AI Workflow 与外部执行工具之间的统一连接层，使 Cosmos OS 不绑定单一
AI 或单一原型工具。

核心设计：

> AI 负责理解任务和生成内容，Tool Adapter
> 负责调用具体执行能力并返回标准化工作产物。

------------------------------------------------------------------------

# 二、当前执行链路

    Campaign
        ↓
    Workflow Step
        ↓
    ZhuowangAITaskPackage
        ↓
    Tool Adapter
        ↓
    具体执行工具
        ↓
    ZhuowangArtifact

------------------------------------------------------------------------

# 三、已完成模块

## 1. ZhuowangToolAdapter

文件：

`ZhuowangToolAdapter.swift`

状态：

✅ 已完成

作用：

建立 Cosmos OS 外部工具统一执行协议。

设计原则：

不绑定具体产品。

未来支持：

-   Figma
-   Pixso
-   HTML Prototype
-   Web 原型工具
-   其他未来执行工具

Workflow 不直接依赖具体工具，而通过 Adapter 调度。

------------------------------------------------------------------------

## 2. ZhuowangHTMLPrototypeAdapter

文件：

`ZhuowangHTMLPrototypeAdapter.swift`

状态：

✅ 已完成

作用：

作为 Cosmos OS 第一个真实执行 Adapter。

当前能力：

`prototypeDesign`

输入：

`ZhuowangAITaskPackage`

输出：

`ZhuowangArtifact`

当前输出类型：

HTML Prototype

------------------------------------------------------------------------

# 四、原型设计能力架构原则

Cosmos OS 不固定使用 Figma。

未来原型设计流程：

    Workflow Step
          ↓
    用户选择执行方式
          ↓
    对应 Tool Adapter
          ↓
    生成 Artifact

例如：

Prototype Design Step：

-   Figma Adapter
-   Pixso Adapter
-   HTML Prototype Adapter
-   其他未来工具

同一个 Workflow Step 可以更换不同执行工具。

------------------------------------------------------------------------

# 五、Artifact 标准化

所有执行结果统一进入：

`ZhuowangArtifact`

目的：

无论产物来自：

-   AI生成
-   Figma
-   Pixso
-   HTML
-   文档工具

最终都由 Cosmos OS 统一管理。

------------------------------------------------------------------------

# 六、本次开发问题记录

## Artifact 初始化字段适配

问题：

HTML Prototype Adapter 初版生成 Artifact 时，字段未完全匹配现有模型。

解决：

按照真实 Workflow Model 结构调整：

-   campaignID
-   workflowStepID
-   Artifact 类型
-   location 字段

经验：

后续涉及核心模块修改时，需要同步检查：

-   Model
-   Store
-   Builder
-   Adapter
-   View

避免局部修改导致重复编译修复。

------------------------------------------------------------------------

# 七、当前完成状态

## 已完成

✅ Workflow Model

✅ TaskPackage 构建

✅ Tool Adapter 协议

✅ HTML Prototype Adapter

------------------------------------------------------------------------

# 八、下一阶段计划

## 1. Adapter Registry

目标：

统一管理所有可用工具。

例如：

    HTML Prototype
    Figma
    Pixso
    Claude
    Codex
    DeepSeek

------------------------------------------------------------------------

## 2. Workflow 执行调度

实现：

用户选择：

AI: Claude

工具: HTML Prototype

↓

Workflow 自动执行

↓

返回 Artifact

------------------------------------------------------------------------

## 3. 外部工具扩展

未来接入：

-   Figma Adapter
-   Pixso Adapter
-   Claude Desktop Adapter
-   Codex Adapter
-   DeepSeek Harness Adapter

------------------------------------------------------------------------

# 九、开发规范补充

核心模块修改原则：

涉及：

-   Workflow
-   Model
-   Adapter
-   Store
-   Artifact

需要先分析完整依赖链，再修改。

推荐流程：

    分析依赖
    ↓
    一次性修改
    ↓
    完整编译验证

避免：

    修改一个文件
    ↓
    编译
    ↓
    发现依赖错误
    ↓
    重复修改

------------------------------------------------------------------------

# 十、本次 Git Commit 建议

    feat: 完成 Cosmos OS Workflow Adapter 初版架构，新增 HTML Prototype 执行能力

记录日期：

2026-08-18
