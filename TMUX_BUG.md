# tmux copy-mode crash on macOS (Apple Silicon)

## Status: unfixed upstream, mitigation reverted on purpose (2026-06-24)

setmeup **no longer ships the copy-mode workaround.** The mitigation made the
crash deterministic but cost mouse scroll and mouse copy-paste in plain shell
panes, which is worse day-to-day than the intermittent crash. So the
full-featured (crash-prone) tmux config is back: `mouse on`, full
`history-limit`, `bind Escape copy-mode`, default mouse wheel/drag → copy-mode.

If the crash becomes intolerable, see **"Getting the crash gone again"** below —
but read **"Why this is hard"** first, because the obvious fixes do not work.

## Symptom

The entire tmux **server** dies with `Abort trap: 6` (SIGABRT), taking **every
session** with it. It looks random but always happens while scrolling up,
drag-selecting, or otherwise entering copy-mode.

Crash reports land in `~/Library/Logs/DiagnosticReports/tmux-*.ips`. Two known
variants of the abort:

- libmalloc `POINTER_BEING_FREED_WAS_NOT_ALLOCATED`, or
- `__assert_rtn` from `grid_free_line`.

Every captured crash has the same shape: entering copy-mode clones the pane's
grid, and a double-free in that path aborts the process.

```
abort  <- SIGABRT
grid_free_line / grid_clear_lines / grid_trim_history   <- the double-free
screen_reinit
window_copy_clone_screen   <- cloning the pane screen...
window_copy_init
window_pane_set_mode
cmd_copy_mode_exec         <- ...when entering COPY MODE
```

## Root cause (corrected)

This is an **upstream tmux bug**, not a setmeup/sesh/tmuxinator problem:
[tmux/tmux#5267](https://github.com/tmux/tmux/issues/5267) is the current live
tracker (opened 2026-06-23), succeeding
[#4962](https://github.com/tmux/tmux/issues/4962) (which nicm closed "for the
moment" on 2026-06-18). Related: [#4777](https://github.com/tmux/tmux/issues/4777),
[#4556](https://github.com/tmux/tmux/issues/4556).

The earlier write-up in this file framed it as a recent copy-mode regression
that a newer tmux would fix. **That was wrong.** What the research actually
found:

- **It is a latent double-free** in `grid_trim_history()` / `grid_free_line`,
  reached via the grid clone on copy-mode entry. A byte-for-byte diff of
  `grid.c` across release tags shows the buggy code is **identical and present
  unchanged from tmux 2.8 through 3.6b and current `master`/`3.7-rc`.** There is
  **no known-good release to downgrade or pin to** — every version contains it.
- **It only aborts on macOS** because Apple's *hardened libmalloc* treats the
  aliased (non-NULL) double-free as fatal. Linux glibc usually tolerates the
  same bad `free()` silently, which is why the same config never crashes on
  Linux.
- **Crash likelihood rises with session age and memory use.** Long-lived
  Apple-silicon sessions accumulate the stale pointers, so it bites more the
  longer tmux has been up.
- Unconfirmed correlation: the trigger seems more frequent with
  **tmux-resurrect restore + `@resurrect-capture-pane-contents on`**. This repo
  does **not** set `@resurrect-capture-pane-contents` (it defaults off), but it
  does use resurrect + `@continuum-restore 'on'`. Not maintainer-confirmed.

As of **2026-06-24** the maintainer has **not** declared it fixed; he is still
asking for an `lldb`/`gdb` backtrace from a debug build
(`--enable-debug --disable-optimizations`). The `#4777` partial fix
(`75828880a`) does not catch this crash — the freed pointer is a non-NULL
aliased double-free, not a free-of-NULL.

## Why switching terminal emulators does NOT help

The abort happens **inside the tmux server process**, which runs independently
of whatever terminal client is attached. The terminal emulator does not own
tmux's grid memory. Both Ghostty and iTerm2 (and Terminal.app, WezTerm, …) run
on the same macOS hardened libmalloc, so the same bad `free()` aborts the same
way regardless of the terminal. **Switching Ghostty → iTerm2 will not avoid the
crash.** (It is still a fine thing to try as a quick experiment — just don't
expect it to stop the aborts.)

## Why this is hard / what does NOT fix it today

| Attempt | Why it fails today |
|---|---|
| Downgrade / pin an older tmux release (3.4, 3.3a, …) | Same buggy `grid.c` in every release back to 2.8; you'd only lose 3.6 scrollbars + security fixes. |
| `brew install --HEAD` / 3.7-rc | `master` and `3.7-rc` still reproduce (#5267); a moving target with no real fix landed. |
| Patched Homebrew formula / private tap | No correct upstream patch exists to carry; hand-patching a libmalloc double-free you don't fully understand just relocates the crash. |

## Getting the crash gone again (if you decide to)

None of these are applied right now. Pick one only if the crash outweighs the
convenience of full mouse scroll + copy.

1. **Config-only, keep tmux — "let the terminal own scrollback."** `set -g mouse
   off` + disable tmux's alternate screen
   (`set -as terminal-overrides ',xterm-ghostty:smcup@:rmcup@'`) + a large
   terminal `scrollback-limit`. The terminal's native trackpad scroll +
   drag-select + Cmd-C/Cmd-V then work and tmux copy-mode is never entered.
   Deterministic. Trade-offs: loses tmux *mouse* pane-resize/click-select, and
   native scroll/selection acts on the whole window (zoom a pane with
   `prefix-z` first for clean per-pane scroll in side-by-side splits).
2. **Re-apply the copy-mode-disable mitigation** that this commit reverted. It
   lived in two commits — `b7399f5` ("tmux bug #4962 workaround", the `prefix-S`
   scrollback-to-vim dump) and `46b22c3` ("disable copy-mode entry", the
   wheel/drag/scrollbar re-bindings + history cap + removal of
   `bind Escape copy-mode`). `git show`/`git revert` those to restore it.
   Crash-proof, but no mouse scroll and no in-pane mouse copy.
3. **Switch multiplexer to Zellij.** Different (Rust) codebase, no libmalloc
   double-free; native scroll/copy + built-in session resurrection. Costs a
   config rewrite and loses tmuxinator / tmux-resurrect / vim-tmux-navigator
   (sesh survives, multiplexer-agnostic).

## If it crashes, help upstream

Because the abort kills the whole server, `@continuum-restore 'on'` should bring
your sessions back on the next tmux start. To move the upstream fix along:

1. Grab the latest crash report from `~/Library/Logs/DiagnosticReports/tmux-*.ips`.
2. Note which abort variant it is (libmalloc `POINTER_BEING_FREED…` vs
   `__assert_rtn` from `grid_free_line`).
3. Ideally reproduce under a debug build
   (`--enable-debug --disable-optimizations`) and capture an `lldb` backtrace —
   that is exactly what the maintainer is asking for.
4. Post it to [tmux/tmux#5267](https://github.com/tmux/tmux/issues/5267)
   (the live tracker — **not** the closed #4962, and explicitly not against
   3.6b).
