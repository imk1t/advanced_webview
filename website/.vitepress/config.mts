import { defineConfig } from 'vitepress'

const repo = 'https://github.com/imk1t/advanced_webview'

export default defineConfig({
  title: 'advanced_webview',
  description: 'A lean, type-safe WebView plugin for Android and iOS built on Pigeon.',
  // Served from https://imk1t.github.io/advanced_webview/ (project Pages).
  // Change to '/' when a custom domain is configured.
  base: '/advanced_webview/',
  cleanUrls: true,
  lastUpdated: true,

  themeConfig: {
    socialLinks: [{ icon: 'github', link: repo }],
    search: { provider: 'local' },
  },

  locales: {
    root: {
      label: 'English',
      lang: 'en',
      themeConfig: {
        nav: [
          { text: 'Guide', link: '/guide/getting-started' },
          { text: 'Changelog', link: `${repo}/blob/main/CHANGELOG.md` },
        ],
        sidebar: [
          {
            text: 'Guide',
            items: [
              { text: 'Getting started', link: '/guide/getting-started' },
              { text: 'Controller and widget', link: '/guide/controller' },
              { text: 'JavaScript', link: '/guide/javascript' },
              { text: 'Navigation', link: '/guide/navigation' },
              { text: 'Settings', link: '/guide/settings' },
              { text: 'Platform API mapping', link: '/guide/api-mapping' },
            ],
          },
        ],
        editLink: {
          pattern: `${repo}/edit/main/website/:path`,
          text: 'Edit this page on GitHub',
        },
        footer: { message: 'Released under the MIT License.' },
      },
    },
    ja: {
      label: '日本語',
      lang: 'ja',
      link: '/ja/',
      themeConfig: {
        nav: [
          { text: 'ガイド', link: '/ja/guide/getting-started' },
          { text: '変更履歴', link: `${repo}/blob/main/CHANGELOG.md` },
        ],
        sidebar: [
          {
            text: 'ガイド',
            items: [
              { text: 'はじめに', link: '/ja/guide/getting-started' },
              { text: 'コントローラとウィジェット', link: '/ja/guide/controller' },
              { text: 'JavaScript', link: '/ja/guide/javascript' },
              { text: 'ナビゲーション', link: '/ja/guide/navigation' },
              { text: '設定', link: '/ja/guide/settings' },
              { text: 'ネイティブ API 対応表', link: '/ja/guide/api-mapping' },
              { text: 'アーキテクチャ', link: '/ja/guide/architecture' },
            ],
          },
        ],
        editLink: {
          pattern: `${repo}/edit/main/website/:path`,
          text: 'GitHub でこのページを編集',
        },
        footer: { message: 'MIT License で公開しています。' },
        outline: { label: '目次' },
        docFooter: { prev: '前へ', next: '次へ' },
        lastUpdated: { text: '最終更新' },
      },
    },
  },
})
