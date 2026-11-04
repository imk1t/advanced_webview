# デザインシステム

ドキュメントサイトには小さなデザインシステムがあり、新しいページや機能を追加しても、サイト全体の見た目が揃うようにしています。トークンは CSS 変数、コンポーネントは Vue ファイルで、どちらもグローバルに登録済みです。Markdown ページからインポートなしで使えます。このページは `website/` を編集するコントリビューター向けです。

## 置き場所

| 内容 | ファイル |
| --- | --- |
| トークン（色・角丸・フォント・余白）。ライトとダーク | `website/.vitepress/theme/tokens.css` |
| コンポーネント（`Aw*.vue`） | `website/.vitepress/theme/components/` |
| CSS が必要なスタイル（ドット模様、コードパネル） | `website/.vitepress/theme/design-system.css` |
| コンテンツ幅と表の上書き | `website/.vitepress/theme/layout.css` |

## トークン

色の値は直接書かず、役割で指定します。Tailwind では `tw:bg-(--aw-surface)` のように書きます。

| トークン | 役割 |
| --- | --- |
| `--aw-bg`, `--aw-surface`, `--aw-surface-soft` | ページ背景、カード、薄い塗り |
| `--aw-ink`, `--aw-ink-muted` | 本文と補助テキスト |
| `--aw-line` | 罫線と区切り |
| `--aw-accent`, `--aw-accent-2` | インディゴとシアンのアクセント（リンク、小見出し、グラデーション文字） |
| `--aw-panel*` | 暗いパネル（コード、CTA）。どちらのカラースキームでも暗色 |
| `--aw-radius-sm`, `--aw-radius`, `--aw-radius-lg` | 角丸 |
| `--aw-section-y`, `--aw-content-w` | セクションの縦の間隔とコンテンツ幅 |
| `--aw-font-mono` | 等幅フォント |

トークンは VitePress の変数にも割り当てているので、ナビやサイドバー、ドキュメントページも同じ配色になります。ダークモードは `.dark` 配下で同じトークンを再定義しています。

## コンポーネント

| コンポーネント | 用途 |
| --- | --- |
| `AwHero` | トップのヒーロー。`eyebrow`、`title`、`accent`（グラデーション部分）、`lead`、`#actions` スロット |
| `AwButton` | リンクボタン。`href`、`variant` は `primary` / `secondary` / `inverse` / `inverse-outline` |
| `AwSection` | セクション。`eyebrow`、`title`、`lead` は任意。`flush` で上の余白をなくす |
| `AwGrid` | スマホは1列、それ以上は `cols` で 2 または 3 列 |
| `AwFeature` | 枠なしのハイライト。タイトルと本文。`AwGrid` の中で使う |
| `AwCard` | 枠付きカード。`title`、`art`（`accent` / `accent-2`）、リンクは `href` と `cta` |
| `AwCodePanel` | `::: code-group` を包む暗いコードパネル |
| `AwCta` | 末尾の行動喚起。`#actions` スロット |
| `AwContainer` | `--aw-content-w` の幅で中央寄せ |

これらで作るページは、`layout: page` に `sidebar: false` と `aside: false` を付けます。

```md
---
layout: page
sidebar: false
aside: false
---

<AwHero title="ページタイトル" accent="アクセント部分" lead="1文の説明。">
  <template #actions>
    <AwButton href="/ja/guide/getting-started">はじめる</AwButton>
  </template>
</AwHero>

<AwSection title="セクション" flush>
  <AwGrid :cols="2">
    <AwCard title="カード" href="/ja/guide/settings" cta="ガイドを読む">短い説明。</AwCard>
  </AwGrid>
</AwSection>
```

## ルール

- 新しい見た目は、既存のトークンとコンポーネントを使います。足りないものは、先にここへ追加してから使います。
- ドキュメントページは素の Markdown のままにします。VitePress の変数経由でトークンが効きます。
- Tailwind のユーティリティには `tw:` プレフィックスを付け、あえてカスケードレイヤーには入れていません。VitePress の既存スタイルがレイヤー外にあり、そのままだと負けてしまうためです。
- 英語と日本語のページを揃え、両方のカラースキームとスマホ幅で確認します。
