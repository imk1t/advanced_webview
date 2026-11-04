<script setup lang="ts">
// Page section with an optional eyebrow, heading and lead paragraph, then free content.
defineProps<{ title?: string; lead?: string; eyebrow?: string; flush?: boolean }>()
</script>

<template>
  <section :class="flush ? 'tw:pb-[var(--aw-section-y)]' : 'tw:py-[var(--aw-section-y)]'">
    <AwContainer>
      <p
        v-if="eyebrow"
        class="tw:m-0 tw:mb-2 tw:font-(family-name:--aw-font-mono) tw:text-xs tw:font-semibold tw:tracking-[0.12em] tw:text-(--aw-accent) tw:uppercase"
      >
        {{ eyebrow }}
      </p>
      <h2
        v-if="title"
        class="aw-display tw:m-0 tw:border-0 tw:p-0 tw:text-[1.75rem] tw:leading-tight tw:font-bold tw:tracking-tight tw:text-(--aw-ink) tw:md:text-4xl"
      >
        {{ title }}
      </h2>
      <p v-if="lead" class="aw-lead tw:mt-3 tw:mb-0 tw:text-(--aw-ink-muted)">{{ lead }}</p>
      <div :class="title ? 'tw:mt-8' : ''"><slot /></div>
    </AwContainer>
  </section>
</template>
