# Sesh Config Design

## Goal

Add the current shared `sesh` configuration to `setmeup` so chezmoi manages `~/.config/sesh/sesh.toml` on fresh machine setup.

## Scope

- Manage `~/.config/sesh/sesh.toml` from `home/dot_config/sesh/sesh.toml`
- Preserve the schema line and the shared preview/session entries
- Exclude the machine-specific `FileRunner` session
- Add tests that verify the managed file exists and contains the shared entries

## Approach

Use a plain managed file rather than a template. The current shared config does not need user-specific interpolation, and keeping it static is the smallest change.

The managed file will contain:

- `default_session.preview_command`
- `zsh config` session
- `tmux config` session
- `sesh config` session

It will not contain placeholder or example project sessions, because they would create a broken or misleading default config.

## Testing

Add dotfile tests that assert:

- `~/.config/sesh/sesh.toml` exists
- it contains the shared preview command
- it contains the three shared session names

Run the relevant BATS test file after implementation.
