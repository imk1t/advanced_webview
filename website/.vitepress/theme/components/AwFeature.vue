<script setup lang="ts">
// Borderless highlight: bold title and short text. Use inside AwGrid.
defineProps<{ title: string }>()
</script>

<template>
  <div>
    <h3
      class="tw:m-0 tw:mb-1.5 tw:border-0 tw:p-0 tw:text-[1.0625rem] tw:font-semibold tw:text-(--aw-ink)"
    >
      {{ title }}
    </h3>
    <p class="tw:m-0 tw:text-[0.9375rem] tw:leading-relaxed tw:text-(--aw-ink-muted)"><slot /></p>
  </div>
</template>
