<script setup lang="ts">
// Link-styled button. `primary` is solid ink, `secondary` is outlined, `inverse` is for dark panels.
import { computed } from 'vue'
import { withBase } from 'vitepress'

const props = withDefaults(
  defineProps<{
    href: string
    variant?: 'primary' | 'secondary' | 'inverse' | 'inverse-outline'
  }>(),
  { variant: 'primary' },
)

const external = computed(() => /^https?:/.test(props.href))
const link = computed(() => (external.value ? props.href : withBase(props.href)))

const base =
  'tw:inline-flex tw:items-center tw:gap-1.5 tw:rounded-(--aw-radius) tw:px-5 tw:py-3 tw:text-[15px] tw:font-semibold tw:no-underline tw:transition-opacity hover:tw:opacity-85'
const tone = {
  primary: 'tw:bg-(--aw-ink) tw:text-(--aw-bg)',
  secondary: 'tw:border tw:border-(--aw-line) tw:text-(--aw-ink)',
  inverse: 'tw:bg-white tw:text-(--aw-panel)',
  'inverse-outline': 'tw:border tw:border-(--aw-panel-line) tw:text-white',
}
</script>

<template>
  <a
    :href="link"
    :class="[base, tone[variant]]"
    :target="external ? '_blank' : undefined"
    :rel="external ? 'noreferrer' : undefined"
  >
    <slot />
    <span v-if="external" aria-hidden="true">↗</span>
  </a>
</template>
