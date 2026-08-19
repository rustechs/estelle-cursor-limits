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
| `sysctl/99-estelle-cursor-inotify.conf` | Optional system limit for `fs.inotify.max_user_watches` (from `CURSOR_INOTIFY_MIN_WATCHES`, default 524288) |

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
sysctl/99-estelle-cursor-inotify.conf   optional inotify watch ceiling
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

When `fs.inotify.max_user_watches` is below the configured minimum (default
**524288**), install may prompt once via **PolicyKit** (`pkexec`) to install
`/etc/sysctl.d/99-estelle-cursor-inotify.conf` with that limit. Override the
value in `~/.config/cursor-limits/env` via `CURSOR_INOTIFY_MIN_WATCHES=…`
(both install threshold and rendered drop-in). An existing custom drop-in at
that path is never overwritten. To apply a higher ceiling after a prior install,
remove the drop-in (`REMOVE_INOTIFY_SYSCTL=1 uninstall.sh`) and re-run install.

Optional shell alias (see `contrib/bashrc.snippet`):

```bash
alias agent-unlimited=agent-raw
```

Replace an existing desktop launcher or `~/.cursorignore`:

```bash
FORCE_CURSOR_DESKTOP=1 FORCE_CURSORIGNORE=1 ~/git/estelle-cursor-limits/install.sh
```

Skip the sysctl step (CI, containers, or manual tuning):

```bash
SKIP_INOTIFY_SYSCTL=1 ~/git/estelle-cursor-limits/install.sh
```

## Check

```bash
systemctl --user status cursor.slice
systemctl --user show cursor.slice | grep -E '^(MemoryMax|CPUQuota|TasksMax)='
cursor-cgwrap --help
type agent agent-raw
sysctl fs.inotify.max_user_watches
```

## Uninstall

```bash
~/git/estelle-cursor-limits/uninstall.sh
# Optional: REMOVE_CURSOR_DESKTOP=1 REMOVE_CURSORIGNORE=1 REMOVE_INOTIFY_SYSCTL=1 uninstall.sh
```

## Tests / CI

```bash
./tests/run
```

ShellCheck on bash scripts; install smoke test into a temporary `$HOME`.
