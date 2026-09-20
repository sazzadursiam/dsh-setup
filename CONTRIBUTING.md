# Contributing

Thanks for helping. This repo is install scripts, a few dsh plugins, and the
shared agent rules — no build step, no dependencies to install. Most changes are
a script edit plus a doc edit.

## Before you start

- **Bug or something not working?** Run `verify.bat` (Windows) or `./verify.sh`
  (macOS / Linux) first and put its output in the issue. It says which piece is
  missing, and it is what the bug-report form asks for.
- **Bigger change** (a new script, a new plugin, a change to the shared rules)?
  Open an issue first so we agree on the shape before you write it.
- **Security problem?** Do not open an issue. See [`SECURITY.md`](SECURITY.md).
- **Never paste tokens or keys.** Not in an issue, a PR, or a log. If you posted
  one by accident, revoke it — deleting the comment is not enough.

## Making a change

1. Fork the repo and branch from `master`.
2. Make the change. Keep it to one thing; a fix and a refactor are two PRs.
3. Run the checks below.
4. Add a line under `## [Unreleased]` in [`CHANGELOG.md`](CHANGELOG.md). Say what
   changed *and why* — the existing entries are the model.
5. Open a PR against `master`. `master` is protected: it needs a PR and a green
   CI run, and nothing is pushed to it directly.

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/)
as the history does: `feat: …`, `fix: …`, `chore: …`, with an optional scope,
e.g. `feat(figma-bridge): …`.

## Checks

CI runs these on Linux, macOS and Windows (shellcheck on Linux only). Run the
ones for your platform before you push.

```bash
# macOS / Linux
./tests/smoke.sh                                  # agents.sh + verify.sh
git ls-files '*.sh' | xargs shellcheck            # lint the shell scripts
node plugins/team-updater/tests/check.mjs
node plugins/figma-bridge/tests/check.mjs
```

```
:: Windows — Command Prompt
tests\smoke.bat
node plugins\team-updater\tests\check.mjs
node plugins\figma-bridge\tests\check.mjs
```

The smoke tests run against a throwaway `HOME`, so they never read or write your
real `~/.dsh`. They are not a substitute for running `setup` / `update` for real
when you change those.

## Conventions worth knowing

- **Every script has a `.sh` and a `.bat` twin.** If you change one, change the
  other, or say in the PR why they differ. (Linux has no Figma write path, since
  Figma has no Linux desktop app — that gap is deliberate.)
- **`.bat` files must be CRLF.** cmd.exe misparses labels and `goto` targets in
  LF-only files. `.gitattributes` handles it on checkout and CI fails if a `.bat`
  is not CRLF — so if it complains, check your editor is not converting them.
- **The shared rules live in `templates/`.** Edit `templates/core.md` or
  `templates/roles/*.md`; never edit a generated `~/.dsh/AGENTS.md`, it is
  overwritten on the next update.
- **Docs travel with code.** If a change alters what a user sees or types,
  update `README.md` and `SETUP.md` in the same PR. A doc that disagrees with
  the script is a bug.
- **Nothing machine-specific in the repo.** No absolute paths of your machine, no
  usernames, no `.claude/settings*.json` (they are git-ignored for that reason).

## Releases

Maintainer only. A release commit moves the `[Unreleased]` entries under a new
version heading in `CHANGELOG.md`, bumps [`VERSION`](VERSION) to match, and is
tagged `vX.Y.Z`. CI fails if `VERSION` and the newest release heading in
`CHANGELOG.md` disagree, so the bump cannot be forgotten. `DSH_VERSION` is a separate pin: it is the dsh version this
setup installs, and it changes only when the maintainer bumps it.

## License

By contributing you agree your work is released under the [MIT license](LICENSE).
