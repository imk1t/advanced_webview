import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import ApiMapping from './ApiMapping.vue'
import './api-mapping.css'

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('ApiMapping', ApiMapping)
  },
} satisfies Theme
