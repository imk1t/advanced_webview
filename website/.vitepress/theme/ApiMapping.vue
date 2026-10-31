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

// Class names carry the `tw:` prefix. VitePress' own (unlayered) styles beat Tailwind's layered
// utilities, so the ones that clash with them (table, code) are marked important with `!`.
const badgeBase =
  'tw:inline-block tw:rounded-[10px] tw:px-2 tw:text-xs tw:leading-5 tw:font-semibold'
const badgeTone: Record<Status, string> = {
  supported: 'tw:bg-(--vp-c-success-soft) tw:text-(--vp-c-success-1)',
  partial: 'tw:bg-(--vp-c-warning-soft) tw:text-(--vp-c-warning-1)',
  creationOnly: 'tw:bg-(--vp-c-warning-soft) tw:text-(--vp-c-warning-1)',
  unsupported: 'tw:bg-(--vp-c-danger-soft) tw:text-(--vp-c-danger-1)',
}
const summaryClass = 'tw:mt-1 tw:mb-0 tw:text-[13px] tw:leading-normal tw:text-(--vp-c-text-2)'
const codeClass = 'tw:text-xs! tw:[overflow-wrap:anywhere]'
const cellClass = 'tw:align-top!'

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
  <div class="tw:my-4 tw:overflow-x-auto">
    <table class="tw:table! tw:w-full tw:table-fixed">
      <thead>
        <tr>
          <th class="tw:w-[30%]">{{ labels[locale].dart }}</th>
          <th class="tw:w-[35%]">{{ labels[locale].android }}</th>
          <th class="tw:w-[35%]">{{ labels[locale].ios }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :id="anchorFor(row.entry.dart)" :key="row.entry.dart">
          <td :class="cellClass">
            <code :class="codeClass">{{ row.entry.dart }}</code>
            <p :class="summaryClass">{{ row.entry.summary[locale] }}</p>
          </td>
          <td
            v-if="row.entry.dartOnly"
            colspan="2"
            :class="[cellClass, 'tw:text-[13px] tw:text-(--vp-c-text-2)']"
          >
            {{ labels[locale].dartOnly }}
          </td>
          <template v-else>
            <td v-for="{ platform, side, refs } in row.sides" :key="platform" :class="cellClass">
              <template v-if="side">
                <span :class="[badgeBase, badgeTone[side.status]]">
                  {{ labels[locale].status[side.status] }}
                </span>
                <ul v-if="refs.length" class="tw:mt-1.5 tw:mb-0 tw:list-none tw:p-0">
                  <li v-for="ref in refs" :key="ref.api" class="tw:my-0.5">
                    <code :class="codeClass"
                      ><a v-if="ref.href" :href="ref.href" target="_blank" rel="noreferrer">{{
                        ref.className
                      }}</a
                      ><template v-else>{{ ref.className }}</template
                      >{{ ref.rest }}</code
                    >
                  </li>
                </ul>
                <p v-if="side.note" :class="summaryClass">{{ side.note[locale] }}</p>
              </template>
            </td>
          </template>
        </tr>
      </tbody>
    </table>
  </div>
</template>
