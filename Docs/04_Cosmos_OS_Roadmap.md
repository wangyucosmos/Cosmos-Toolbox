# Cosmos OS Roadmap

**版本：v0.2**  
**日期：2026-08-17**

---

## 总原则

Roadmap 只作为方向，不用日期绑架开发。

每个阶段必须达到：

> 可运行 → 可使用 → 可稳定 → 再扩展

---

## 2026-08-17 当前实际进度

> 本节记录已经完成并经过实际运行验收的能力。Roadmap 阶段顺序仍作为方向，但真实开发允许根据高价值工作流提前验证后续能力。

### 已完成并验收

- [x] Cosmos OS macOS SwiftUI 基础工程可稳定运行
- [x] Dashboard / Sidebar / 卓望工作区基础导航建立
- [x] 卓望 Workspace 已支持省份、模块、分类结构
- [x] Campaign 活动项目可创建、查看、编辑、删除并持久化
- [x] Campaign Detail 已具备概览、AI Workflow、工作产物入口
- [x] AI Workflow 六步标准流程建立：需求整理、策划思路、完整策划案、页面结构、Figma 原型、客服文档
- [x] 每个 Workflow Step 可独立选择 AI Provider
- [x] AI Provider 选择可持久化并在重新进入步骤时自动恢复
- [x] DeepSeek Harness 已完成本地 Headless 调用
- [x] Cosmos OS 可通过按钮直接调用 DeepSeek Harness 执行真实任务
- [x] AI 执行结果可自动返回 Cosmos OS
- [x] AI 结果支持人工审核与“采用结果”
- [x] 采用结果后自动写入 AI Run / Approval / Artifact
- [x] 采用结果后当前 Workflow Step 自动标记为已确认
- [x] 采用结果后自动解锁下一 Workflow Step
- [x] Workflow 进度、已确认数量、工作产物数量可实时更新
- [x] Task Preview Provider / Connection / Step 状态已改为原子化传递，修复偶发按钮变灰和 AI 状态不同步问题
- [x] DeepSeek Harness Provider / Connection 稳定 ID 兼容与旧数据迁移已处理
- [x] App Icon 已完成设计并配置到 Xcode
- [x] GitHub 已建立持续 Commit / Push 版本记录

### 已验证的真实闭环

```text
创建活动
→ 进入 AI Workflow
→ 选择 / 自动恢复 DeepSeek Harness
→ 准备 Task Package
→ Cosmos OS 调用本地 DeepSeek Harness
→ DeepSeek 返回结果
→ 人工审核
→ 采用结果
→ 保存 AI Run / Approval / Artifact
→ 当前步骤已确认
→ 自动解锁下一步骤
```

目前已实际完成并验收前两步：

```text
01 需求整理 → 已确认
02 策划思路 → 已确认
03 完整策划案 → 已解锁，可开始
```

### 当前下一优先级

1. 完善“工作产物 / Artifacts”页面，让已采用结果真正可查看、管理和复用
2. 将 Artifact 从内部持久化进一步落成真实项目文件（Markdown / Word 等）
3. 为 Campaign 建立标准本地项目目录与 Finder 打开能力
4. 继续验证完整策划案、页面结构、Figma 原型、客服文档四个 Workflow Step
5. 在核心功能稳定后，再统一进行 Cosmos OS 全局 UI / Motion / 视觉系统升级

### 当前已知待处理项

- Campaign / Workflow 等长期数据目前仍以本地持久化为主，后续需要升级为更稳健的数据存储与迁移机制
- Artifact 当前已经保存为 Workflow 数据，但“真实文件落盘”尚未完成
- ChatGPT / Claude Work 暂未直接自动执行，先采用辅助式 Task Package 工作流
- Codex / Claude Code 后续计划采用本地 Adapter / CLI 执行方式接入
- Figma 自动化连接尚未实现
- 全局 UI 目前以功能优先，最终视觉统一将在核心信息架构稳定后集中处理

---

# Phase 0 — Foundation

目标：

> 建立一个不会很快推翻的基础工程。

## v0.1 — App Foundation

- [ ] 工程目录整理
- [x] `DashboardView`
- [x] App 名称确认
- [x] Sidebar 基础导航
- [ ] `NavigationSplitView`
- [ ] AppState
- [x] SF Symbols
- [ ] 最小窗口尺寸
- [ ] Light / Dark Mode
- [x] Git 初始提交
- [ ] README
- [x] PRD
- [x] UI Design
- [x] Architecture
- [x] Roadmap
- [x] Philosophy

完成标准：

- App 稳定启动；
- Sidebar 可以切换页面；
- 所有一级模块均有 Placeholder 页面；
- 工程结构正式建立。

---

# Phase 1 — Work First

目标：

> 让 Cosmos OS 第一次真正进入日常工作。

## v0.2 — Zhuowang Workspace 基础

- [x] 项目列表
- [x] 新建项目
- [x] 项目名称
- [x] 省份
- [x] 活动类型
- [x] 日期
- [x] 状态
- [x] 项目详情
- [ ] 项目文件夹路径

## v0.3 — Workspace Generator

- [ ] 自动生成活动目录
- [ ] 文件夹模板
- [ ] 打开 Finder
- [ ] 打开策划目录
- [ ] 打开原型目录
- [ ] 打开客服目录
- [ ] 打开素材目录
- [ ] 最近项目

## v0.4 — Zhuowang Templates

- [ ] 活动策划模板
- [ ] 客服 FAQ 模板
- [ ] 流程图模板
- [ ] 活动规则模板
- [x] 省份标签
- [x] 项目备注

阶段完成标准：

- 可以真实用 Cosmos OS 新建一个卓望活动项目；
- 自动创建标准项目目录；
- 每天可以从 Cosmos OS 打开工作项目。

---

# Phase 2 — Learning & Prompt

## v0.5 — AI Learning Center

- [ ] 学习主题
- [ ] 学习进度
- [ ] 今日学习
- [ ] 学习记录
- [ ] 笔记
- [ ] 下一步
- [ ] 已完成内容

首批主题：

- Python
- GitHub
- Swift
- Figma
- AI Agent
- MCP
- 视频剪辑

## v0.6 — Prompt Vault

- [ ] Prompt 列表
- [ ] 分类
- [ ] 标签
- [ ] 搜索
- [ ] 收藏
- [ ] 一键复制
- [ ] 编辑
- [ ] 创建 Prompt

阶段完成标准：

- 学习可以连续记录至少两周；
- 常用 Prompt 不再依赖聊天历史查找。

---

# Phase 3 — AI Workspace

## v0.7 — Environment Scanner

检测：

- [ ] Python
- [ ] Git
- [ ] Homebrew
- [ ] Node
- [ ] npm
- [ ] uv
- [ ] VS Code
- [ ] Codex
- [ ] Claude Code
- [x] DeepSeek Harness（已完成可执行性验证与真实调用）

## v0.8 — Environment Details

- [ ] 版本显示
- [x] 安装路径（DeepSeek Harness 当前本机执行链已确认）
- [x] 是否可执行（DeepSeek Harness 已确认）
- [ ] 更新提示
- [ ] 问题详情
- [ ] 安全修复建议

原则：

- 默认只检测；
- 不自动修改。

---

# Phase 4 — Knowledge Layer

## v0.9 — Knowledge Base

- [ ] 文件索引
- [ ] 项目元数据
- [ ] 标签
- [ ] 搜索
- [ ] 最近访问
- [ ] 文件类型过滤

后续：

- 内容全文索引
- 语义搜索
- AI 摘要

---

# Phase 5 — Mac Utility

## v0.10 — Mac Optimizer

- [ ] 系统信息
- [ ] 电池
- [ ] 内存
- [ ] 磁盘
- [ ] 输入法
- [ ] 登录项
- [ ] LaunchAgents
- [ ] Finder 设置
- [ ] Dock 设置

原则：

- 只做透明、安全、可解释的操作。

---

# Phase 6 — Dashboard 2.0

## v0.11

Dashboard 开始整合真实数据：

- [ ] 今日项目
- [ ] 最近项目
- [ ] AI 环境状态
- [ ] 学习进度
- [ ] 最近 Prompt
- [ ] 系统健康
- [ ] 快速操作

---

# Phase 7 — Backup & Migration

## v0.12

- [ ] Cosmos 数据备份
- [ ] Settings 导出
- [ ] Project Manifest 导出
- [ ] 开发环境清单导出
- [ ] Homebrew Brewfile
- [ ] VS Code 扩展列表
- [ ] Git 配置检查
- [ ] SSH Key 存在性检查

目标：

> 为未来换 Mac 做准备。

---

# Phase 8 — AI Integration

## v0.13+

> 原 Roadmap 计划在基础稳定后开始 AI Integration；实际开发中，为了优先验证最高价值的卓望真实工作流，已提前完成 DeepSeek Harness 的首个端到端闭环。其余 AI 集成仍遵循“先稳定，再扩展”。

候选能力：

- AI 项目摘要
- AI Prompt 优化
- [x] 活动策划助手（DeepSeek Harness 首条 Workflow 已跑通）
- [ ] 客服 FAQ 生成
- [ ] 学习问答
- [ ] 文件总结
- [ ] 项目复盘
- [x] Agent Workflow（DeepSeek Harness + 人工确认 + Artifact 闭环已完成基础版）

原则：

> AI 必须嵌入真实工作流，而不是为了“有 AI”而加入 AI。

---

# Phase 9 — V1.0

V1.0 不看功能数量，看是否形成真正闭环。

## V1.0 必须满足

- [ ] Zhuowang Workspace 已真实长期使用
- [ ] AI Learning Center 已形成学习记录
- [ ] Prompt Vault 已替代聊天历史找 Prompt
- [ ] AI Workspace 能稳定检测环境
- [ ] Knowledge Base 可以检索项目
- [ ] Dashboard 有实际价值
- [ ] Mac Optimizer 基础可用
- [ ] 数据支持备份
- [x] GitHub 有完整版本记录（已进入持续 Commit / Push）
- [ ] 连续稳定使用 30 天

---

# 暂不进入 Roadmap 的功能

以下功能暂不承诺：

- 多用户
- Windows
- Web
- Android
- 团队协作
- 商业化
- Plugin Marketplace
- 自建云
- 社区
- AI 模型托管
- 完整 IDE

不是永远不做，而是当前阶段不值得分散注意力。

---

# 当前执行顺序

当前优先级调整为：

1. 稳定当前 Zhuowang Workspace + AI Workflow 已跑通能力
2. 完善 Artifacts 工作产物页面
3. 完成 Workspace Generator：真实目录、文件落盘、Finder 打开
4. 继续验证后续 Workflow Step
5. 再进入 Learning / Prompt / Knowledge 等后续模块
6. 核心信息架构稳定后统一升级全局 UI / Motion

原则仍然不变：

> 可运行 → 可使用 → 可稳定 → 再扩展
