import fs from "node:fs";
import path from "node:path";

const repo = process.argv[2] ? path.resolve(process.argv[2]) : path.resolve(".");
const overlay = path.join(repo, "zh-cn-overlay");
const translationsPath = path.join(overlay, "translations.json");
const reportPath = path.join(overlay, "untranslated-report.json");
const skippedPath = path.join(overlay, "machine-translate-skipped.json");

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8").replace(/^\uFEFF/, ""));
}

function rustLiteral(text) {
  return `"${text
    .replace(/\\/g, "\\\\")
    .replace(/"/g, '\\"')
    .replace(/\r/g, "\\r")
    .replace(/\n/g, "\\n")
    .replace(/\t/g, "\\t")}"`;
}

function countLiteralInCode(content, literal) {
  let count = 0;
  let index = 0;
  while ((index = content.indexOf(literal, index)) >= 0) {
    const lineStart = content.lastIndexOf("\n", Math.max(index - 1, 0)) + 1;
    if (!content.slice(lineStart, index).includes("//")) count += 1;
    index += literal.length;
  }
  return count;
}

function slug(text) {
  return (
    text
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "")
      .slice(0, 80) || "text"
  );
}

function moduleName(file) {
  return file
    .replace(/^crates\//, "")
    .replace(/\/src\/.*$/, "")
    .replace(/[^a-z0-9_]+/gi, "_");
}

const preserveExact = new Set([
  "AI",
  "API",
  "AWS",
  "Claude",
  "CodeQL",
  "Copilot",
  "CSS",
  "DAP",
  "Docker",
  "ESLint",
  "Git",
  "GitHub",
  "Helix",
  "HTML",
  "JSON",
  "LSP",
  "MCP",
  "OpenAI",
  "OpenCode",
  "OpenRouter",
  "SSH",
  "TLS",
  "TOML",
  "TypeScript",
  "URL",
  "Vim",
  "WSL",
  "Zed",
]);

const skipExact = new Set([
  ...preserveExact,
  "OpenAI",
  "Mistral",
  "Ollama",
  "Anthropic",
  "DeepSeek",
  "Gemini",
  "LM Studio",
  "xAI",
]);

function shouldSkip(text) {
  if (!text || skipExact.has(text)) return true;
  if (/^[A-Z][A-Za-z]+AI$/.test(text)) return true;
  if (/^[A-Z][A-Za-z]+[A-Z][A-Za-z]+$/.test(text) && text.length <= 20) return true;
  if (/^(https?:|zed:|ssh |[./~]|[A-Za-z]:\\)/.test(text)) return true;
  if (/^[a-z0-9_.:-]+$/.test(text)) return true;
  if (/^[A-Z0-9_]+$/.test(text) && text.length > 1) return true;
  return false;
}

function protectCodeSpans(text) {
  const values = [];
  const protectedText = text.replace(/`[^`]*`/g, (match) => {
    const token = `__CODE_${values.length}__`;
    values.push([token, match]);
    return token;
  });
  return { protectedText, values };
}

function restoreCodeSpans(text, values) {
  let restored = text;
  for (const [token, value] of values) {
    restored = restored.replaceAll(token, value);
    restored = restored.replaceAll(token.replaceAll("_", " "), value);
  }
  return restored;
}

function postprocess(text) {
  return text
    .replaceAll(" Zed ", " Zed ")
    .replaceAll("Git Hub", "GitHub")
    .replaceAll("Open AI", "OpenAI")
    .replaceAll("Open Router", "OpenRouter")
    .replaceAll("Type Script", "TypeScript")
    .replaceAll("Java Script", "JavaScript")
    .replaceAll("代理面板", "Agent 面板")
    .replaceAll("代理响应", "Agent 响应")
    .replaceAll("Zed 代理", "Zed Agent")
    .replaceAll("AI功能", "AI 功能")
    .replaceAll("API密钥", "API 密钥")
    .replaceAll("JSON文件", "JSON 文件")
    .replaceAll("设置.json", "settings.json")
    .replaceAll("debug.json", "debug.json");
}

async function translate(text, attempt = 1) {
  const { protectedText, values } = protectCodeSpans(text);
  const params = new URLSearchParams({
    client: "gtx",
    sl: "en",
    tl: "zh-CN",
    dt: "t",
    q: protectedText,
  });
  const response = await fetch(
    `https://translate.googleapis.com/translate_a/single?${params.toString()}`,
  );
  if (!response.ok) {
    if (attempt < 4) {
      await new Promise((resolve) => setTimeout(resolve, 500 * attempt));
      return translate(text, attempt + 1);
    }
    throw new Error(`translate failed ${response.status}: ${text}`);
  }
  const data = await response.json();
  const translated = data?.[0]?.map((segment) => segment[0]).join("") ?? "";
  return postprocess(restoreCodeSpans(translated, values)).trim();
}

async function mapLimit(items, limit, fn) {
  const results = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: limit }, async () => {
    while (next < items.length) {
      const index = next++;
      results[index] = await fn(items[index], index);
    }
  });
  await Promise.all(workers);
  return results;
}

const translations = readJson(translationsPath);
const report = readJson(reportPath);
const existing = new Set(translations.map((entry) => `${entry.file}\0${entry.from}`));
const usedIds = new Set(translations.map((entry) => entry.id));

const grouped = new Map();
for (const item of report) {
  const key = `${item.file}\0${item.text}`;
  if (!grouped.has(key)) grouped.set(key, { file: item.file, text: item.text });
}

const contentCache = new Map();
const pending = [];
const skipped = [];
for (const item of grouped.values()) {
  if (existing.has(`${item.file}\0${item.text}`)) continue;
  if (shouldSkip(item.text)) {
    skipped.push({ ...item, reason: "skip_exact_or_code_like" });
    continue;
  }

  const absolute = path.join(repo, item.file);
  let content = contentCache.get(item.file);
  if (content === undefined) {
    content = fs.readFileSync(absolute, "utf8");
    contentCache.set(item.file, content);
  }
  const expectedCount = countLiteralInCode(content, rustLiteral(item.text));
  if (expectedCount <= 0) {
    skipped.push({ ...item, reason: "source_literal_not_found" });
    continue;
  }
  pending.push({ ...item, expectedCount });
}

console.log(`pending=${pending.length}`);
const translatedItems = await mapLimit(pending, 8, async (item, index) => {
  if (index % 50 === 0) console.log(`translated ${index}/${pending.length}`);
  const translated = await translate(item.text);
  return { ...item, translated };
});

let added = 0;
for (const item of translatedItems) {
  if (!item.translated || item.translated === item.text) {
    skipped.push({ file: item.file, text: item.text, reason: "unchanged_translation" });
    continue;
  }
  const base = `auto.mt.${moduleName(item.file)}.${slug(item.text)}`;
  let id = base;
  let suffix = 2;
  while (usedIds.has(id)) id = `${base}_${suffix++}`;
  usedIds.add(id);
  translations.push({
    id,
    file: item.file,
    from: item.text,
    to: item.translated,
    expected_count: item.expectedCount,
  });
  existing.add(`${item.file}\0${item.text}`);
  added += 1;
}

fs.writeFileSync(translationsPath, `${JSON.stringify(translations, null, 2)}\n`, "utf8");
fs.writeFileSync(skippedPath, `${JSON.stringify(skipped, null, 2)}\n`, "utf8");
console.log(`added=${added}`);
console.log(`skipped=${skipped.length}`);
console.log(`total=${translations.length}`);
