# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| < 1.1   | :x:                |

Only the latest release (distributed as a signed and notarized DMG, and via
Sparkle updates) receives security fixes. Please update before reporting.

## Reporting a Vulnerability

**Do not open a public issue for security reports.**

Report privately via [GitHub Security Advisories](https://github.com/ikoshura/MacRMB/security/advisories/new)
or by email to the maintainer. Please include:

- MacRMB version (`About` pane) and macOS version
- Steps to reproduce
- What you expected vs. what happened

You can expect an initial response within 7 days. Once a fix is ready it
ships as a normal Sparkle/DMG release and is credited in the release notes
(unless you prefer to stay anonymous).

## Scope Notes

MacRMB legitimately requires sensitive permissions to do its job, so please
keep this in mind when assessing reports:

- **Accessibility + Input Monitoring + keystroke posting** are the app's core
  function (keyboard simulation for camera panning). They are requested at
  first launch and explained in the README. This is by design, not a bug.
- **The undocumented `SetsCursorInBackground` WindowServer property** is used
  for cursor hiding (same as upstream RMB and the MIT-licensed
  raycast-mouse-cursor-toggle reference). If Apple removes it, the app fails
  closed with an `RMB-CUR-*` error and the cursor stays visible.
- Out of scope: reports that the app *requests* these permissions, or that it
  is not sandboxed / not Mac App Store eligible (both intentional and
  documented).
