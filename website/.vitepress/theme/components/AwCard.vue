<script setup lang="ts">
// Bordered card. `art` adds a dotted header strip; `href` + `cta` add a link at the bottom.
import { computed } from 'vue'
import { withBase } from 'vitepress'

const props = defineProps<{
  title: string
  art?: 'accent' | 'accent-2'
  href?: string
  cta?: string
}>()
const external = computed(() => !!props.href && /^https?:/.test(props.href))
const link = computed(() =>
  props.href ? (external.value ? props.href : withBase(props.href)) : '',
)
</script>

<template>
  <div
    class="tw:overflow-hidden tw:rounded-(--aw-radius-lg) tw:border tw:border-(--aw-line) tw:bg-(--aw-surface)"
  >
    <div
      v-if="art"
      class="tw:h-28 tw:border-b tw:border-(--aw-line)"
      :class="art === 'accent' ? 'aw-dots-accent' : 'aw-dots-accent-2'"
      aria-hidden="true"
    />
    <div class="tw:p-5">
      <h3
        class="tw:m-0 tw:mb-1.5 tw:border-0 tw:p-0 tw:text-[1.0625rem] tw:font-semibold tw:text-(--aw-ink)"
      >
        {{ title }}
      </h3>
      <p class="tw:m-0 tw:text-[0.9375rem] tw:leading-relaxed tw:text-(--aw-ink-muted)"><slot /></p>
      <a
        v-if="href && cta"
        :href="link"
        :target="external ? '_blank' : undefined"
        :rel="external ? 'noreferrer' : undefined"
        class="tw:mt-3 tw:inline-block tw:text-sm tw:font-semibold tw:text-(--aw-accent) tw:no-underline hover:tw:underline"
        >{{ cta }} →</a
      >
    </div>
  </div>
</template>
