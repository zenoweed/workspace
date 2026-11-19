# ws: workspace manager

One folder per project, opened in your editor with a single command. `ws` creates, finds, opens and tidies project workspaces under `~/Documents/workspaces`, with an fzf picker sorted by most recently used.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/zenoweed/workspace/main/install.sh | sh
```

This puts the script at `~/.local/bin/ws` (set `WS_BIN` to choose another folder). Or install by hand:

```bash
curl -fsSL https://raw.githubusercontent.com/zenoweed/workspace/main/workspace.sh -o ~/.local/bin/ws
chmod +x ~/.local/bin/ws
```

**Needs:** Linux with bash and GNU coreutils. Optional: [fzf](https://github.com/junegunn/fzf) for the interactive picker (without it you type the name), `tree` for `ws tree`, and VS Code as the default editor (change it in the config).

## Usage

```bash
ws                      # list workspaces, most recently used first
ws create my-project    # create and open a workspace
ws open                 # pick one with fzf and open it
ws search terraform eks # rank workspaces by keyword hits
```

### Commands

| Command | What it does |
| --- | --- |
| `create [NAME]` | Create a workspace (with `src/`, `docs/`, `tests/` and a README) and open it |
| `open [NAME]` | Open a workspace in your editor; with no name, pick one with fzf |
| `list`, `ls` | List workspaces, most recently used first, with "2h ago"-style times |
| `delete`, `rm [NAME]` | Delete a workspace (asks to confirm) |
| `rename`, `mv [OLD] [NEW]` | Rename a workspace |
| `clone`, `cp [FROM] [TO]` | Copy a workspace |
| `tree [NAME]` | Show a workspace's folder structure |
| `info [NAME]` | Show path, size, and file and folder counts |
| `recent` | Show the last 10 workspaces opened |
| `search KEYWORDS...` | Search workspace names and file contents. Ranks by how many of the keywords matched, then total hits, and shows a per-keyword breakdown. Skips `.git`, `node_modules`, virtualenvs, build output and similar. |
| `help` | Show help |

Any command that takes a name lets you pick from a list when you leave the name out.

### Templates

| Command | What it does |
| --- | --- |
| `template create [NAME]` | Save the current directory as a template |
| `template list` | List templates |
| `template use TEMPLATE WORKSPACE` | Create a workspace from a template |
| `template delete NAME` | Delete a template |

### Options

Put options before the command, e.g. `ws --no-open create scratch`.

| Option | What it does |
| --- | --- |
| `--editor CMD` | Use a different editor for this run |
| `--no-open` | Don't open the workspace after `create` |
| `--no-close` | Keep the terminal open after opening a workspace |

## Configuration

`~/.workspace_config` is created on first run and read as shell variables:

```bash
editor=code             # command used to open a workspace
auto_open=true          # open new workspaces right after create
close_terminal=false    # close the terminal after opening a workspace in the editor
# base_path=$HOME/Documents/workspaces             # where workspaces live
# templates_path=$HOME/Documents/workspace-templates
```

`close_terminal=true` is handy when you launch `ws open` from a terminal you only opened to pick a project: once the editor opens, the terminal closes itself.
