# zedCn

`zedCn` 是基于 [zed-industries/zed](https://github.com/zed-industries/zed) 的 Zed 简体中文汉化仓库。

这个仓库不是单独的补丁仓库，而是直接在官方源码基础上维护中文本地化改动，目标是：

- 跟随官方 `main` 持续同步最新功能
- 将中文 UI 文案长期维护为可复用的汉化资产
- 让别人拉下仓库后可以继续构建、补翻、验收和发布

## 仓库定位

- `origin`：当前汉化仓库
- `upstream`：官方 `zed-industries/zed`
- 默认维护分支：`dev`

也就是说，这个仓库里已经包含官方源码，不需要再额外 clone 一份 Zed 才能继续开发汉化。

## 已包含内容

- Zed 源码及当前汉化改动
- `zh-cn-overlay/` 汉化维护脚本与翻译表
- 汉化方案与操作文档
- Windows 汉化安装包与便携包的构建流程

当前汉化维护入口：

- [ZED_ZH_CN_LOCALIZATION_PLAN.md](./docs/zh-cn/ZED_ZH_CN_LOCALIZATION_PLAN.md)
- [ZH_CN_LOCALIZATION_STEPS.md](./docs/zh-cn/ZH_CN_LOCALIZATION_STEPS.md)
- [FORK_MIGRATION_PLAN.md](./docs/zh-cn/FORK_MIGRATION_PLAN.md)

## 不包含内容

以下内容不会提交到仓库：

- 本地 `target/` 构建缓存
- 本地 `inno/` 打包目录
- `AGS_SDK`、`ConPTY` 等 Windows 打包依赖下载产物

原因很简单：这些文件体积大、可再生成、可再下载，不适合进入源码仓库。

## 快速开始

克隆后先确认远端：

```powershell
git remote -v
```

如果缺少官方上游：

```powershell
git remote add upstream https://github.com/zed-industries/zed.git
git remote set-url --push upstream DISABLED
```

## 汉化维护流程

同步官方更新：

```powershell
git switch dev
git fetch upstream
git merge upstream/main
```

运行汉化与检查：

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

## Windows 构建说明

别人拉取本仓库后，可以直接获得：

- 官方源码
- 汉化源码
- 汉化维护脚本

但如果要完整构建 Windows 安装包，除了 Rust 和 Visual Studio Build Tools 之外，还需要本地准备：

- `AGS_SDK`
- `Microsoft.Windows.Console.ConPTY`
- `Inno Setup`

这些依赖不会跟随 Git 仓库分发，所以不是 `git clone` 后立刻就能打出安装包；需要按文档准备一次本地环境。

详细步骤见：

- [docs/src/development/windows.md](./docs/src/development/windows.md)
- [ZH_CN_LOCALIZATION_STEPS.md](./docs/zh-cn/ZH_CN_LOCALIZATION_STEPS.md)

## 当前产物

本地已验证通过的常用产物路径：

- 安装包：`target/Zed-x86_64.exe`
- 便携包：`target/Zed-x86_64-portable-zh-cn.zip`
- 远程服务包：`target/zed-remote-server-windows-x86_64.zip`

这些产物默认不提交到 Git。

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

理想状态：

- `apply-zh-cn.ps1` 二次运行 `replacements: 0`
- `scan-untranslated.ps1` 输出 `candidates: 0`
- `translations.json` 无重复 ID

## 与官方项目的关系

本仓库是社区汉化维护仓库，不是 Zed 官方发布仓库。

- 官方项目主页：[zed.dev](https://zed.dev)
- 官方源码仓库：[zed-industries/zed](https://github.com/zed-industries/zed)

如果官方未来引入正式多语言/i18n 方案，这个仓库也可以继续作为中文翻译资产和迁移基础。
