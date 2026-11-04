<script setup lang="ts">
// Left-aligned landing hero: eyebrow, display headline with an accent run, lead, actions.
defineProps<{ eyebrow?: string; title: string; accent?: string; lead?: string }>()
</script>

<template>
  <header class="tw:relative tw:overflow-hidden tw:py-16 tw:md:py-24">
    <div
      class="aw-dots tw:pointer-events-none tw:absolute tw:inset-0 tw:opacity-70 tw:[mask-image:linear-gradient(90deg,transparent_35%,#000)]"
      aria-hidden="true"
    />
    <AwContainer class="tw:relative">
      <p
        v-if="eyebrow"
        class="tw:m-0 tw:font-(family-name:--aw-font-mono) tw:text-xs tw:font-semibold tw:tracking-[0.12em] tw:text-(--aw-accent) tw:uppercase"
      >
        {{ eyebrow }}
      </p>
      <h1
        class="aw-display tw:mt-4 tw:mb-5 tw:max-w-[52rem] tw:text-[2.5rem] tw:leading-[1.08] tw:font-bold tw:tracking-tight tw:text-(--aw-ink) tw:md:text-[4.25rem]"
      >
        {{ title }}
        <span
          v-if="accent"
          class="tw:bg-linear-to-r tw:from-(--aw-accent) tw:to-(--aw-accent-2) tw:bg-clip-text tw:text-transparent"
          >{{ accent }}</span
        >
      </h1>
      <p
        v-if="lead"
        class="aw-lead tw:m-0 tw:max-w-[38rem] tw:text-lg tw:leading-relaxed tw:text-(--aw-ink-muted) tw:md:text-xl"
      >
        {{ lead }}
      </p>
      <div class="tw:mt-8 tw:flex tw:flex-wrap tw:gap-3"><slot name="actions" /></div>
    </AwContainer>
  </header>
</template>
