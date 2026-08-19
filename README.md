# estelle-cursor-limits

Host overlay for **estelle** (dev laptop): cap Cursor IDE and CLI agent CPU/RAM
with a shared systemd user slice so ripgrep storms and agent work cannot consume
the whole machine.

Complements the global Cursor rule in
[`cursor-rules`](https://github.com/rustechs/cursor-rules)
(`cursor-resource-limits.mdc`).

## Behavior

| Component | Role |
|---|---|
| `cursor.slice` | Shared cgroup: **700% CPU** (~7/8 cores), **18G** hard / **14G** soft RAM, **768** tasks |
| `cursor-cgwrap` | Launches Cursor or `agent-raw` inside the slice via `systemd-run` |
| `agent` | Wrapper → `cursor-cgwrap agent` (default terminal entrypoint) |
| `agent-raw` | Symlink to real `cursor-agent` (escape hatch) |
| `cursor.desktop` | User override so the app menu launches through `cursor-cgwrap` |

Default limits target an 8-core / 32 GiB box with browser + VM always running.

**Where limits live:**

| Goal | Edit |
|---|---|
| Aggregate cap for all Cursor scopes | `~/.config/systemd/user/cursor.slice`, then `systemctl --user daemon-reload` |
| Default per-launch ceiling (installed copy) | `bin/cursor-cgwrap` defaults / reinstall |
| One-shot override | env vars below |

Override per launch:

```bash
CURSOR_MEMORY_MAX=12G CURSOR_CPU_QUOTA=500% cursor-cgwrap cursor .
```

## Layout

```text
bin/cursor-cgwrap          launcher under cursor.slice
bin/agent                  wrapped agent entrypoint
systemd/cursor.slice       user slice unit
etc/cursor-limits.env      desktop extra args (Wayland on estelle)
etc/cursorignore.example   optional ~/.cursorignore template
applications/cursor.desktop   @HOME@ / @EXTRA_ARGS@ template
contrib/bashrc.snippet     agent-unlimited alias
```

Installed paths: `~/.local/bin/`, `~/.config/systemd/user/`, optional
`~/.local/share/applications/cursor.desktop`, `~/.cursorignore`.

## Requirements

- Linux, systemd user session, `systemd-run`
- Cursor IDE at `/usr/share/cursor/cursor` (override with `CURSOR_BIN`)
- Cursor CLI / `cursor-agent` for `agent-raw` symlink (install warns if missing)

## Install

```bash
git clone git@github.com:rustechs/estelle-cursor-limits.git ~/git/estelle-cursor-limits
~/git/estelle-cursor-limits/install.sh
```

Optional shell alias (see `contrib/bashrc.snippet`):

```bash
alias agent-unlimited=agent-raw
```

Replace an existing desktop launcher or `~/.cursorignore`:

```bash
FORCE_CURSOR_DESKTOP=1 FORCE_CURSORIGNORE=1 ~/git/estelle-cursor-limits/install.sh
```

## Check

```bash
systemctl --user status cursor.slice
systemctl --user show cursor.slice | grep -E '^(MemoryMax|CPUQuota|TasksMax)='
cursor-cgwrap --help
type agent agent-raw
```

## Uninstall

```bash
~/git/estelle-cursor-limits/uninstall.sh
# Optional: REMOVE_CURSOR_DESKTOP=1 REMOVE_CURSORIGNORE=1 uninstall.sh
```

## Tests / CI

```bash
./tests/run
```

ShellCheck on bash scripts; install smoke test into a temporary `$HOME`.
