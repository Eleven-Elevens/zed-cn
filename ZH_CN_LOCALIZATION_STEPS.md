# Zed 简体中文本地化步骤

本文档记录 `K:\Project\zed-cn` 当前采用的本地汉化流程。目标是把可见 UI 文案集中维护为 overlay，避免无范围的全仓库替换，同时保留语言名、品牌名、协议字段、路径、命令和代码示例。

## 当前状态

- 当前 overlay 位于 `zh-cn-overlay/`。
- `zh-cn-overlay/translations.json` 当前包含 4145 条翻译项。
- 已覆盖菜单栏、Settings、Agent / LLM Providers、Project Panel、Search、Git UI、Editor / Diagnostics / Quick Action Bar、Onboarding、Welcome、Recent Projects、Workspace 通知、Extensions、REPL / Jupyter、Copilot 登录说明、组件 preview 示例标题/说明等。
- `zh-cn-overlay/scan-untranslated.ps1` 已修正大小写误判，并扩展到 `ListBulletItem`、Settings 数据字段、`action_disabled_when`、`single_line_input`、`InputField::new`、`SharedString`、通知、安装器和 DAP adapter schema description 等相关 UI 构造；当前扫描结果为 0 个候选，报告写入 `zh-cn-overlay/untranslated-report.json`。
- 最近一轮已补齐截图中暴露的 Agent 欢迎卡片、Settings General 首屏、设置下拉选项、编辑器/Agent/项目面板/终端右键菜单、最近项目占位、Onboarding 标签标题、断点/书签提示、更新提示、通知和安装器文案，并继续覆盖 Settings 数据表、组件预览搜索、协作通话质量、Agent 工具消息、Diagnostics 标签、Keybinding context、调试器 schema 说明、自动更新状态、诊断工具栏、计划 chip 和编辑预测数据共享说明等候选。
- `apply-zh-cn.ps1` 支持幂等套用，并支持 `previous_to`，可把早期已应用的旧译文迁移成更好的译文。
- Rust / Visual Studio Build Tools / Inno Setup 已安装到 `D:\zed-build-tools`。`zed.exe`、`remote_server.exe` 和完整 Windows 安装包均已成功编出；安装包路径为 `K:\Project\zed-cn\target\Zed-x86_64.exe`。
- 当前仓库就是汉化仓库，直接在当前分支维护中文改动。
- `origin` 指向你的汉化仓库，`upstream` 指向官方 Zed 仓库；后续只需要从 `upstream` 同步官方最新代码。

## 目录说明

```text
zh-cn-overlay/
  translations.json          # 主翻译表
  apply-zh-cn.ps1            # 将翻译表套用到源码
  scan-untranslated.ps1      # 扫描疑似未覆盖 UI 文案
  auto-fill-from-report.mjs  # 从扫描报告自动补明确映射
  machine-translate-report.mjs # 对扫描报告中的公开 UI 文案做机器初翻
  refine-translations.mjs    # 人工精修、补多行源码字符串、迁移旧译文
  untranslated-report.json   # 最新扫描报告
```

## 第 1 步：扫描候选

```powershell
cd K:\Project\zed-cn
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

扫描器只关注 Rust 源码里的常见 UI 构造，例如菜单、按钮、Label、Tooltip、标题、右键菜单、表单标签、说明文案和 `.child("...")`。它会跳过：

- 行注释和文档示例。
- `*_test.rs` / `*_tests.rs` 测试文件。
- 语言名、模型名、品牌名。
- Git ref、路径、命令、代码片段。

当前完成态应输出：

```text
Scan complete.
  candidates: 0
```

## 第 2 步：自动补齐明确文案

当上游更新后扫描报告出现新候选，先运行自动补齐：

```powershell
node .\zh-cn-overlay\auto-fill-from-report.mjs .
```

这个脚本只处理已有词表和规则能明确翻译的短文案。它不会翻译 `Rust`、`TypeScript`、`GitHub Copilot`、`refs/heads/main`、命令和代码片段。

## 第 3 步：人工精修

```powershell
node .\zh-cn-overlay\refine-translations.mjs .
```

精修脚本负责：

- 修正自动翻译里容易出现的中英文拼接问题。
- 补充长句和说明文案。
- 处理 Rust 多行字符串的 `from_source` / `to_source`。
- 为已经应用过的旧译文记录 `previous_to`，便于迁移到新译文。

## 第 4 步：套用 overlay

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
```

成功输出示例：

```text
Localization applied.
  entries: 4145
  replacements: 0
  already applied: 2398
  files changed: 0
```

第一次套用时 `replacements` 和 `files changed` 会大于 0；第二次运行应为 0，表示幂等。

## 第 5 步：验证覆盖

按顺序执行：

```powershell
node .\zh-cn-overlay\refine-translations.mjs .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
node -e "const fs=require('fs'); const t=JSON.parse(fs.readFileSync('zh-cn-overlay/translations.json','utf8').replace(/^\uFEFF/,'')); const ids=new Set(); let dup=0; for (const e of t) { if (ids.has(e.id)) dup++; ids.add(e.id); } console.log({entries:t.length, duplicate_ids:dup});"
```

当前应满足：

```text
entries: 4145
duplicate_ids: 0
candidates: 0
```

## 第 6 步：不要翻译的内容

这些内容应保留英文或原样：

- 内部 action id、settings key、provider id、schema/protocol 字段。
- URL、文件路径、Git ref、shell 命令。
- 编程语言名和文件类型名：`Rust`、`TypeScript`、`JSON` 等。
- 品牌和模型名：`Zed`、`GitHub Copilot`、`Claude`、`Gemini`、`LM Studio`、`Ollama` 等。
- LSP、终端、编译器、模型输出。
- 代码示例和测试占位：`fn main() {}`、`John Doe`、`refs/heads/main` 等。

如果扫描报告只剩这些，应更新 `scan-untranslated.ps1` 的忽略规则，而不是强行翻译。

## 第 7 步：跟随官方上游更新

当前仓库远端约定：

```text
origin   https://github.com/Eleven-Elevens/zed-cn.git
upstream https://github.com/zed-industries/zed.git
```

日常继续在当前汉化分支上改。需要同步官方最新代码时执行：

```powershell
git switch dev
git fetch upstream
git merge upstream/main
node .\zh-cn-overlay\auto-fill-from-report.mjs .
node .\zh-cn-overlay\refine-translations.mjs .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

如果更喜欢线性历史，可以把 `git merge upstream/main` 换成：

```powershell
git rebase upstream/main
```

但有冲突时先解决冲突，再继续运行 overlay 验证脚本。

如果 `apply-zh-cn.ps1` 报某条原文找不到，通常说明上游改了英文文案或文件路径。处理方式：

1. 在源码里找到新的英文文案。
2. 更新 `translations.json` 的 `file` / `from` / `to`。
3. 必要时补 `from_source` / `to_source`。
4. 重新运行精修、套用和扫描。

同步并验证通过后，推送到你的仓库：

```powershell
git push origin dev
```

## 第 8 步：编译与手动验收

当前机器的构建工具安装在 `D:\zed-build-tools`。已完成完整 Windows 打包，并已编出主程序：

```powershell
K:\Project\zed-cn\target\x86_64-pc-windows-msvc\release\zed.exe
```

完整安装包和远端服务包：

```text
K:\Project\zed-cn\target\Zed-x86_64.exe
K:\Project\zed-cn\target\zed-remote-server-windows-x86_64.zip
```

最终打包相关日志：

```text
K:\Project\zed-cn\target\bundle-full-zh-cn-rerun9.log
K:\Project\zed-cn\target\remote-server-final-retry.log
K:\Project\zed-cn\target\zed-incremental-deep-scan-final-rerun.log
K:\Project\zed-cn\target\inno-final-zh-cn-deep-scan-rerun.log
```

本次产物信息：

```text
K:\Project\zed-cn\target\Zed-x86_64.exe                           以当前 target 目录中的最新构建产物为准
K:\Project\zed-cn\target\zed-remote-server-windows-x86_64.zip     以当前 target 目录中的最新构建产物为准
K:\Project\zed-cn\target\x86_64-pc-windows-msvc\release\zed.exe   以当前 target 目录中的最新构建产物为准
K:\Project\zed-cn\target\x86_64-pc-windows-msvc\release\remote_server.exe 以当前 target 目录中的最新构建产物为准
```

说明：`bundle-full-zh-cn-rerun9.log` 中主程序 release 构建已完成，随后 `remote_server` 构建遇到一次 `STATUS_HEAP_CORRUPTION` 编译器/内存崩溃；之后已通过 `remote-server-final-retry.log` 定向重试成功。最后一轮深度补扫新增自动更新状态、诊断工具栏、计划 chip、DAP schema label 和编辑预测数据共享说明等文案后，又通过 `zed-incremental-deep-scan-final-rerun.log` 重新编译主程序，并用 `inno-final-zh-cn-deep-scan-rerun.log` 完成最终安装包生成。

手动验收时重点检查：

- 菜单栏和命令是否仍触发原动作。
- Settings / Agent / Git / Search / Project Panel 是否显示中文。
- 弹窗、Toast、状态栏、Quick Action Bar 是否有溢出。
- 代码、路径、语言名、品牌名是否没有被误翻。

## 提交前清单

```powershell
node .\zh-cn-overlay\refine-translations.mjs .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

确认：

- `apply-zh-cn.ps1` 二次运行 `replacements: 0`。
- `scan-untranslated.ps1` 输出 `candidates: 0`。
- `translations.json` 无重复 id。
- 使用 `D:\zed-build-tools` 工具链补跑 `cargo check -p zed -p remote_server`。

## 2026-05-01 深度补扫记录

标准扫描之外，继续用源码字符串抽样审查补齐了以下真实 UI 文案：

- Picker 占位文案：主题、图标主题、字体、编码、语言、换行符、仓库、贮藏、代码片段作用域、最近项目、WSL 发行版。
- 面板和工具提示：Agent / Git / Project / Outline / Terminal / Collab 面板，提交编辑器展开折叠，搜索选区，大纲固定。
- Agent 工具标题和权限确认：获取 URL、联网搜索、查找路径、保存文件、删除路径、恢复文件、正则搜索、获取当前时间。
- 弹窗和 Toast：Vim 保存覆盖提示、项目搜索保存提示、Dev Container 提示、ETW 录制通知、CLI 安装提示、更新按钮。
- 调试和 REPL：调试器选择、调试面板标签、REPL 会话、Notebook 内核提示、内存写入不支持提示。

本轮验证：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
git diff --check
node -e "const fs=require('fs'); const t=JSON.parse(fs.readFileSync('zh-cn-overlay/translations.json','utf8').replace(/^\uFEFF/,'')); const ids=new Set(); let dup=0; for (const e of t) { if (ids.has(e.id)) dup++; ids.add(e.id); } console.log({entries:t.length, duplicate_ids:dup});"
```

结果：

- `scan-untranslated.ps1`: `candidates: 0`
- `translations.json`: `4145` 条，重复 id 为 `0`
- `git diff --check`: 仅 CRLF 提示，无空白错误
- `rerun9` 主程序 release 构建通过；`remote_server` 的同轮构建遇到一次 `STATUS_HEAP_CORRUPTION`，已通过定向重试恢复
- 完整打包：`rerun9` 主程序 release 构建通过；`remote-server-final-retry` 退出码 `0`；`zed-incremental-deep-scan-final-rerun` 退出码 `0`；`inno-final-zh-cn-deep-scan-rerun` 退出码 `0`

追加补扫：

- 新增扫描规则：`submenu` / `submenu_with_icon`、`toggleable_entry`、`label_with_contrast`、component preview 的 `example_group_with_title`、`single_example`、组件 `description()` 和 Dropdown/ToggleButton 示例标签。
- 补齐 Quick Action Bar 切换项、Git 提交按钮状态、Extensions 空状态、标题栏面板布局、Workspace 主题预览、UI component preview 示例标题和说明。
- 修正机器初翻误译：`Custom` 统一为“自定义”，`Filled` 为“填充”，`Outlined` 为“描边”，`Ghost` 为“透明”，`States` 为“状态”，`Disabled` 为“禁用”，`API URL` 可见标签统一为“API 地址”。
- 追加深度补扫：自动更新远程服务器状态、诊断工具栏 Include/Exclude Warnings、Agent 诊断工具输出、DAP schema 的 label / markdownDeprecationMessage / enumDescriptions、编辑预测数据共享说明、计划 chip。
- 追加后验证：`scan-untranslated.ps1` 为 `candidates: 0`，component preview 专项扫描剩余 `0`，翻译表重复 id 为 `0`。
