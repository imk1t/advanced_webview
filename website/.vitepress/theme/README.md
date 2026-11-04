# Docs site design system

The docs site has a small design system so new pages and features look like the rest of the
site. Tokens live in CSS variables, components are Vue files, and both are registered globally,
so Markdown pages can use them without imports. This file is for contributors editing `website/`
and is not published on the site.

## Where things live

| What | File |
| --- | --- |
| Tokens (colour, radius, font, spacing), light and dark | `website/.vitepress/theme/tokens.css` |
| Components (`Aw*.vue`) | `website/.vitepress/theme/components/` |
| Styles that need real CSS (dot pattern, code panel) | `website/.vitepress/theme/design-system.css` |
| Content width and table overrides | `website/.vitepress/theme/layout.css` |

## Tokens

Use a role, never a raw colour. In Tailwind utilities write `tw:bg-(--aw-surface)`.

| Token | Role |
| --- | --- |
| `--aw-bg`, `--aw-surface`, `--aw-surface-soft` | Page background, cards, soft fills |
| `--aw-ink`, `--aw-ink-muted` | Text and secondary text |
| `--aw-line` | Borders and dividers |
| `--aw-accent`, `--aw-accent-2` | Indigo and cyan accents (links, eyebrow, gradient text) |
| `--aw-panel*` | Dark panels (code, call to action), dark in both colour schemes |
| `--aw-radius-sm`, `--aw-radius`, `--aw-radius-lg` | Corner radii |
| `--aw-section-y`, `--aw-content-w` | Vertical section rhythm and content width |
| `--aw-font-mono` | Monospace stack |

The tokens are mapped onto VitePress' own variables, so the nav, sidebar and documentation pages
follow the same palette. Dark mode redefines the same tokens under `.dark`.

## Components

| Component | Use |
| --- | --- |
| `AwHero` | Landing hero: `eyebrow`, `title`, `accent` (gradient run), `lead`, `#actions` slot |
| `AwButton` | Link button: `href`, `variant` = `primary`, `secondary`, `inverse`, `inverse-outline` |
| `AwSection` | Section with optional `eyebrow`, `title`, `lead`; `flush` removes the top padding |
| `AwGrid` | 1 column on phones, `cols` 2 or 3 above |
| `AwFeature` | Borderless highlight with a title and text, inside `AwGrid` |
| `AwCard` | Bordered card: `title`, `art` (`accent` or `accent-2`), `href` and `cta` for a link |
| `AwCodePanel` | Dark showcase panel around a `::: code-group` |
| `AwCta` | Closing call to action with an `#actions` slot |
| `AwContainer` | Centres content at `--aw-content-w` |

A page built from these components uses `layout: page` with `sidebar: false` and `aside: false`:

```md
---
layout: page
sidebar: false
aside: false
---

<AwHero title="Page title" accent="with an accent." lead="One sentence.">
  <template #actions>
    <AwButton href="/guide/getting-started">Get started</AwButton>
  </template>
</AwHero>

<AwSection title="Section" flush>
  <AwGrid :cols="2">
    <AwCard title="Card" href="/guide/settings" cta="Read the guide">Short text.</AwCard>
  </AwGrid>
</AwSection>
```

## Rules

- New visuals reuse tokens and components. Add a token or component here first if one is missing,
  then use it.
- Documentation pages stay plain Markdown; they inherit the tokens through VitePress' variables.
- Tailwind utilities carry the `tw:` prefix and are not in a cascade layer, on purpose: VitePress'
  own styles are unlayered and would otherwise win.
- Keep English and Japanese pages in sync, and check both colour schemes and a phone-width view.
- Do not add this material to the published docs; it stays in this file.
