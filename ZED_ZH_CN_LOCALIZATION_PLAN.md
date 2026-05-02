# Zed 本地汉化方案

## 当前落地状态（H:\zedCn）

本仓库已经采用本文建议的 overlay 思路落地到本地目录：

```text
H:\zedCn\zh-cn-overlay\
```

当前主流程和完成态以 `ZH_CN_LOCALIZATION_STEPS.md` 为准：

- `translations.json` 已包含 4141 条翻译项。
- `apply-zh-cn.ps1` 可幂等套用汉化，支持旧译文迁移。
- `scan-untranslated.ps1` 已修正大小写误判，并覆盖 `ListBulletItem`、Settings 数据字段、`action_disabled_when`、`single_line_input`、`InputField::new`、`SharedString`、通知、安装器和 DAP adapter schema description 等相关 UI 构造。
- 额外复扫了欢迎页、远程连接弹窗、Git / stash 提示、REPL / Jupyter 空状态、Agent 队列与错误提示、Copilot 登录说明等扫描器外的 UI 字符串。
- 使用 `D:\zed-build-tools` 工具链执行 `cargo check -p zed -p remote_server` 已通过。
- 当前扫描候选为 0；截图中暴露的 Agent、Settings、右键菜单、最近项目、通知、断点/书签提示、更新提示和安装器文案已继续补齐。
- 当前仓库就是汉化仓库，直接在 `dev` 分支维护；`origin` 是 `Eleven-Elevens/zedCn`，`upstream` 是官方 `zed-industries/zed`。
- Rust / Visual Studio Build Tools / Inno Setup 已安装到 `D:\zed-build-tools`；完整 Windows 安装包已成功生成：`H:\zedCn\target\Zed-x86_64.exe`，最终安装器日志为 `H:\zedCn\target\inno-final-zh-cn-deep-scan-rerun.log`。

## 目标

在不修改已安装 `Zed.exe` 的前提下，通过官方源码编译一个本地汉化版 Zed。

核心目标：

- 能跟随 Zed 官方 `main` 分支获得最新功能。
- 汉化内容集中维护，避免散落在源码中。
- 每次官方更新后，可以快速重新套用汉化。
- 尽量减少 Git rebase 冲突和手工重复翻译。

## 总体方案

采用“官方源码 + 外置汉化 overlay”的方式：

```text
官方 Zed 源码
  +
外置汉化翻译表和脚本
  =
本地编译汉化版 Zed
```

不推荐直接修改已安装程序：

```text
D:\OtherSoftware\Zed\Zed.exe
```

原因：

- UI 文案大多已经编译进二进制文件。
- 直接改 exe 风险高，容易损坏程序。
- 官方更新后会被覆盖。
- 无法长期维护。

## 推荐目录结构

```text
H:\zedCn\
  官方 Zed 源码 + 本地汉化改动

H:\zedCn\zh-cn-overlay\
  translations.json
  apply-zh-cn.ps1
  scan-untranslated.ps1
  auto-fill-from-report.mjs
  refine-translations.mjs
```

其中：

- `H:\zedCn`：当前汉化仓库，直接维护中文改动。
- `origin`：你的线上汉化仓库。
- `upstream`：官方 Zed 仓库，用于拉取最新代码。
- `zh-cn-overlay`：长期保留，存放汉化资产和维护脚本。
- `translations.json`：维护英文到中文的映射。
- `apply-zh-cn.ps1`：把翻译表套用到源码。
- `scan-untranslated.ps1`：扫描疑似未翻译 UI 文案。
- `auto-fill-from-report.mjs`：从扫描报告自动补明确映射。
- `refine-translations.mjs`：人工精修长句、多行字符串和旧译文迁移。

## translations.json 设计

建议不要只用简单键值对，而是记录文件路径和翻译 ID。

示例：

```json
[
  {
    "id": "agent.llm_providers.title",
    "file": "crates/agent_ui/src/agent_configuration.rs",
    "from": "LLM Providers",
    "to": "LLM 提供商"
  },
  {
    "id": "agent.add_provider",
    "file": "crates/agent_ui/src/agent_configuration.rs",
    "from": "Add Provider",
    "to": "添加提供商"
  },
  {
    "id": "agent.external_agents.title",
    "file": "crates/agent_ui/src/agent_configuration.rs",
    "from": "External Agents",
    "to": "外部代理"
  }
]
```

这样做的好处：

- 可以限制替换范围，避免误翻配置字段。
- 官方源码路径变化时容易定位。
- 某条翻译失败时能准确知道是哪一条。
- 后续可以按模块统计覆盖率。

## apply-zh-cn.ps1 要求

脚本应该做到：

```text
1. 读取 translations.json。
2. 只在指定 file 中替换指定 from 文案。
3. 找不到原文时输出失败项。
4. 同一文件匹配多次时输出警告。
5. 替换完成后输出成功、失败、警告统计。
6. 不做全仓库无脑替换。
```

不建议替换这些内容：

```text
settings key
command id
action id
provider id
schema field
protocol field
日志内部标识
文件路径
LSP 返回内容
终端输出
```

## 更新最新版流程

当前仓库直接维护汉化改动。每次 Zed 官方更新后，执行：

```powershell
cd H:\zedCn

git switch dev
git fetch upstream
git merge upstream/main

powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

如果同步后出现新的英文 UI 文案，再执行：

```powershell
node .\zh-cn-overlay\auto-fill-from-report.mjs .
node .\zh-cn-overlay\refine-translations.mjs .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

验证通过后推到自己的仓库：

```powershell
git push origin dev
```

如果更喜欢线性历史，可以把 merge 换成 rebase：

```powershell
git rebase upstream/main
```

长期资产直接保留在当前仓库：

```text
zh-cn-overlay\translations.json
```

## 编译前准备

需要先准备 Zed Windows 构建环境：

- Rust toolchain
- Visual Studio Build Tools C++ 组件
- Windows SDK
- CMake
- Git

当前已经是汉化仓库，不需要再单独拉一份官方源码。首次配置或检查远端：

```powershell
cd H:\zedCn
git remote -v
```

如果缺少官方上游远端：

```powershell
git remote add upstream https://github.com/zed-industries/zed.git
git remote set-url --push upstream DISABLED
```

准备好构建环境后再确认当前仓库能运行：

```powershell
cargo run --release
```

同步官方代码、套用汉化和扫描验证的流程见上方“更新最新版流程”。

## 汉化优先级

建议先覆盖高频页面，不要一开始追求全量。

第一批：

```text
Settings
Agent
LLM Providers
MCP Servers
External Agents
```

第二批：

```text
菜单栏
命令面板
Project Panel
Search Panel
Git Panel
```

第三批：

```text
弹窗
Toast
错误提示
状态栏
低频设置页面
```

暂不处理：

```text
插件自己的 UI
LSP 报错
终端输出
编译器输出
第三方工具输出
模型返回内容
```

## 同步更新时的处理方式

如果官方没有改到相关 UI，脚本会直接成功。

如果官方修改了文案，例如：

```text
Add Provider
```

变成：

```text
Add LLM Provider
```

脚本会提示找不到原文。

此时只需要更新 `translations.json`：

```json
{
  "id": "agent.add_provider",
  "file": "crates/agent_ui/src/agent_configuration.rs",
  "from": "Add LLM Provider",
  "to": "添加 LLM 提供商"
}
```

然后重新执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
```

## 为什么不直接做完整 i18n 框架

完整 i18n 框架更正规，但成本高。

它至少需要：

```text
crates/i18n/
assets/locales/en-US.ftl
assets/locales/zh-CN.ftl
settings schema 增加 ui_locale
GPUI 全局语言状态
运行时语言切换和窗口重绘
翻译 key 校验工具
大量 UI 字符串替换
```

对于本地使用来说，收益不如“外置翻译层 + 自动脚本”直接。

可以等常用 UI 汉化稳定后，再考虑升级为正式 i18n 框架。

## 验证方式

每次套用汉化后，至少执行：

```powershell
cargo check
cargo run --release
```

启动后手动检查：

```text
Settings
External Agents
LLM Providers
MCP Servers
Command Palette
Project Panel
Git Panel
```

如果改到了大量 UI 文案，建议额外检查：

```text
菜单项是否显示正常
按钮文字是否溢出
弹窗布局是否被中文撑坏
设置项是否还能搜索
命令面板命令是否还能执行
```

## 风险点

主要风险：

- 官方 UI 结构变化导致某些翻译失效。
- 某些英文字符串既是 UI 文案，又是内部标识，误翻后可能影响功能。
- 中文文案比英文长，可能导致布局溢出。
- 跟随 `main` 分支可能遇到临时编译失败。

规避方式：

- 只按文件定点替换。
- 不做全局字符串替换。
- 每次替换后跑 `cargo check`。
- 第一阶段只翻高频 UI。
- 对疑似内部字段保持英文。

## 最终建议

当前最合适路线：

```text
外置 translations.json
  +
apply-zh-cn.ps1 自动套汉化
  +
当前汉化仓库直接维护
  +
从 upstream/main 同步官方最新代码
  +
本地编译使用
```

这套方案能兼顾：

- 跟随最新功能。
- 更新时可重复执行。
- 汉化资产可长期维护。
- 避免完整 i18n 框架的高成本。

## 2026-05-01 补扫结论

在标准扫描 `candidates: 0` 之外，又按源码上下文补扫了 `placeholder_text`、`Tooltip::for_action_in`、`SharedString::new_static`、`StatusToast`、`window.prompt`、Agent 工具权限标题、`submenu`、`toggleable_entry`、`label_with_contrast` 和 component preview 示例标题/说明等容易漏掉的 UI 构造。

已补齐的重点包括：选择器占位、面板标题、Git/搜索/最近项目/大纲/终端入口、Agent 工具调用标题、Vim 和项目搜索提示、ETW 通知、调试器与 REPL 文案、Quick Action Bar 切换项、Extensions 空状态、标题栏布局菜单、Workspace 主题预览、UI component preview 示例，以及 `API URL` 可见标签统一为“API 地址”。

验证状态：

- `translations.json`: `4141` 条，重复 id 为 `0`
- `scan-untranslated.ps1`: `candidates: 0`
- `git diff --check`: 仅 CRLF 提示
- `rerun9` 主程序 release 构建通过；随后 `remote_server` 在同轮构建里触发一次 `STATUS_HEAP_CORRUPTION` 编译器/内存崩溃，已用定向重试恢复
- `remote-server-final-retry`: 退出码 `0`，`remote_server` 和远端服务包已生成
- `zed-incremental-deep-scan-final-rerun`: 退出码 `0`，深度补扫新增文案后主程序已重新编译
- `inno-final-zh-cn-deep-scan-rerun`: 退出码 `0`，最终安装包已重新生成
- component preview 专项扫描：剩余 `0`
