# tmux copy-mode crash on macOS (Apple Silicon)

## Symptom

The entire tmux **server** dies with `Abort trap: 6` (SIGABRT), taking **every
session** with it. It looks random but always happens while scrolling up,
drag-selecting, or otherwise entering copy-mode.

Crash reports land in `~/Library/Logs/DiagnosticReports/tmux-*.ips`.

## Root cause

This is an **upstream tmux bug**, not a setmeup/sesh/tmuxinator problem:
[tmux/tmux#4777](https://github.com/tmux/tmux/issues/4777) (related:
[#4962](https://github.com/tmux/tmux/issues/4962),
[#4556](https://github.com/tmux/tmux/issues/4556)).

Entering copy-mode clones the pane's grid, and a double-free in that clone path
aborts the process. Every captured crash has the identical stack:

```
abort  <- SIGABRT "pointer being freed was not allocated"
___BUG_IN_CLIENT_OF_LIBMALLOC_POINTER_BEING_FREED_WAS_NOT_ALLOCATED
grid_free_line
grid_clear_lines
screen_reinit
window_copy_clone_screen   <- cloning the pane screen...
window_copy_init
window_pane_set_mode
cmd_copy_mode_exec         <- ...when entering COPY MODE
```

It affects tmux **3.5a, 3.6a, 3.6b, and current `master` / `3.7-rc`** on macOS
arm64. A first round of fixes landed 2026-06-07 (commits `110909d2e` /
`42f3e7f`) and shipped in the `3.7-rc` tag (2026-06-12) and master; on that
basis upstream closed [#4962](https://github.com/tmux/tmux/issues/4962) "for the
moment" on 2026-06-18, asking for recurrence reports against `master` or
`3.7-rc` (explicitly *not* 3.6b).

**The fix is incomplete.** The crash still reproduces on a Homebrew `--HEAD`
build pinned to `1dd2589` (master, 2026-06-17 — confirmed to contain the
`42f3e7f` fix), so there is no released or pre-release tmux that reliably avoids
it yet. The crash likelihood rises with session age and memory use. Until a
confirmed fix ships, keep the mitigation below; report fresh crashes upstream
with the backtrace from `~/Library/Logs/DiagnosticReports/tmux-*.ips`, noting
whether the abort is the libmalloc `POINTER_BEING_FREED_WAS_NOT_ALLOCATED` or an
`__assert_rtn` from `grid_free_line` (the two known variants).

## Why it kept crashing despite the earlier workaround

The original mitigation only replaced **one** manual route into copy-mode
(`prefix-S`). But `setw -g mouse on` means tmux's default bindings send you into
copy-mode constantly without any keypress:

| Default binding | Action | Result |
|---|---|---|
| `WheelUpPane` | trackpad / wheel scroll-up | `copy-mode -e` → crash path |
| `MouseDrag1Pane` | drag to select text | `copy-mode -M` |
| `DoubleClick1Pane` / `TripleClick1Pane` | word / line select | `copy-mode -H` |
| `MouseDrag1ScrollbarSlider`, `MouseDown1Scrollbar*` | the 3.6 scrollbars | `copy-mode -S/-u/-d` |
| `MouseDown3Pane` menu → Search/Copy | right-click menu | `copy-mode` |

So a normal trackpad scroll was enough to lose every session.

## Mitigation applied (`home/dot_tmux.conf`)

Deterministic: if copy-mode is never entered, the crashing clone never runs.

1. **Every automatic mouse path is re-pointed away from copy-mode** (block at
   the end of the config, placed after TPM so no plugin re-binds it). The events
   are still forwarded (`send-keys -M`) to mouse-aware fullscreen apps, so
   scrolling still works inside vim / less / htop. In a plain shell pane the
   wheel/drag now does nothing instead of entering copy-mode.
2. **`bind Escape copy-mode` was removed** — it was the last explicit key into
   the crash.
3. **`history-limit` lowered** 1,000,000 → 50,000. With copy-mode disabled this
   no longer affects the crash; it is now just memory hygiene and the cap on how
   much `prefix-S` can dump. Raise it freely if you want deeper scrollback.

### How to read scrollback now

`prefix-S` (capital S) dumps the current pane's scrollback to a tmpfile and
opens it read-only in vim — no copy-mode, no crash. Search/yank there instead.

## Reverting when upstream fixes it

When [#4777](https://github.com/tmux/tmux/issues/4777) is fixed and the fixed
tmux is installed:

1. Delete the `--- Disable copy-mode entry ---` block at the end of
   `home/dot_tmux.conf`.
2. Restore `bind Escape copy-mode` in the `--- Copy mode ---` section (optional).
3. Optionally raise `history-limit` back up.
4. Drop the corresponding tests in `tests/dotfiles.bats` and this file.
