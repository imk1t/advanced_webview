<script setup lang="ts">
// Renders one group of data/api-mapping.json as a table: Dart API -> Android / iOS native APIs.
import { computed } from 'vue'
import { useData } from 'vitepress'
import mappingJson from '../../data/api-mapping.json'
import { anchorFor, parseRef } from '../../data/mapping'
import type { ApiMapping, Platform, PlatformMapping, Status } from '../../data/mapping'

const props = defineProps<{ group: string }>()
const mapping = mappingJson as ApiMapping
const { lang } = useData()
const locale = computed<'en' | 'ja'>(() => (lang.value.startsWith('ja') ? 'ja' : 'en'))

const entries = computed(() => mapping.entries.filter((e) => e.group === props.group))

const labels = {
  en: {
    dart: 'Dart API',
    android: 'Android',
    ios: 'iOS',
    dartOnly: 'Dart only',
    status: {
      supported: 'Supported',
      partial: 'Partial',
      creationOnly: 'Creation only',
      unsupported: 'Not supported',
    } satisfies Record<Status, string>,
  },
  ja: {
    dart: 'Dart API',
    android: 'Android',
    ios: 'iOS',
    dartOnly: 'Dart のみ',
    status: {
      supported: '対応',
      partial: '一部対応',
      creationOnly: '作成時のみ',
      unsupported: '非対応',
    } satisfies Record<Status, string>,
  },
}

const platforms: Platform[] = ['android', 'ios']

// Status badge: a dot plus label in the VitePress status colours. Classes carry the `tw:` prefix;
// layout and spacing live in this template, the look comes from the design tokens (tokens.css).
const badgeBase =
  'tw:inline-flex tw:items-center tw:gap-1.5 tw:rounded-full tw:px-2.5 tw:py-0.5 tw:text-xs tw:leading-5 tw:font-semibold'
const badgeTone: Record<Status, string> = {
  supported: 'tw:bg-(--vp-c-success-soft) tw:text-(--vp-c-success-1)',
  partial: 'tw:bg-(--vp-c-warning-soft) tw:text-(--vp-c-warning-1)',
  creationOnly: 'tw:bg-(--vp-c-warning-soft) tw:text-(--vp-c-warning-1)',
  unsupported: 'tw:bg-(--vp-c-danger-soft) tw:text-(--vp-c-danger-1)',
}

// Break opportunities for long identifiers: after dots, parens, commas and colons, so the
// names stay intact and only wrap at those points (or at a hard limit via overflow-wrap).
function parts(text: string) {
  return text.split(/(?<=[.(,:])/)
}

function refOf(platform: Platform, api: string) {
  const ref = parseRef(api)
  if (!ref) return { api, className: api, rest: '', href: undefined }
  return {
    api,
    className: ref.className,
    rest: api.slice(ref.className.length),
    href: mapping.classes[platform][ref.className],
  }
}

const rows = computed(() =>
  entries.value.map((entry) => ({
    entry,
    sides: platforms.map((platform) => {
      const side: PlatformMapping | undefined = entry[platform]
      return { platform, side, refs: (side?.apis ?? []).map((api) => refOf(platform, api)) }
    }),
  })),
)
</script>

<template>
  <!--
    Plain div/span markup on purpose: VitePress' `.vp-doc` styles for table, ul, p and code have
    higher specificity than utilities and would fight the layout.
    Phones: one column. Tablets: Dart API on top, Android and iOS side by side.
    Wide screens: three columns under a header strip.
  -->
  <div
    class="tw:my-6 tw:overflow-hidden tw:rounded-(--aw-radius-lg) tw:border tw:border-(--aw-line) tw:bg-(--aw-surface)"
  >
    <div
      class="tw:hidden tw:grid-cols-[1.15fr_1fr_1fr] tw:gap-x-6 tw:border-b tw:border-(--aw-line) tw:bg-(--aw-surface-soft) tw:px-5 tw:py-2.5 tw:text-xs tw:font-semibold tw:tracking-wider tw:text-(--aw-ink-muted) tw:uppercase tw:xl:grid"
      aria-hidden="true"
    >
      <span>{{ labels[locale].dart }}</span>
      <span>{{ labels[locale].android }}</span>
      <span>{{ labels[locale].ios }}</span>
    </div>
    <div
      v-for="row in rows"
      :id="anchorFor(row.entry.dart)"
      :key="row.entry.dart"
      class="tw:grid tw:scroll-mt-20 tw:grid-cols-1 tw:gap-x-6 tw:gap-y-4 tw:border-t tw:border-(--aw-line) tw:px-5 tw:py-4 tw:first:border-t-0 tw:sm:grid-cols-2 tw:xl:grid-cols-[1.15fr_1fr_1fr]"
    >
      <div class="tw:min-w-0 tw:sm:col-span-2 tw:xl:col-span-1">
        <span
          class="tw:block tw:font-(family-name:--aw-font-mono) tw:text-[0.8125rem] tw:leading-6 tw:font-semibold tw:text-(--aw-ink)"
          ><template v-for="(part, i) in parts(row.entry.dart)" :key="i"
            ><wbr v-if="i > 0" />{{ part }}</template
          ></span
        >
        <span class="tw:mt-1 tw:block tw:text-[0.8125rem] tw:leading-5 tw:text-(--aw-ink-muted)">{{
          row.entry.summary[locale]
        }}</span>
      </div>
      <div
        v-if="row.entry.dartOnly"
        class="tw:text-[0.8125rem] tw:text-(--aw-ink-muted) tw:sm:col-span-2 tw:xl:col-span-2"
      >
        {{ labels[locale].dartOnly }}
      </div>
      <template v-else>
        <div v-for="{ platform, side, refs } in row.sides" :key="platform" class="tw:min-w-0">
          <span
            class="tw:mb-1.5 tw:block tw:text-xs tw:font-semibold tw:tracking-wider tw:text-(--aw-ink-muted) tw:uppercase tw:xl:hidden"
            >{{ labels[locale][platform] }}</span
          >
          <template v-if="side">
            <span :class="[badgeBase, badgeTone[side.status]]">
              <span class="tw:size-1.5 tw:rounded-full tw:bg-current" aria-hidden="true" />
              {{ labels[locale].status[side.status] }}
            </span>
            <div v-if="refs.length" class="tw:mt-2 tw:flex tw:flex-wrap tw:gap-1.5">
              <span
                v-for="ref in refs"
                :key="ref.api"
                class="tw:rounded-md tw:bg-(--aw-surface-soft) tw:px-2 tw:py-0.5 tw:font-(family-name:--aw-font-mono) tw:text-xs tw:leading-5 tw:text-(--aw-ink) tw:[overflow-wrap:anywhere]"
                ><a
                  v-if="ref.href"
                  :href="ref.href"
                  target="_blank"
                  rel="noreferrer"
                  class="tw:font-semibold! tw:text-(--aw-accent)! tw:no-underline! hover:tw:underline!"
                  >{{ ref.className }}</a
                ><template v-else>{{ ref.className }}</template
                ><template v-for="(part, i) in parts(ref.rest)" :key="i"
                  ><wbr v-if="i > 0" />{{ part }}</template
                ></span
              >
            </div>
            <span
              v-if="side.note"
              class="tw:mt-2 tw:block tw:text-[0.8125rem] tw:leading-5 tw:text-(--aw-ink-muted)"
              >{{ side.note[locale] }}</span
            >
          </template>
        </div>
      </template>
    </div>
  </div>
</template>
