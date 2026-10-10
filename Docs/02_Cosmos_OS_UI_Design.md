# Cosmos OS UI Design

**版本：v0.1**  
**日期：2026-08-17**


> **2026-10-10 状态说明**
> 2026-10-10 起用户启动分步体验升级，设计方向升级为 macOS 26 Liquid Glass 原生风格，以 CosmosDesign 组件为准；玻璃仅用于导航与控件，内容层采用系统填充。第一步已通过构建与隔离测试并部署，可交用户体验验收（验证缺口见 Current Status）。
> 本文是立项基线（v0.1，写于 2026-08-17，正文保持原样不改写）；产品方向与原则仍然有效。**实际进度和实现以 `Docs/07_Cosmos_OS_Current_Status.md` 为准**；历史细节见 `Docs/Archive/07_Cosmos_OS_Current_Status_至2026-10-10.md`（下表“归档 §N”指该归档文件的章节号）。下表只列已在代码或归档中核实过的差异，未列出的内容不代表一致或已验证。
>
> | 原文表述 | 当前实际 | 依据 |
> |---|---|---|
> | §4 Sidebar：Home / Work / AI / Learning / System / General 六组 | 实际五组：首页·Home（仪表盘、统一检索）｜工作·Work（卓望工作、项目、知识库）｜AI（AI 工作台、提示词库）｜学习·Learning（AI 学习中心）｜系统·System（Mac 优化、设置）；多出“统一检索”，设置并入系统组 | `DashboardView.swift` 的 `navigationContent` 与 `SidebarItem` |
> | §6 Dashboard 样例：Good morning / Today's Work 3 items / Python 28% / 8/9 Healthy / All Good | 这些样例内容均已移除；首页只显示真实数据（真实时钟问候），不显示编造的任务数 / 学习百分比 / 健康数 | 归档 §21、§18；源码中已无这些字符串 |
> | §8 学习中心：Python 28% 进度条、Today 45 min | 已决定任何位置都不显示百分比进度；学习中心为三态手动 + 学习记录 | 归档 §18；`LearningModels.swift` |
> | §9 Prompt Vault：三栏 Category | List | Detail，支持标签 | 三栏已按此实现（窄窗口回退为分类选择器）；无标签（单一文本分类）；版本历史已实现 | `PromptVaultView.swift`；归档 §17、§35 |
> | §10 AI Workspace 状态样例（Python ✓ 3.14 / Homebrew / DeepSeek …） | 仅 5 个工具；行状态为 可运行 / 无法运行 / 未找到 / 未检测，并显示版本、执行路径与发现来源 | 归档 §22 |
> | §11 Mac Optimizer 样例（Input Methods / Login Items / Developer Environment / Storage） | 页面显示系统版本 / 硬件 / 内存 / 磁盘 / 电池，只读；无输入法 / 登录项 | 归档 §28；`MacEnvironmentView.swift` |
> | §7 Zhuowang Workspace 左侧固定省份列表 | 省份来自可维护配置；停用省份进入可折叠的“已停用省份（历史）”；没有省份时显示“还没有省份，点击添加” | 归档 §19；`ZhuowangWorkspaceView.swift` |

---

## 1. 设计目标

Cosmos OS 的视觉目标不是“科技感炫技”，而是：

> 原生、克制、清晰、长期耐看。

参考的是 macOS 原生软件的秩序感，而不是赛博朋克、霓虹渐变、重卡片、重装饰。

---

## 2. 设计关键词

- Native
- Calm
- Precise
- Spacious
- Functional
- Personal

中文理解：

- 原生
- 克制
- 精准
- 留白
- 功能导向
- 私人工作空间

---

## 3. 总体布局

采用标准 macOS Sidebar 架构。

```text
┌───────────────────────────────────────────────────────────────┐
│ Cosmos OS                                                     │
├──────────────────┬────────────────────────────────────────────┤
│                  │                                            │
│ Dashboard        │              Main Content                  │
│                  │                                            │
│ Work             │                                            │
│ Zhuowang         │                                            │
│ Projects         │                                            │
│                  │                                            │
│ AI               │                                            │
│ AI Workspace     │                                            │
│ Prompt Vault     │                                            │
│                  │                                            │
│ Learning         │                                            │
│ Learning Center  │                                            │
│                  │                                            │
│ System           │                                            │
│ Mac Optimizer    │                                            │
│                  │                                            │
│ Settings         │                                            │
└──────────────────┴────────────────────────────────────────────┘
```

---

## 4. Sidebar 结构

建议采用分组设计，而不是所有菜单平铺。

### Home
- Dashboard

### Work
- Zhuowang Workspace
- Projects
- Knowledge Base

### AI
- AI Workspace
- Prompt Vault

### Learning
- AI Learning Center

### System
- Mac Optimizer

### General
- Settings

---

## 5. SF Symbols 建议

优先使用 SF Symbols，不自制图标。

| 模块 | 建议图标 |
|---|---|
| Dashboard | `square.grid.2x2` |
| Zhuowang Workspace | `briefcase` |
| Projects | `folder` |
| Knowledge Base | `books.vertical` |
| AI Workspace | `sparkles` |
| Prompt Vault | `text.book.closed` |
| Learning Center | `graduationcap` |
| Mac Optimizer | `wrench.and.screwdriver` |
| Settings | `gearshape` |

图标只承担识别，不承担装饰。

---

## 6. Dashboard 页面

### 首屏结构

```text
Good morning
Cosmos OS

┌────────────────┐  ┌────────────────┐
│ Today's Work   │  │ Learning       │
│ 3 items        │  │ Python 28%     │
└────────────────┘  └────────────────┘

┌────────────────────────────────────┐
│ Recent Projects                    │
│ 河南 9月促活                       │
│ 亚运竞猜                           │
│ Cosmos OS                          │
└────────────────────────────────────┘

┌────────────────┐  ┌────────────────┐
│ AI Workspace   │  │ System         │
│ 8/9 Healthy    │  │ All Good       │
└────────────────┘  └────────────────┘
```

### 原则

- 不做大面积彩色卡片；
- 信息密度适中；
- 使用系统背景色；
- 状态色只在真正需要时出现；
- 默认支持浅色 / 深色模式。

---

## 7. Zhuowang Workspace

建议采用“项目列表 + 项目详情”的两级布局。

### 左侧

- 全部项目
- 河南
- 安徽
- 浙江
- 海南
- 广东
- 贵州
- 全国

### 右侧项目卡片

显示：

- 项目名称
- 省份
- 活动类型
- 时间
- 当前状态
- 最近修改
- 关键文件

### 新建项目

使用 Sheet：

```text
New Zhuowang Project

Project Name
Province
Activity Type
Start Date
End Date
Template

[Cancel] [Create]
```

创建后直接生成标准目录。

---

## 8. AI Learning Center

建议视觉核心不是“课程”，而是“进度”。

```text
Python
28%

███████░░░░░░░░

Today
45 min

Next
变量 / 条件判断

Recent Notes
...
```

学习主题采用列表，不做复杂仪表盘。

---

## 9. Prompt Vault

采用三栏结构更合适：

```text
Category | Prompt List | Prompt Detail
```

支持：

- 搜索
- 标签
- 收藏
- 复制
- 编辑
- 版本

Prompt 正文使用等宽或系统正文，不使用过度代码化视觉。

---

## 10. AI Workspace

状态分为：

- Normal
- Warning
- Missing
- Needs Update
- Unknown

展示样例：

```text
Python          ✓ 3.14
Git             ✓ 2.xx
Homebrew        ✓
Node            ! Update available
Codex           ✓
Claude Code     —
DeepSeek        ✓
```

只在异常时展开详情。

---

## 11. Mac Optimizer

采用“检查 → 建议 → 执行”的交互。

禁止：

- 默认勾选高风险清理；
- 一键执行无法解释的批量删除；
- 使用“释放 XX GB”作为主要视觉目标。

建议：

```text
Input Methods
2 installed
1 third-party

Login Items
6 items

Developer Environment
Healthy

Storage
Normal
```

---

## 12. 色彩

第一版不定义品牌色硬编码。

优先使用：

- `.primary`
- `.secondary`
- `.accentColor`
- 系统背景
- 系统分隔线

状态色使用系统语义色。

原则：

> UI 应该随着 macOS 外观自动适配，而不是强行覆盖系统风格。

---

## 13. 字体

全部优先使用 SF Pro / 系统字体。

### 建议层级

- 页面标题：28–32
- Section 标题：17–20
- 正文：13–15
- 辅助信息：11–13
- 状态数字：24–36

不要同时使用太多字号。

---

## 14. 间距

基础间距单位：

- 4
- 8
- 12
- 16
- 24
- 32

页面外边距建议 24–32。

卡片之间 12–16。

---

## 15. 圆角

系统原生即可。

建议：

- 小组件：8
- 卡片：12
- 大区域：16

禁止满屏大圆角卡片。

---

## 16. 动效

原则：

- 少；
- 快；
- 可预期；
- 不干扰。

可使用：

- 页面切换淡入；
- Sheet；
- Sidebar 原生折叠；
- hover；
- 状态变化轻动画。

避免：

- 弹跳；
- 光效；
- 大面积缩放；
- 炫技过渡。

---

## 17. 窗口

第一版建议：

- 最小宽度：900
- 最小高度：620
- 推荐默认：1180 × 760

支持用户自由调整。

---

## 18. 空状态

不要只显示“暂无数据”。

例如：

```text
No projects yet

Create your first Zhuowang project
and Cosmos OS will build the workspace for you.

[New Project]
```

---

## 19. 错误状态

错误信息必须回答三个问题：

1. 发生了什么；
2. 是否影响数据；
3. 下一步怎么做。

禁止：

> Error -1

---

## 20. UI 决策原则

每设计一个页面，都检查：

- 是否比系统设置更复杂？
- 是否有不必要的卡片？
- 是否存在无意义颜色？
- 是否可以少一个按钮？
- 用户能否 3 秒内看懂页面作用？
- 深色模式是否自然？
- 窗口缩小时是否仍可用？

如果答案不理想，继续简化。
