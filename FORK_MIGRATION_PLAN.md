# Fork 迁移方案

本文档记录 `zed-cn` 如何从旧的本地汉化仓库迁移为一个标准的官方 fork 维护仓库。

## 目标

- 使用官方 `zed-industries/zed` 作为真正的 Git 上游
- 在 `origin` 中保留自己的汉化维护分支 `dev`
- 避免继续维护“内容同步了，但 Git 历史不同源”的旧主线

## 当前结构

当前主仓库：

```text
K:\Project\zed-cn
```

当前远端：

```text
origin   https://github.com/Eleven-Elevens/zed-cn.git
upstream https://github.com/zed-industries/zed.git
```

当前维护分支：

```text
dev
```

说明：

- `main` 保持官方 fork 主线
- `dev` 作为简体中文汉化维护主线
- 旧仓库 `H:\zedCn` 只保留作备份和历史参考

## 迁移来源

旧仓库：

```text
H:\zedCn
```

它包含：

- 历史汉化源码改动
- `zh-cn-overlay/` 维护脚本与翻译表
- 历史构建与扫描文档

但它与官方仓库不是同一条 Git 历史，因此不适合作为长期同步上游的主仓库。

## 本次迁移采用的方法

迁移时没有直接把旧仓库继续当主仓库，而是：

1. 新建官方 fork 本地工作目录 `K:\Project\zed-cn`
2. 把旧仓库接为 `legacy` remote
3. 使用已验证通过的同步分支作为新的 `dev` 主线

核心分支来源：

```text
legacy/sync-upstream-2026-05-03
```

它的意义是：

- 基于官方 `upstream/main`
- 已重新套用汉化 overlay
- 已经过扫描和一致性验证

## 迁移后的维护原则

以后只在：

```text
K:\Project\zed-cn
```

里继续维护。

旧仓库：

```text
H:\zedCn
```

不要再作为主开发仓库使用。

## 后续同步官方更新

在新仓库中执行：

```powershell
git switch dev
git fetch upstream
git merge upstream/main
node .\zh-cn-overlay\auto-fill-from-report.mjs .
node .\zh-cn-overlay\refine-translations.mjs .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\apply-zh-cn.ps1 .
powershell -NoProfile -ExecutionPolicy Bypass -File .\zh-cn-overlay\scan-untranslated.ps1 .
```

再做重复 ID 检查：

```powershell
node -e "const fs=require('fs'); const t=JSON.parse(fs.readFileSync('zh-cn-overlay/translations.json','utf8').replace(/^\uFEFF/,'')); const ids=new Set(); let dup=0; for (const e of t) { if (ids.has(e.id)) dup++; ids.add(e.id); } console.log({entries:t.length, duplicate_ids:dup});"
```

理想状态：

- `apply-zh-cn.ps1` 二次运行 `replacements: 0`
- `scan-untranslated.ps1` 输出 `candidates: 0`
- `translations.json` 无重复 ID

## 为什么不继续用旧仓库直接同步

因为旧仓库虽然内容上已经接近官方源码，但 Git 历史不是从官方仓库直接演进出来的。

结果就是：

- 普通 `git merge upstream/main` 会很痛苦
- 有时甚至会被识别为“无共同历史”
- 长期维护成本很高

迁移到标准 fork 后，这个问题就消失了。

## 当前结论

一句话总结：

```text
以后只在 K:\Project\zed-cn 上维护，
用 dev 作为汉化主线，
用 upstream/main 作为官方同步源。
```
