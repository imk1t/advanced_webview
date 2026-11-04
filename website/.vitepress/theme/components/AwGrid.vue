<script setup lang="ts">
// Responsive column grid for AwCard / AwFeature. One column on phones.
withDefaults(defineProps<{ cols?: 2 | 3 }>(), { cols: 3 })
</script>

<template>
  <div
    class="tw:grid tw:grid-cols-1 tw:gap-5"
    :class="cols === 3 ? 'tw:md:grid-cols-3' : 'tw:md:grid-cols-2'"
  >
    <slot />
  </div>
</template>
