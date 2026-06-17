# Zsh chpwd hooks: auto-ls and auto-venv

**Date:** 2026-06-17
**Status:** Approved

## Goal

Add two zsh `chpwd` hooks to the managed zsh config so that, on every directory
change:

1. The directory contents are listed (`ls`).
2. A Python virtualenv is automatically sourced if one exists, and automatically
   deactivated when leaving its directory tree.

## Location

A new section in `home/dot_config/setmeup/zshrc.tmpl`, placed after the aliases
block and before the auto-update section. The section uses zsh's native hook
mechanism via `autoload -Uz add-zsh-hook`.

## Hook 1 — auto-ls on cd

```zsh
_setmeup_chpwd_ls() { ls; }
add-zsh-hook chpwd _setmeup_chpwd_ls
```

Plain `ls` is used for portability across the macOS and Linux targets the repo
supports.

## Hook 2 — auto-source / auto-deactivate venv

```zsh
_setmeup_chpwd_venv() {
    # Leave the tree of a venv WE activated -> deactivate
    if [[ -n "$_SETMEUP_VENV_ROOT" && "$PWD" != "$_SETMEUP_VENV_ROOT"* ]]; then
        deactivate 2>/dev/null
        unset _SETMEUP_VENV_ROOT
    fi
    # Activate .venv (then venv) if present and nothing is active
    if [[ -z "$VIRTUAL_ENV" ]]; then
        for _venv in .venv venv; do
            if [[ -f "$PWD/$_venv/bin/activate" ]]; then
                source "$PWD/$_venv/bin/activate"
                _SETMEUP_VENV_ROOT="$PWD"
                break
            fi
        done
        unset _venv
    fi
}
add-zsh-hook chpwd _setmeup_chpwd_venv
```

### Behaviour and safety

- **Venv names:** `.venv` is checked first, then `venv`.
- **Auto-deactivate:** when you `cd` out of the subtree where an auto-sourced
  venv lives, it is deactivated. Only venvs activated by this hook are tracked
  (via `_SETMEUP_VENV_ROOT`), so a venv you activated by hand is never killed.
- **No stomping:** activation only happens when `$VIRTUAL_ENV` is empty, so the
  hook will not override a manually-activated venv when you `cd` into a project
  that contains a `.venv`.

## Testing (TDD)

Add `assert_file_contains` tests to `tests/dotfiles.bats`, written and confirmed
failing before implementation. Assertions cover:

- Registration of both hooks (`add-zsh-hook chpwd _setmeup_chpwd_ls`,
  `add-zsh-hook chpwd _setmeup_chpwd_venv`).
- `autoload -Uz add-zsh-hook`.
- Both venv directory names (`.venv`, `venv`).
- The `deactivate` call.
- The `$VIRTUAL_ENV` activation guard.

All testing runs in Docker per the project's testing rules.
