/**
 * Builds the published documentation site from the Markdown already in this
 * repository.
 *
 *   node build.mjs        → docs/site/dist
 *
 * The documents are the source of truth and stay readable on GitHub; this
 * script only wraps them in a shell and rewrites the links. Nothing here should
 * ever require editing a document to keep the site working — a document that
 * renders on GitHub renders here.
 *
 * Link rewriting is the whole trick. A link in a Markdown file is relative to
 * that file, and the site is flat, so every href is resolved against its source
 * file and then re-pointed at one of three places:
 *
 *   - another published page  → its slug on this site
 *   - an asset under docs/    → the copied asset
 *   - anything else in the repo (LICENSE, .env.example, Go source) → GitHub
 *
 * That last case is why the site can link to code it does not publish.
 */
import {cpSync, mkdirSync, readFileSync, rmSync, writeFileSync} from "node:fs";
import {dirname, join, posix, relative, resolve} from "node:path";
import {fileURLToPath} from "node:url";

import {Marked} from "marked";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HERE, "..", "..");
const OUT = join(HERE, "dist");

const GITHUB = "https://github.com/gerege-systems/open-dgov-mn";
const BLOB = `${GITHUB}/blob/main`;

/* ── What gets published ──────────────────────────────────────────────────── */

/**
 * Every page on the site, in sidebar order. `group` buckets them in the
 * sidebar; `lang` marks the translations of the overview so they can be
 * offered as a language row rather than as separate sidebar entries.
 *
 * The deployment README is published as-is under Ажиллагаа. It is the
 * operator's page — ports, rollout, the way back — and keeping it in one place
 * is the point: a second copy on this site is a second thing to keep true.
 */
const PAGES = [
  {src: "docs/index.md", slug: "index", title: "Тойм", group: "Танилцуулга", lang: "mn"},
  {src: "docs/overview-en.md", slug: "overview-en", title: "Overview", group: "Танилцуулга", lang: "en"},

  {src: "docs/platform.md", slug: "platform", title: "Нээлттэй суурь платформ", group: "Хоёр домэйн"},
  {src: "docs/sso.md", slug: "sso", title: "Нэгдсэн нэвтрэлт", group: "Хоёр домэйн"},

  {src: "docs/federation.md", slug: "federation", title: "Систем холбох", group: "Холбогдох"},
  {src: "docs/security.md", slug: "security", title: "Аюулгүй байдал", group: "Холбогдох"},

  {src: "README.md", slug: "deployment", title: "Байрлуулалт", group: "Ажиллагаа"},
];

const bySrc = new Map(PAGES.map((p) => [p.src, p]));
// Two languages, so the row is two words rather than a flag strip. Mongolian
// is the source; the English page is a summary rather than a mirror, and says
// so at the top of itself.
const LANGS = [
  {lang: "mn", label: "Монгол"},
  {lang: "en", label: "English"},
];

/* ── Markdown → HTML ──────────────────────────────────────────────────────── */

const slugged = new Map();

/** A stable, collision-free id for a heading, so the sidebar can link into it. */
function headingId(text) {
  const base =
    text
      .toLowerCase()
      .replace(/<[^>]+>/g, "")
      .replace(/[^\p{L}\p{N}]+/gu, "-")
      .replace(/^-+|-+$/g, "") || "section";
  const seen = slugged.get(base) ?? 0;
  slugged.set(base, seen + 1);
  return seen ? `${base}-${seen}` : base;
}

/**
 * Re-points one href from "relative to this Markdown file" to "correct on this
 * site". Anchors, mailto: and absolute URLs are already right and pass through.
 */
function rewrite(href, srcPath) {
  if (!href || /^(https?:|mailto:|#|data:)/.test(href)) return href;

  const [pathPart, hash = ""] = href.split("#");
  if (!pathPart) return href;

  const repoRel = posix.normalize(posix.join(posix.dirname(srcPath), pathPart)).replace(/^\.\//, "");
  const anchor = hash ? `#${hash}` : "";

  const page = bySrc.get(repoRel);
  if (page) return `${page.slug}.html${anchor}`;
  // Assets are copied and served; a Markdown file sitting among them is prose,
  // not an asset, and a browser would download it rather than render it — so it
  // goes to GitHub with the rest of the unpublished files.
  if (repoRel.startsWith("docs/assets/") && !repoRel.endsWith(".md")) {
    return repoRel.slice("docs/".length) + anchor;
  }
  return `${BLOB}/${repoRel}${anchor}`;
}

function render(markdown, srcPath) {
  slugged.clear();
  const headings = [];
  const md = new Marked({gfm: true, breaks: false});

  md.use({
    renderer: {
      heading({tokens, depth}) {
        const text = this.parser.parseInline(tokens);
        const id = headingId(text);
        if (depth === 2 || depth === 3) headings.push({id, text, depth});
        return `<h${depth} id="${id}"><a class="anchor" href="#${id}" aria-hidden="true"></a>${text}</h${depth}>\n`;
      },
      link({href, title, tokens}) {
        const text = this.parser.parseInline(tokens);
        const target = rewrite(href, srcPath);
        const external = /^https?:/.test(target);
        return `<a href="${target}"${title ? ` title="${title}"` : ""}${
          external ? ' target="_blank" rel="noopener"' : ""
        }>${text}</a>`;
      },
      image({href, title, text}) {
        return `<img src="${rewrite(href, srcPath)}" alt="${text ?? ""}"${title ? ` title="${title}"` : ""}>`;
      },
      table(token) {
        // Wrapped so a wide table scrolls inside the column instead of pushing
        // the whole page sideways on a phone.
        const rendered = md.Renderer.prototype.table.call(this, token);
        return `<div class="table-scroll">${rendered}</div>`;
      },
    },
  });

  // Raw HTML in the source (the flag rows) carries hrefs marked has no reason
  // to touch, so they are rewritten here.
  let html = md.parse(markdown);
  html = html.replace(/(<a\s[^>]*href=")([^"]+)(")/g, (m, a, href, b) => a + rewrite(href, srcPath) + b);
  html = html.replace(/(<img\s[^>]*src=")([^"]+)(")/g, (m, a, src, b) => a + rewrite(src, srcPath) + b);

  return {html, headings};
}

/* ── Page shell ───────────────────────────────────────────────────────────── */

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function sidebar(current) {
  const groups = new Map();
  for (const p of PAGES) {
    // The seven overview translations collapse to one entry; the rest of the
    // languages are reachable from the language row on the page itself.
    if (p.lang && p.lang !== "mn") continue;
    if (!groups.has(p.group)) groups.set(p.group, []);
    groups.get(p.group).push(p);
  }
  const sections = [...groups]
    .map(([group, pages]) => {
      const items = pages
        .map((p) => {
          const active = p.slug === current || (p.lang && PAGES.find((q) => q.slug === current)?.lang && p.lang === "mn");
          return `<li><a href="${p.slug}.html"${active ? ' class="active" aria-current="page"' : ""}>${esc(p.title)}</a></li>`;
        })
        .join("");
      return `<div class="nav-group"><h4>${esc(group)}</h4><ul>${items}</ul></div>`;
    })
    .join("");
  return `<nav class="sidebar" aria-label="Баримтын цэс">${sections}</nav>`;
}

function languageRow(page) {
  if (!page?.lang) return "";
  const links = LANGS.map(({lang, label}) => {
    const target = PAGES.find((p) => p.lang === lang);
    if (!target) return "";
    return lang === page.lang
      ? `<b>${esc(label)}</b>`
      : `<a href="${target.slug}.html">${esc(label)}</a>`;
  }).join("");
  return `<div class="lang-row">${links}</div>`;
}

function shell({title, slug, body, toc = "", page}) {
  const rtl = page?.rtl ? ' dir="rtl"' : "";
  return `<!doctype html>
<html lang="${page?.lang ?? "mn"}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)} · Цахим Засаг</title>
<meta name="description" content="Засгийн газрын нээлттэй суурь платформ ба нэгдсэн нэвтрэлт — open.dgov.mn, sso.dgov.mn.">
<link rel="icon" href="assets/gov_icon.png">
<link rel="stylesheet" href="assets/theme.css">
</head>
<body>
<a class="skip" href="#content">Агуулга руу шилжих</a>
<header class="topbar">
  <a class="brand" href="index.html"><img class="mark-img" src="assets/gov_icon.png" alt=""> Цахим Засаг</a>
  <nav class="topnav">
    <a href="index.html">Тойм</a>
    <a href="platform.html">Платформ</a>
    <a href="sso.html">Нэвтрэлт</a>
    <a href="federation.html">Систем холбох</a>
  </nav>
  <div class="topactions">
    <a class="ghost" href="${GITHUB}" target="_blank" rel="noopener">GitHub</a>
    <a class="gold" href="https://open.dgov.mn" target="_blank" rel="noopener">Нэвтрэх</a>
  </div>
</header>
<div class="layout">
${sidebar(slug)}
<main id="content"${rtl}>
${page ? languageRow(page) : ""}
${body}
</main>
${toc}
</div>
<footer class="sitefoot">
  <span>© 2026 · <a href="https://github.com/gerege-systems/open-gerege-nexus" target="_blank" rel="noopener">Gerege Nexus</a> дээр суурилсан · Apache 2.0</span>
  <span><a href="${GITHUB}" target="_blank" rel="noopener">Эх код</a> · <a href="deployment.html">Байрлуулалт</a> · <a href="security.html">Аюулгүй байдал</a></span>
</footer>
</body>
</html>
`;
}

function tocFor(headings) {
  if (headings.length < 3) return "";
  const items = headings
    .map((h) => `<li class="d${h.depth}"><a href="#${h.id}">${h.text}</a></li>`)
    .join("");
  return `<aside class="toc" aria-label="Энэ хуудсанд"><h4>Энэ хуудсанд</h4><ul>${items}</ul></aside>`;
}

/* ── Build ────────────────────────────────────────────────────────────────── */

rmSync(OUT, {recursive: true, force: true});
mkdirSync(OUT, {recursive: true});

for (const page of PAGES) {
  const markdown = readFileSync(join(REPO, page.src), "utf8");
  const {html, headings} = render(markdown, page.src);
  writeFileSync(
    join(OUT, `${page.slug}.html`),
    shell({title: page.title, slug: page.slug, body: html, toc: tocFor(headings), page}),
  );
}

mkdirSync(join(OUT, "assets"), {recursive: true});
cpSync(join(REPO, "docs/assets"), join(OUT, "assets"), {
  recursive: true,
  filter: (src) => !src.endsWith(".md"),
});
cpSync(join(HERE, "theme.css"), join(OUT, "assets/theme.css"));
// Tells GitHub Pages not to run the output through Jekyll, which would drop
// any file or directory whose name begins with an underscore.
writeFileSync(join(OUT, ".nojekyll"), "");

console.log(`built ${PAGES.length} pages → ${relative(process.cwd(), OUT)}`);
