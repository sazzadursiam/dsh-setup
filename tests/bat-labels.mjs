// Static check: every label a batch file jumps to actually exists in that file.
//
//   node tests/bat-labels.mjs
//
// cmd.exe has no syntax check the way `bash -n` is one, and a `goto :failed`
// whose `:failed` was renamed or deleted only shows up when that path runs -
// which for setup.bat and update.bat is on somebody's fresh machine. This does
// not prove the scripts are right, only that no jump lands nowhere.
import { readdirSync, readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const root = join(dirname(fileURLToPath(import.meta.url)), '..')
const dirs = [root, join(root, 'tests')]
const files = dirs.flatMap((dir) =>
	readdirSync(dir)
		.filter((name) => name.toLowerCase().endsWith('.bat'))
		.map((name) => join(dir, name)),
)

let problems = 0
for (const file of files) {
	const lines = readFileSync(file, 'utf8').split(/\r?\n/)
	const defined = new Set()
	const jumps = []
	lines.forEach((line, i) => {
		const text = line.trim()
		if (/^(rem\b|::)/i.test(text)) return
		const label = text.match(/^:([A-Za-z0-9_.-]+)/)
		if (label) defined.add(label[1].toLowerCase())
		// `goto :x`, `goto x` and `call :x` - `:eof` is built in.
		for (const m of text.matchAll(/\b(?:goto|call)\s+:?([A-Za-z0-9_.-]+)/gi)) {
			const isCall = /^call/i.test(m[0])
			if (isCall && !m[0].includes(':')) continue // `call other.bat`, not a label
			if (m[1].toLowerCase() === 'eof') continue
			jumps.push({ name: m[1].toLowerCase(), line: i + 1 })
		}
	})
	const missing = jumps.filter((jump) => !defined.has(jump.name))
	for (const jump of missing) {
		console.error(`${file}:${jump.line}: jumps to :${jump.name}, which is not defined`)
	}
	problems += missing.length
	if (!missing.length) {
		console.log(`  [ OK ] ${file.slice(root.length + 1)}: ${jumps.length} jump(s), ${defined.size} label(s)`)
	}
}

if (problems) {
	console.error(`\n${problems} jump(s) to a missing label`)
	process.exit(1)
}
console.log('\nall batch-file jumps resolve')
