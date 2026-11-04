import DefaultTheme from 'vitepress/theme'
import type { Theme } from 'vitepress'
import ApiMapping from './ApiMapping.vue'
import AwButton from './components/AwButton.vue'
import AwCard from './components/AwCard.vue'
import AwCodePanel from './components/AwCodePanel.vue'
import AwContainer from './components/AwContainer.vue'
import AwCta from './components/AwCta.vue'
import AwFeature from './components/AwFeature.vue'
import AwGrid from './components/AwGrid.vue'
import AwHero from './components/AwHero.vue'
import AwSection from './components/AwSection.vue'
import './tailwind.css'
import './tokens.css'
import './layout.css'
import './design-system.css'

// Design system components (see guide/design-system). Registered globally so Markdown pages can
// use them without imports.
const components = {
  AwButton,
  AwCard,
  AwCodePanel,
  AwContainer,
  AwCta,
  AwFeature,
  AwGrid,
  AwHero,
  AwSection,
}

export default {
  extends: DefaultTheme,
  enhanceApp({ app }) {
    app.component('ApiMapping', ApiMapping)
    for (const [name, component] of Object.entries(components)) app.component(name, component)
  },
} satisfies Theme
