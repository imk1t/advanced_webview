<script setup lang="ts">
// Closing call to action on a dark panel. Put AwButton variant="inverse" / "inverse-outline" in `actions`.
defineProps<{ title: string; lead?: string }>()
</script>

<template>
  <AwContainer class="tw:pb-16">
    <div
      class="tw:rounded-3xl tw:border tw:border-(--aw-panel-line) tw:bg-(--aw-panel) tw:px-6 tw:py-16 tw:text-center tw:md:py-20"
    >
      <h2
        class="aw-display tw:m-0 tw:border-0 tw:p-0 tw:text-[1.75rem] tw:leading-tight tw:font-bold tw:tracking-tight tw:text-white tw:md:text-4xl"
      >
        {{ title }}
      </h2>
      <p
        v-if="lead"
        class="aw-lead tw:mx-auto tw:mt-3 tw:mb-0 tw:max-w-xl tw:text-(--aw-panel-muted)"
      >
        {{ lead }}
      </p>
      <div class="tw:mt-8 tw:flex tw:flex-wrap tw:justify-center tw:gap-3">
        <slot name="actions" />
      </div>
    </div>
  </AwContainer>
</template>
