// Fails when website/data/api-mapping.json drifts from the code:
//   - every public Dart API member has an entry, and every entry names a real symbol;
//   - every native API an entry cites still appears in the Kotlin / Swift sources;
//   - entries are complete (both languages, both platforms) and every group has a section
//     on both mapping pages.
// Run from website/: `bun run check:mapping`.
import { existsSync, readFileSync, readdirSync, statSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { parseRef } from '../data/mapping'
import type { ApiMapping, MappingEntry, Platform } from '../data/mapping'

const root = resolve(import.meta.dir, '../..')
const errors: string[] = []
const fail = (message: string) => errors.push(message)

// ---------------------------------------------------------------------------
// Dart: extract the public API surface

/** Classes whose members are mapped one by one. Every other public type needs one type-level entry. */
const MEMBER_LEVEL = new Set(['AdvancedWebViewController', 'AdvancedWebView', 'WebViewSettings'])
/** Public members that are plumbing, not API surface. */
const IGNORED_MEMBERS = new Set(['copyWith', 'toMessage'])

interface Statement {
  head: string
  body?: string
}

/** Removes comments and string contents so brace/paren matching is reliable. */
function stripDart(src: string): string {
  let out = ''
  let i = 0
  while (i < src.length) {
    const c = src[i]
    const n = src[i + 1]
    if (c === '/' && n === '/') {
      while (i < src.length && src[i] !== '\n') i++
    } else if (c === '/' && n === '*') {
      const end = src.indexOf('*/', i + 2)
      i = end < 0 ? src.length : end + 2
    } else if (c === "'" || c === '"') {
      i++
      while (i < src.length && src[i] !== c) i += src[i] === '\\' ? 2 : 1
      i++
      out += "''"
    } else {
      out += c
      i++
    }
  }
  return out
}

/** Splits `text` into statements at nesting depth 0 (`;` or a closing `}` block). */
function splitStatements(text: string): Statement[] {
  const result: Statement[] = []
  let depth = 0
  let start = 0
  let headEnd = -1
  let bodyStart = -1
  const push = (end: number) => {
    const head = text.slice(start, headEnd >= 0 ? headEnd : end)
    const body = bodyStart >= 0 ? text.slice(bodyStart, end) : undefined
    if (head.trim()) result.push({ head: head.replace(/\s+/g, ' ').trim(), body })
    start = end + 1
    headEnd = -1
    bodyStart = -1
  }
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if ('([{'.includes(c)) {
      if (c === '{' && depth === 0 && headEnd < 0) {
        headEnd = i
        bodyStart = i + 1
      }
      depth++
    } else if (')]}'.includes(c)) {
      depth--
      if (c === '}' && depth === 0) {
        // `final x = {1};` continues after the brace; a method body ends here.
        const next = /\S/.exec(text.slice(i + 1))?.[0]
        if (next !== ';' && next !== ',' && next !== ')') push(i)
      }
    } else if (c === ';' && depth === 0) {
      push(i)
    }
  }
  return result
}

function stripAnnotations(text: string): string {
  return text.replace(/@\w+(\.\w+)?(\([^)]*\))?\s*/g, '')
}

/** Names of the constructor parameters that are part of the public API. */
function constructorParams(head: string): string[] {
  const open = head.indexOf('(')
  let depth = 0
  let close = -1
  for (let i = open; i < head.length; i++) {
    if (head[i] === '(') depth++
    else if (head[i] === ')' && --depth === 0) {
      close = i
      break
    }
  }
  const inner = head.slice(open + 1, close).replace(/[{}[\]]/g, ' ')
  const params: string[] = []
  let depthAngle = 0
  let depthParen = 0
  let current = ''
  const flush = () => {
    if (current.trim()) params.push(current.trim())
    current = ''
  }
  for (const c of inner) {
    if (c === '<') depthAngle++
    else if (c === '>') depthAngle--
    else if (c === '(') depthParen++
    else if (c === ')') depthParen--
    if (c === ',' && depthAngle === 0 && depthParen === 0) flush()
    else current += c
  }
  flush()
  const names: string[] = []
  for (const param of params) {
    if (/@visibleForTesting\b/.test(param)) continue
    const cleaned = stripAnnotations(param).split('=')[0].trim()
    const thisParam = /\bthis\.(\w+)/.exec(cleaned)
    if (thisParam) names.push(thisParam[1])
    else if (/\bsuper\./.test(cleaned)) continue
    else {
      const last = /(\w+)$/.exec(cleaned)?.[1]
      if (last) names.push(last)
    }
  }
  return names.filter((n) => !n.startsWith('_'))
}

/** Public member names declared by one class-body statement. */
function memberNames(className: string, head: string): string[] {
  if (/@override\b/.test(head)) return []
  const text = stripAnnotations(head)
    .replace(/^(?:(?:static|final|const|late|external|abstract|covariant)\s+)+/, '')
    .trim()
  if (new RegExp(`^(?:factory\\s+)?${className}(?:\\.\\w+)?\\s*\\(`).test(text)) {
    return constructorParams(head)
  }
  if (/\boperator\b/.test(text)) return []
  const paren = text.indexOf('(')
  const equals = text.search(/=(?!>)/)
  const getter = /\bget\s+(\w+)/.exec(text)
  let name: string | undefined
  if (getter && (paren < 0 || getter.index < paren)) name = getter[1]
  else if (equals >= 0 && (paren < 0 || equals < paren))
    name = /(\w+)\s*$/.exec(text.slice(0, equals))?.[1]
  else if (paren < 0) name = /(\w+)\s*$/.exec(text)?.[1]
  else {
    const before = text.slice(0, paren)
    if (/\bset\s+\w+\s*$/.test(before)) return []
    name = /(\w+)\s*(?:<[^<>()]*>)?\s*$/.exec(before)?.[1]
  }
  return name && !name.startsWith('_') ? [name] : []
}

function publicDartApi(): Set<string> {
  const lib = join(root, 'lib')
  const symbols = new Set<string>()
  const original = readFileSync(join(lib, 'advanced_webview.dart'), 'utf8')
  for (const m of original.matchAll(/export\s+'([^']+)'(?:\s+show\s+([\w\s,]+))?;/g)) {
    const shown = m[2]?.split(',').map((s) => s.trim())
    const file = join(lib, m[1])
    for (const stmt of splitStatements(stripDart(readFileSync(file, 'utf8')))) {
      const decl =
        /^(?:@\w+\s+)*(?:(?:abstract|final|base|sealed|interface)\s+)*(class|enum|mixin)\s+(\w+)/.exec(
          stmt.head,
        )
      if (!decl || decl[2].startsWith('_')) continue
      const name = decl[2]
      if (shown && !shown.includes(name)) continue
      symbols.add(name)
      if (decl[1] === 'class' && MEMBER_LEVEL.has(name) && stmt.body) {
        for (const member of splitStatements(stmt.body)) {
          for (const n of memberNames(name, member.head)) {
            if (!IGNORED_MEMBERS.has(n)) symbols.add(`${name}.${n}`)
          }
        }
      }
    }
  }
  return symbols
}

// ---------------------------------------------------------------------------
// Native sources

function listFiles(dir: string, ext: string, skipGenerated: string): string[] {
  if (!existsSync(dir)) return []
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    if (statSync(path).isDirectory()) return listFiles(path, ext, skipGenerated)
    return name.endsWith(ext) && !name.endsWith(skipGenerated) ? [path] : []
  })
}

const nativeSource: Record<Platform, string> = {
  android: listFiles(join(root, 'android/src/main'), '.kt', '.g.kt')
    .map((f) => readFileSync(f, 'utf8'))
    .join('\n'),
  ios: listFiles(join(root, 'ios/advanced_webview/Sources'), '.swift', '.g.swift')
    .map((f) => readFileSync(f, 'utf8'))
    .join('\n'),
}

function hasToken(platform: Platform, token: string): boolean {
  return new RegExp(`\\b${token}\\b`).test(nativeSource[platform])
}

/** Kotlin uses property syntax, so `getTitle`/`setFoo`/`isBar` also match `title`/`foo`/`bar`. */
function androidMemberVariants(member: string): string[] {
  const m = /^(?:get|set|is)([A-Z]\w*)$/.exec(member)
  return m ? [member, m[1][0].toLowerCase() + m[1].slice(1)] : [member]
}

// ---------------------------------------------------------------------------
// Validate the mapping

const mapping: ApiMapping = JSON.parse(
  readFileSync(join(root, 'website/data/api-mapping.json'), 'utf8'),
)
const groupIds = new Set(mapping.groups.map((g) => g.id))
const dartApi = publicDartApi()
const seen = new Set<string>()
const platforms: Platform[] = ['android', 'ios']
const statuses = new Set(['supported', 'partial', 'creationOnly', 'unsupported'])

function checkEntry(entry: MappingEntry) {
  const at = `entry ${entry.dart}`
  if (seen.has(entry.dart)) fail(`${at}: duplicate entry`)
  seen.add(entry.dart)
  if (!dartApi.has(entry.dart)) {
    fail(`${at}: no such public Dart API in lib/ (renamed or removed? update or delete the entry)`)
  }
  if (!groupIds.has(entry.group)) fail(`${at}: unknown group "${entry.group}"`)
  if (!entry.summary?.en || !entry.summary?.ja) fail(`${at}: summary needs both "en" and "ja"`)
  if (entry.dartOnly) {
    if (entry.android || entry.ios) fail(`${at}: dartOnly entries must not have android/ios`)
    return
  }
  for (const platform of platforms) {
    const side = entry[platform]
    if (!side) {
      fail(`${at}: missing "${platform}" (set "dartOnly": true if there is no native counterpart)`)
      continue
    }
    if (!statuses.has(side.status)) fail(`${at}: ${platform}.status "${side.status}" is invalid`)
    if (side.status === 'unsupported' ? side.apis.length > 0 : side.apis.length === 0) {
      fail(
        `${at}: ${platform}.apis must be ${side.status === 'unsupported' ? 'empty' : 'non-empty'} for "${side.status}"`,
      )
    }
    if (side.status !== 'supported' && !(side.note?.en && side.note?.ja)) {
      fail(`${at}: ${platform} is "${side.status}" and needs a note in "en" and "ja"`)
    }
    if (side.note && !(side.note.en && side.note.ja))
      fail(`${at}: ${platform}.note needs both "en" and "ja"`)
    for (const api of side.apis) checkRef(at, platform, api)
  }
}

function checkRef(at: string, platform: Platform, api: string) {
  const ref = parseRef(api)
  if (!ref) return fail(`${at}: cannot parse ${platform} reference "${api}"`)
  if (!mapping.classes[platform][ref.className]) {
    return fail(
      `${at}: "${ref.className}" is not in classes.${platform} (add it with its documentation URL)`,
    )
  }
  // Only names this plugin's own native code uses can be verified.
  const tokens: string[] = []
  if (ref.member) {
    tokens.push(platform === 'android' ? androidMemberVariants(ref.member).join('|') : ref.member)
  } else {
    tokens.push(ref.className)
  }
  // Delegate callbacks are all named `webView(...)`; their first label tells them apart.
  if (platform === 'ios' && ref.member === 'webView') {
    const label = ref.args?.split(':').find((l) => l && l !== '_')
    if (label) tokens.push(label)
  }
  for (const token of tokens) {
    if (!hasToken(platform, `(?:${token})`)) {
      fail(
        `${at}: ${platform} reference "${api}" — "${token}" not found in the ${platform} sources (stale mapping?)`,
      )
    }
  }
}

mapping.entries.forEach(checkEntry)

// Every public Dart API must be mapped.
for (const symbol of [...dartApi].sort()) {
  const [className] = symbol.split('.')
  const isMember = symbol.includes('.')
  if (isMember ? !seen.has(symbol) : !MEMBER_LEVEL.has(symbol) && !seen.has(symbol)) {
    fail(
      `${symbol}: public Dart API without an entry in website/data/api-mapping.json` +
        (isMember
          ? ''
          : ` (or add ${className} to MEMBER_LEVEL in this script to map its members instead)`),
    )
  }
}

// Every group needs a section on both pages, so no entry is silently left out.
for (const page of ['guide/api-mapping.md', 'ja/guide/api-mapping.md']) {
  const path = join(root, 'website', page)
  const text = existsSync(path) ? readFileSync(path, 'utf8') : ''
  for (const group of mapping.groups) {
    if (!new RegExp(`<ApiMapping\\s+group="${group.id}"`).test(text)) {
      fail(`website/${page}: missing <ApiMapping group="${group.id}" />`)
    }
  }
}

if (errors.length > 0) {
  console.error(
    `api-mapping check failed (${errors.length}):\n` + errors.map((e) => `  - ${e}`).join('\n'),
  )
  console.error('\nFix website/data/api-mapping.json.')
  process.exit(1)
}
console.log(`api-mapping OK: ${mapping.entries.length} entries, ${dartApi.size} Dart symbols`)
