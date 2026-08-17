# Cosmos OS UI Design

**版本：v0.1**  
**日期：2026-08-17**

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
