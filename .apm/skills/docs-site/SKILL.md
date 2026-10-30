---
name: docs-site
description: Update the advanced_webview docs site (VitePress in website/, English and Japanese, deployed to GitHub Pages) after a code, API or behaviour change, then open a PR. Use when guide pages, the sidebar or the site config must change.
---

# Updating the docs site

The site is VitePress in `website/`: English pages at the root, Japanese under `website/ja/`.
Merging to `main` deploys it to GitHub Pages (`.github/workflows/docs.yml`). Read `AGENTS.md`
first; it takes precedence over this skill. Do not add Web, macOS, Windows or Linux content.

## Steps

1. **Find what changed.** Compare the code change with the guide pages in
   `website/guide/` (`getting-started`, `controller`, `javascript`, `navigation`, `settings`,
   `api-mapping`).
   Public API lives in `lib/advanced_webview.dart` and `lib/src/`; use the dartdoc and
   `CHANGELOG.md` (`## Unreleased`) as the source of truth, not memory.
2. **Edit the English page** in `website/guide/`. Keep code samples compiling against the
   current API (class names `AdvancedWebView`, `AdvancedWebViewController`) and note any
   Android/iOS difference explicitly.
3. **Edit the matching Japanese page** in `website/ja/guide/` in the same change. Translate
   prose only; keep code, identifiers and headings' anchors structurally identical. If a
   page exists in only one language, add the other.
4. **Update the API mapping.** `website/data/api-mapping.json` is the single source for the
   "Platform API mapping" pages (`website/guide/api-mapping.md`, `website/ja/guide/api-mapping.md`):
   one entry per public Dart member with the Android and iOS APIs it uses, a status
   (`supported`, `partial`, `creationOnly`, `unsupported`) and an `en`/`ja` summary. For every
   added, renamed or removed public member, or changed native call, edit the entry (cite
   only native APIs the Kotlin/Swift sources really use). A new group needs a section in
   both pages. Run `cd website && bun run check:mapping`; it fails on any drift from `lib/` and
   the native sources.
5. **New page?** Add it to both sidebars in `website/.vitepress/config.mts` (`root` and
   `ja` locales) and link it from a related page. `website/ja/guide/architecture.md`
   `@include`s `doc/architecture.md`; edit `doc/architecture.md` (Japanese) rather than
   copying it.
6. **Keep neighbours consistent.** If a user-visible behaviour changed, also check
   `README.md` / `README.ja.md` (keep them in sync), the dartdoc of the affected public
   members, and `CHANGELOG.md`.
7. **Format and build locally.** In `website/`: `bun install --frozen-lockfile`, `bun run lint` (oxlint), `bun run format` (Bun's built-in `bun fmt`; Markdown pages are excluded), then `bun run build`
   (it runs `check:mapping` first). The build fails on dead internal links, so fix them rather
   than ignoring the error. Optionally preview with `bun run dev`. Do not commit
   `node_modules/` or `.vitepress/dist`/`cache`.
8. **Open a PR** (use the `create-pr` skill and `.github/pull_request_template.md`). The
   `Docs` workflow builds the site on the PR; the deploy job runs only after merge to
   `main`. Mention in the PR which pages changed in both languages.

## Notes

- Styling: custom components use Tailwind v4 utilities with the `tw:` prefix (`tw:overflow-x-auto`);
  preflight is not imported, so the default VitePress theme is untouched. Content width is set
  in `website/.vitepress/theme/layout.css`.

- Site URL: https://imk1t.github.io/advanced_webview/ (`base: '/advanced_webview/'` in the
  config; change it to `/` only if a custom domain is set up).
- Changing `website/package.json` or the lockfile means updating `.github/workflows/docs.yml`
  to match.
- If you edit this skill, run `apm install --target agent-skills,claude,codex` and commit
  `apm.lock.yaml` with it (APM 0.33.0). Generated `.agents/` and `.claude/` stay uncommitted.

## Done when

- English and Japanese pages describe the same behaviour and the same API.
- `website/data/api-mapping.json` covers every public Dart API and `bun run check:mapping` passes.
- `bun run lint`, `bun run format:check` and `bun run build` pass in `website/`, with no errors and the sidebar lists every page in both languages.
- README, dartdoc and `CHANGELOG.md` do not contradict the guide.
