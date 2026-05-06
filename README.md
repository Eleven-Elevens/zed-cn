# zed-cn

`zed-cn` 是一个基于 [zed-industries/zed](https://github.com/zed-industries/zed) 的 Zed 简体中文汉化维护仓库。

这个仓库直接在官方源码基础上维护中文本地化改动，不是单独的补丁仓库，也不是只存打包产物的发布仓库。目标很明确：

- 跟随官方 `main` 持续同步最新功能
- 长期维护可复用的简体中文翻译资产
- 让别人拉下仓库后可以继续构建、补翻、验收和发布

## 当前状态

- 默认维护分支：`dev`
- 官方同步源：`upstream -> zed-industries/zed`
- 当前汉化翻译表：`4145` 条
- 当前扫描状态：`candidates: 0`
- 当前主仓库：`K:\Project\zed-cn`

如果你只是想直接使用成品，请优先看 Release 或本地构建产物。  
如果你想参与维护，请直接基于 `dev` 分支工作。

## 下载与产物

当前仓库常见的 Windows 产物约定如下：

- 安装包：`target/Zed-x86_64.exe`
- 远程服务包：`target/zed-remote-server-windows-x86_64.zip`
- 便携包：`target/Zed-x86_64-portable-zh-cn.zip`

这些产物默认**不提交到 Git**。对外发布时建议通过 GitHub Releases 分发。

## 仓库结构

最重要的目录和文件：

- `crates/`
  Zed 官方源码和汉化后的源码改动
- `zh-cn-overlay/`
  汉化翻译表、扫描脚本、精修脚本、自动补齐脚本
- `docs/zh-cn/`
  汉化方案、维护步骤、fork 迁移说明

文档入口：

- [本地汉化方案](./docs/zh-cn/ZED_ZH_CN_LOCALIZATION_PLAN.md)
- [本地化维护步骤](./docs/zh-cn/ZH_CN_LOCALIZATION_STEPS.md)
- [Fork 迁移方案](./docs/zh-cn/FORK_MIGRATION_PLAN.md)

## 分支说明

- `main`
  保留官方 fork 主线，用来跟踪官方仓库
- `dev`
  简体中文汉化维护主线，建议设置为 GitHub 默认分支

对这个仓库来说，真正长期维护的是 `dev`，不是 `main`。

## 快速开始

克隆后先确认远端：

```powershell
git remote -v
```

理想状态：

```text
origin   你的 zed-cn 仓库
upstream https://github.com/zed-industries/zed.git
```

如果缺少官方上游：

```powershell
git remote add upstream https://github.com/zed-industries/zed.git
git remote set-url --push upstream DISABLED
```

## 日常同步流程

同步官方最新代码：

```powershell
git switch dev
git fetch upstream
git merge upstream/main
```

重新套用汉化并检查：

```powershell
node .\zh-cn-overlay\auto-fill-from-report.mjs .
node .\zh-cn-overlay\refine-translations.mjs .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

重复 ID 检查：

```powershell
node -e "const fs=require('fs'); const t=JSON.parse(fs.readFileSync('zh-cn-overlay/translations.json','utf8').replace(/^\uFEFF/,'')); const ids=new Set(); let dup=0; for (const e of t) { if (ids.has(e.id)) dup++; ids.add(e.id); } console.log({entries:t.length, duplicate_ids:dup});"
```

理想结果：

- `apply-zh-cn.ps1` 二次运行 `replacements: 0`
- `scan-untranslated.ps1` 输出 `candidates: 0`
- `translations.json` 无重复 ID

## 构建说明

别人拉取本仓库后，可以直接获得：

- 官方源码
- 汉化源码
- 汉化维护脚本

但如果要完整构建 Windows 安装包，还需要本地准备：

- Rust toolchain
- Visual Studio Build Tools
- Windows SDK
- `AGS_SDK`
- `Microsoft.Windows.Console.ConPTY`
- `Inno Setup`

这些依赖不会随 Git 仓库分发，所以不是 `git clone` 后立刻就能完整打包。

相关参考：

- [官方 Windows 构建文档](./docs/src/development/windows.md)
- [本地化维护步骤](./docs/zh-cn/ZH_CN_LOCALIZATION_STEPS.md)

## 贡献建议

如果你想参与这个仓库，建议优先做这些事情：

- 补扫并修正遗漏的英文 UI 文案
- 改进 `scan-untranslated.ps1` 的命中率和误报过滤
- 统一术语风格，减少同义翻译
- 跟随官方上游同步并处理新增 UI
- 做真实界面的人工验收，找出扫描器抓不到的可见文案

提交前至少执行：

```powershell
node .\zh-cn-overlay\refine-translations.mjs .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

## 不包含内容

以下内容默认不提交到仓库：

- 本地 `target/` 构建缓存
- 本地 `inno/` 打包目录
- `AGS_SDK`、`ConPTY` 等 Windows 打包依赖下载产物

原因很简单：这些文件体积大、可再生成、可再下载，不适合作为源码资产进入 Git。

## 与官方项目的关系

本仓库是社区汉化维护仓库，不是 Zed 官方发布仓库。

- 官方项目主页：[zed.dev](https://zed.dev)
- 官方源码仓库：[zed-industries/zed](https://github.com/zed-industries/zed)

如果官方未来引入正式多语言 / i18n 方案，这个仓库也可以继续作为中文翻译资产和迁移基础。
