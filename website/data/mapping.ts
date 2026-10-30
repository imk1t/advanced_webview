// Types and helpers for api-mapping.json, shared by the docs component and
// the drift check (scripts/check-api-mapping.ts).

export type Platform = 'android' | 'ios'
export type Status = 'supported' | 'partial' | 'creationOnly' | 'unsupported'
export type Localized = { en: string; ja: string }

export interface PlatformMapping {
  status: Status
  /** Native references such as `WebView.loadUrl(String, Map)`; see {@link parseRef}. */
  apis: string[]
  note?: Localized
}

export interface MappingEntry {
  /** Dart symbol: `Class` or `Class.member`. Checked against lib/. */
  dart: string
  group: string
  summary: Localized
  /** No native counterpart; `android` and `ios` are omitted. */
  dartOnly?: boolean
  android?: PlatformMapping
  ios?: PlatformMapping
}

export interface ApiMapping {
  groups: { id: string; title: Localized }[]
  classes: Record<Platform, Record<string, string>>
  entries: MappingEntry[]
}

export interface NativeRef {
  className: string
  member?: string
  /** Text between the parentheses, if any (`''` for `foo()`). */
  args?: string
}

/**
 * Parses `Class`, `Class.member`, `Class.member(args)` and `Class(args)`.
 * Returns undefined when the text is not in that shape.
 */
export function parseRef(ref: string): NativeRef | undefined {
  const m = /^(\w+)(?:\.(\w+))?(?:\(([^)]*)\))?$/.exec(ref)
  if (!m) return undefined
  return { className: m[1], member: m[2], args: m[3] }
}

/** Anchor id for an entry, e.g. `AdvancedWebViewController.loadUrl` -> `advancedwebviewcontroller-loadurl`. */
export function anchorFor(dart: string): string {
  return dart.toLowerCase().replace(/\./g, '-')
}
