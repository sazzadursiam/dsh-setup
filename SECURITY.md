# Security policy

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Use GitHub's private reporting instead: on this repo, go to **Security →
Report a vulnerability**. Only the maintainer sees it.

Include what you found, how to reproduce it, and which script or plugin it is in.
This is a one-maintainer project, so replies are best-effort, but a report is read
and answered.

## What counts

This repo installs software and handles credentials on a developer's machine, so
the interesting problems are:

- an install or update script that runs something it should not, or fetches from
  somewhere unexpected;
- a plugin (`plugins/team-updater`, `plugins/figma-bridge`) that leaks, logs or
  mis-stores the Figma token or a provider key;
- the auto-update path pulling or running code the user did not agree to;
- a file in this repo that contains a real secret.

## What is known and documented

These are the way dsh and this setup work, not vulnerabilities — but you should
know them:

- dsh writes provider API keys **in plain text** to `~/.dsh/.credentials.yaml`.
- The Figma token set under Settings → General is written **in plain text** to
  `~/.dsh/profiles/web/node_modules/dsh-figma-bridge/cordis.patch.yml`.
- Neither file, nor the `.dsh/` folder, should be copied to another machine,
  committed, or synced. Details are in `SETUP.md`, Part 1 Step 4.

## If a token was exposed

Revoke it first, then clean up. For a Figma token: figma.com → Settings →
Security, revoke it and issue a new one. Deleting a committed file does not
remove it from git history.

## Supported versions

Only the latest release on `master`. Fixes are not backported.
