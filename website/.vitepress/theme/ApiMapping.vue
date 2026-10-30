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
    <table class="api-mapping">
      <thead>
        <tr>
          <th>{{ labels[locale].dart }}</th>
          <th>{{ labels[locale].android }}</th>
          <th>{{ labels[locale].ios }}</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="row in rows" :id="anchorFor(row.entry.dart)" :key="row.entry.dart">
          <td>
            <code>{{ row.entry.dart }}</code>
            <p class="api-mapping__summary">{{ row.entry.summary[locale] }}</p>
          </td>
          <td v-if="row.entry.dartOnly" colspan="2" class="api-mapping__dart-only">
            {{ labels[locale].dartOnly }}
          </td>
          <template v-else>
            <td v-for="{ platform, side, refs } in row.sides" :key="platform">
              <template v-if="side">
                <span :class="['api-mapping__badge', `api-mapping__badge--${side.status}`]">
                  {{ labels[locale].status[side.status] }}
                </span>
                <ul v-if="refs.length" class="api-mapping__apis">
                  <li v-for="ref in refs" :key="ref.api">
                    <code
                      ><a v-if="ref.href" :href="ref.href" target="_blank" rel="noreferrer">{{
                        ref.className
                      }}</a
                      ><template v-else>{{ ref.className }}</template
                      >{{ ref.rest }}</code
                    >
                  </li>
                </ul>
                <p v-if="side.note" class="api-mapping__note">{{ side.note[locale] }}</p>
              </template>
            </td>
          </template>
        </tr>
      </tbody>
    </table>
  </div>
</template>
