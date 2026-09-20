// Static check for the Markdown docs: links between them (and to files in the
// repo) must resolve, and `#anchor`s must match a heading.
//
//   node tests/md-links.mjs
//
// Checks, offline and without dependencies:
//   1. [text](relative/path)        - the file or folder exists
//   2. [text](file.md#anchor)       - the anchor is a heading in that file
//   3. [text](#anchor)              - the anchor is a heading in this file
//   4. `plugins/x/y.js`             - a code span that names a repo path under
//                                     plugins/, templates/, tests/ or .github/
//                                     exists (CHANGELOG.md is skipped: it is
//                                     history and names files that are gone)
// External http(s) links are counted but not fetched - a network check would make
// CI fail for reasons that are not this repo's.
//
// Links inside fenced code blocks and code spans are ignored: they are examples.
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs'
import { dirname, join, relative, resolve, sep } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const SKIP_DIRS = new Set(['node_modules', '.git'])

// Paths a doc names on purpose although the file is gone - they describe the
// past. Keep this short, and say why each is here.
const HISTORICAL = new Map([
	// Part 10 tells v0.3.x users what their projects held before v0.4.0 removed it.
	['SETUP.md', new Set(['templates/AGENTS.md'])],
])

const walk = (dir) =>
	readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
		if (SKIP_DIRS.has(entry.name)) return []
		const full = join(dir, entry.name)
		if (entry.isDirectory()) return walk(full)
		return entry.name.toLowerCase().endsWith('.md') ? [full] : []
	})

// What GitHub turns a heading into: lower-case, drop everything that is not a
// letter, number, space, hyphen or underscore, then spaces become hyphens.
// Repeated headings get -1, -2, ... appended.
const slugify = (heading) =>
	heading
		.replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1') // [text](url) -> text
		.replace(/[`*_~]+/g, (m) => (m.includes('_') ? m : '')) // keep underscores, drop emphasis marks
		.toLowerCase()
		.replace(/[^\p{L}\p{N}\p{M} _-]/gu, '')
		.trim()
		.replace(/ /g, '-')

const parsed = new Map() // file -> { anchors:Set, links:[{target,line}], paths:[{path,line}] }

const parse = (file) => {
	if (parsed.has(file)) return parsed.get(file)
	const anchors = new Set()
	const seen = new Map()
	const links = []
	const paths = []
	let fence = null // the opening marker of the current fenced block, if inside one

	readFileSync(file, 'utf8')
		.split(/\r?\n/)
		.forEach((line, i) => {
			const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/)
			if (marker) {
				if (!fence) fence = marker[1]
				else if (marker[1][0] === fence[0] && marker[1].length >= fence.length) fence = null
				return
			}
			if (fence) return

			const heading = line.match(/^#{1,6}\s+(.*?)\s*#*\s*$/)
			if (heading) {
				const base = slugify(heading[1])
				const n = seen.get(base) ?? 0
				seen.set(base, n + 1)
				anchors.add(n === 0 ? base : `${base}-${n}`)
			}
			for (const m of line.matchAll(/<a\s+[^>]*?(?:id|name)="([^"]+)"/gi)) anchors.add(m[1])

			// Code spans first: collect repo paths from them, then blank them so a
			// `[x](y)` shown as an example is not read as a link.
			const noCode = line.replace(/(`+)([^`]|[^`].*?[^`])\1(?!`)/g, (_, __, inner) => {
				paths.push({ path: inner.trim(), line: i + 1 })
				return ' '.repeat(inner.length + 2)
			})
			for (const m of noCode.matchAll(/!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)/g)) {
				links.push({ target: m[1], line: i + 1 })
			}
		})

	const result = { anchors, links, paths }
	parsed.set(file, result)
	return result
}

const files = walk(root).sort()
const rel = (file) => relative(root, file).split(sep).join('/')
const problems = []
let external = 0
let checked = 0

for (const file of files) {
	const { links, paths } = parse(file)

	for (const { target, line } of links) {
		if (/^[a-z][a-z0-9+.-]*:/i.test(target)) {
			external++ // http(s), mailto, ...
			continue
		}
		checked++
		const hash = target.indexOf('#')
		const pathPart = decodeURIComponent(hash === -1 ? target : target.slice(0, hash))
		const fragment = hash === -1 ? '' : decodeURIComponent(target.slice(hash + 1))
		const dest = pathPart === '' ? file : resolve(dirname(file), pathPart.split('?')[0])

		if (!existsSync(dest)) {
			problems.push(`${rel(file)}:${line}: ${target} - ${rel(dest)} does not exist`)
			continue
		}
		if (!fragment || /^L\d+/.test(fragment)) continue // no anchor, or a GitHub line anchor
		if (!statSync(dest).isFile() || !dest.toLowerCase().endsWith('.md')) continue
		if (!parse(dest).anchors.has(fragment.toLowerCase())) {
			problems.push(`${rel(file)}:${line}: ${target} - no heading "#${fragment}" in ${rel(dest)}`)
		}
	}

	if (rel(file) === 'CHANGELOG.md') continue
	for (const { path, line } of paths) {
		if (!/^(?:plugins|templates|tests|\.github)\/[A-Za-z0-9._/-]+$/.test(path)) continue
		if (HISTORICAL.get(rel(file))?.has(path)) continue
		checked++
		if (!existsSync(resolve(root, path))) {
			problems.push(`${rel(file)}:${line}: \`${path}\` is named as a file in this repo, but it does not exist`)
		}
	}
}

console.log(`  ${files.length} Markdown files, ${checked} internal link(s)/path(s) checked, ${external} external skipped`)
if (problems.length) {
	console.error(`\n${problems.join('\n')}\n\n${problems.length} broken link(s) or path(s)`)
	process.exit(1)
}
console.log('\nall internal Markdown links resolve')
