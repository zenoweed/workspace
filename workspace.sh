#!/bin/bash

# Workspace Manager - Enhanced Version + FZF selection
script_name="workspace"
# Defaults; base_path and templates_path can be overridden in the config file.
base_path="$HOME/Documents/workspaces"
templates_path="$HOME/Documents/workspace-templates"
config_file="$HOME/.workspace_config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo -e "\n${CYAN}Workspace Manager - Easy project workspace management${NC}"
    echo -e "\n${YELLOW}Usage:${NC} $(basename "$0") [OPTIONS] [COMMAND]"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${GREEN}create${NC} [NAME]        Create new workspace"
    echo -e "  ${GREEN}open${NC} [NAME]          Open existing workspace"
    echo -e "  ${GREEN}list${NC}                List all workspaces"
    echo -e "  ${GREEN}delete${NC} [NAME]        Delete workspace"
    echo -e "  ${GREEN}rename${NC} [OLD] [NEW]   Rename workspace"
    echo -e "  ${GREEN}clone${NC} [FROM] [TO]    Clone workspace"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  ${GREEN}--editor${NC} [CMD]       Override editor for this run"
    echo -e "  ${GREEN}--no-open${NC}            Don't open after create"
    echo -e "  ${GREEN}--no-close${NC}           Keep the terminal open after opening"
    echo
    echo -e "${YELLOW}Template Commands:${NC}"
    echo -e "  ${GREEN}template create${NC} [NAME]"
    echo -e "  ${GREEN}template list${NC}"
    echo -e "  ${GREEN}template use${NC} [TEMPLATE] [WORKSPACE]"
    echo -e "  ${GREEN}template delete${NC} [NAME]"
    echo
    echo -e "${YELLOW}Utility Commands:${NC}"
    echo -e "  ${GREEN}tree${NC} [NAME]          Show workspace structure"
    echo -e "  ${GREEN}info${NC} [NAME]          Show workspace information"
    echo -e "  ${GREEN}recent${NC}               Show recently accessed workspaces"
    echo -e "  ${GREEN}search${NC} [KEYWORDS...] Rank workspaces by keyword hits"
    echo
    exit 0
}

# Initialization
init_workspace() {
    if [ ! -f "$config_file" ]; then
        echo "editor=code" > "$config_file"
        echo "auto_open=true" >> "$config_file"
        echo "close_terminal=false" >> "$config_file"
    fi
}

# Runs after init_workspace, so a base_path/templates_path set in the config
# is the one that gets created.
load_config() {
    [ -f "$config_file" ] && source "$config_file"
    EDITOR=${editor:-code}
    AUTO_OPEN=${auto_open:-true}
    CLOSE_TERMINAL=${close_terminal:-false}
    mkdir -p "$base_path" "$templates_path"
}

log_access() {
    local workspace="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$workspace" >> "$base_path/.access_log"
    tail -n 50 "$base_path/.access_log" > "$base_path/.temp" && mv "$base_path/.temp" "$base_path/.access_log"
}

# Last-used timestamp per workspace. .workspace_info is touched on every
# create/open, so its mtime is the real "last used" marker; fall back to the
# directory mtime for workspaces that predate it.
workspace_times() {
    local ws name stamp
    for ws in "$base_path"/*; do
        [ -d "$ws" ] || continue
        name=$(basename "$ws")
        if [ -f "$ws/.workspace_info" ]; then
            stamp=$(stat -c %Y "$ws/.workspace_info" 2>/dev/null)
        else
            stamp=$(stat -c %Y "$ws" 2>/dev/null)
        fi
        printf '%s\t%s\n' "${stamp:-0}" "$name"
    done | sort -rn
}

relative_time() {
    local diff=$(( $(date +%s) - ${1:-0} ))
    if   [ "$diff" -lt 60 ];      then echo "just now"
    elif [ "$diff" -lt 3600 ];    then echo "$((diff / 60))m ago"
    elif [ "$diff" -lt 86400 ];   then echo "$((diff / 3600))h ago"
    elif [ "$diff" -lt 2592000 ]; then echo "$((diff / 86400))d ago"
    else                               echo "$((diff / 2592000))mo ago"
    fi
}

# ============================================================================
# FZF WORKSPACE PICKER
# ============================================================================
pick_workspace() {
    if ! command -v fzf >/dev/null 2>&1; then
        echo -e "${RED}fzf is not installed. Falling back to manual selection.${NC}"
        list_workspaces
        read -p "Enter workspace name: " name
        echo "$name"
        return
    fi

    local choice
    choice=$(workspace_times \
        | while IFS=$'\t' read -r stamp name; do
              printf '%s\t%s\n' "$name" "$(relative_time "$stamp")"
          done \
        | column -t -s $'\t' \
        | fzf --no-sort --prompt="Workspace > " \
        | awk '{print $1}')

    if [ -z "$choice" ]; then
        echo "xx67f67676"
        return
    fi
    
    echo "$choice"
}

# ============================================================================
# WORKSPACE CORE
# ============================================================================

create_workspace() {
    local name="$1"
    local template="$2"

    if [ -z "$name" ]; then
        read -p "Enter workspace name: " name
    fi

    [ -z "$name" ] && echo -e "${RED}Error: workspace name required${NC}" && exit 1

    local workspace_path="$base_path/$name"

    if [ -d "$workspace_path" ]; then
        echo -e "${RED}Workspace already exists${NC}"
        exit 1
    fi

    echo -e "${BLUE}Creating workspace: $name${NC}"
    mkdir -p "$workspace_path"

    if [ -n "$template" ] && [ -d "$templates_path/$template" ]; then
        cp -r "$templates_path/$template"/* "$workspace_path/"
        echo -e "${GREEN}Template applied: $template${NC}"
    fi

    mkdir -p "$workspace_path"/{src,docs,tests}
    echo "# $name" > "$workspace_path/README.md"
    echo "Created: $(date)" > "$workspace_path/.workspace_info"
    echo "Last accessed: $(date)" >> "$workspace_path/.workspace_info"

    log_access "$name"

    [ "$AUTO_OPEN" = "true" ] && [ "$NO_OPEN" != "true" ] && open_workspace "$name"
}

# The script runs as a child of the shell, so it can't `exit` that shell
# itself; hanging up the parent is what closes the terminal window. Only do
# it when attached to a terminal, so calls from other scripts are untouched.
close_terminal() {
    [ "$CLOSE_TERMINAL" = "true" ] && [ "$NO_CLOSE" != "true" ] || return 0
    [ -t 0 ] && [ -t 1 ] || return 0

    case "$(ps -o comm= -p "$PPID" 2>/dev/null)" in
        bash|zsh|fish|sh|dash) kill -HUP "$PPID" ;;
    esac
}

open_workspace() {
    local name="$1"

    if [ -z "$name" ]; then
        name=$(pick_workspace)
    fi

    if [ "$name" == "xx67f67676" ]; then
        return
    fi

    local workspace_path="$base_path/$name"
    [ ! -d "$workspace_path" ] && echo -e "${RED}Workspace not found${NC}" && exit 1

    echo "Last accessed: $(date)" >> "$workspace_path/.workspace_info"
    log_access "$name"

    echo -e "${GREEN}Opening workspace: $name${NC}"
    cd "$workspace_path"

    if command -v "$EDITOR" >/dev/null 2>&1; then
        "$EDITOR" . && close_terminal
    else
        echo -e "${YELLOW}Editor not found. Showing files...${NC}"
        ls -la
    fi
}

list_workspaces() {
    # If no workspace directory or it's empty
    if [ ! -d "$base_path" ] || [ -z "$(ls -A "$base_path" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No workspaces found${NC}"
        return
    fi

    echo -e "${CYAN}Available workspaces ${NC}(most recently used first)"

    local count=0
    local stamp name

    while IFS=$'\t' read -r stamp name; do
        printf "${GREEN}%-30s${NC} ${BLUE}%s${NC}\n" "$name" "$(relative_time "$stamp")"
        count=$((count + 1))
    done < <(workspace_times)

    echo -e "${BLUE}Total: $count workspaces${NC}"
}


delete_workspace() {
    local name="$1"
    [ -z "$name" ] && name=$(pick_workspace)

    local workspace_path="$base_path/$name"
    [ ! -d "$workspace_path" ] && echo -e "${RED}Workspace not found${NC}" && exit 1

    read -p "Delete '$name'? (y/N): " confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        rm -rf "$workspace_path"
        echo -e "${GREEN}Deleted${NC}"
    else
        echo -e "${BLUE}Cancelled${NC}"
    fi
}

rename_workspace() {
    local old="$1"
    local new="$2"

    [ -z "$old" ] && old=$(pick_workspace)
    [ -z "$new" ] && read -p "New name: " new

    [ -z "$new" ] && echo -e "${RED}New name required${NC}" && exit 1

    mv "$base_path/$old" "$base_path/$new"
    echo -e "${GREEN}Renamed to $new${NC}"
}

clone_workspace() {
    local from="$1"
    local to="$2"

    [ -z "$from" ] && from=$(pick_workspace)
    [ -z "$to" ] && read -p "New workspace name: " to

    cp -r "$base_path/$from" "$base_path/$to"
    echo "Cloned from: $from" >> "$base_path/$to/.workspace_info"
    log_access "$to"

    echo -e "${GREEN}Cloned${NC}"
}

# ============================================================================
# TEMPLATES
# ============================================================================

manage_templates() {
    local action="$1"
    local name="$2"
    local workspace="$3"

    case "$action" in
        create)
            [ -z "$name" ] && read -p "Template name: " name
            mkdir -p "$templates_path/$name"
            cp -r ./* "$templates_path/$name" 2>/dev/null
            echo -e "${GREEN}Template created${NC}"
            ;;
        list)
            echo -e "${CYAN}Templates:${NC}"
            ls "$templates_path"
            ;;
        use)
            create_workspace "$workspace" "$name"
            ;;
        delete)
            rm -rf "$templates_path/$name"
            echo -e "${GREEN}Template deleted${NC}"
            ;;
        *)
            echo -e "${RED}Invalid template command${NC}"
            ;;
    esac
}

# ============================================================================
# EXTRA COMMANDS
# ============================================================================

show_tree() {
    local name="$1"
    [ -z "$name" ] && name=$(pick_workspace)
    tree "$base_path/$name"
}

show_info() {
    local name="$1"
    [ -z "$name" ] && name=$(pick_workspace)

    local p="$base_path/$name"
    echo -e "${CYAN}Info for $name${NC}"
    echo "Path: $p"
    echo "Size: $(du -sh "$p" | cut -f1)"
    echo "Files: $(find "$p" -type f | wc -l)"
    echo "Dirs: $(find "$p" -type d | wc -l)"
}

show_recent() {
    [ ! -f "$base_path/.access_log" ] && echo -e "${YELLOW}No recent activity${NC}" && return
    tail -n 10 "$base_path/.access_log" | tac
}

search_workspaces() {
    local keywords=("$@")
    local limit=20

    if [ ${#keywords[@]} -eq 0 ]; then
        read -r -p "Search keywords: " -a keywords
    fi
    [ ${#keywords[@]} -eq 0 ] && echo -e "${RED}At least one keyword required${NC}" && return 1

    local grep_args=() kw
    for kw in "${keywords[@]}"; do grep_args+=(-e "$kw"); done

    echo -e "${CYAN}Searching for:${NC} ${keywords[*]}"

    # Every hit becomes one "<source>\t<matched text>" line:
    #   content hit -> "./<workspace>/<file>\t<match>"
    #   name hit    -> "@<workspace>\t<keyword>"
    # awk then tallies hits per workspace per keyword.
    local results
    results=$(
        {
            (cd "$base_path" && grep -rIoiF --null \
                --exclude-dir={.git,node_modules,.terraform,.venv,venv,__pycache__,dist,build,.next,target} \
                "${grep_args[@]}" . 2>/dev/null) | tr '\0' '\t'

            local ws name
            shopt -s nocasematch
            for ws in "$base_path"/*/; do
                name=$(basename "$ws")
                for kw in "${keywords[@]}"; do
                    [[ "$name" == *"$kw"* ]] && printf '@%s\t%s\n' "$name" "$kw"
                done
            done
            shopt -u nocasematch
        } | awk -F'\t' -v kws="$(printf '%s\037' "${keywords[@]}")" '
            BEGIN {
                n = split(kws, K, "\037") - 1
                for (i = 1; i <= n; i++) L[i] = tolower(K[i])
            }
            {
                if (substr($1, 1, 1) == "@") {
                    ws = substr($1, 2); by_name[ws] = 1
                } else {
                    ws = $1; sub(/^\.\//, "", ws); sub(/\/.*/, "", ws)
                }
                m = tolower($2)
                for (i = 1; i <= n; i++) if (m == L[i]) { hits[ws, i]++; seen[ws] = 1; break }
            }
            END {
                for (ws in seen) {
                    matched = 0; total = 0; detail = ""
                    for (i = 1; i <= n; i++) {
                        c = hits[ws, i] + 0
                        if (c > 0) matched++
                        total += c
                        detail = detail sprintf("%s:%d ", K[i], c)
                    }
                    printf "%d\t%d\t%s\t%s%s\n", matched, total, ws, detail, (ws in by_name ? "[name]" : "")
                }
            }' \
        | sort -t$'\t' -k1,1nr -k2,2nr
    )

    if [ -z "$results" ]; then
        echo -e "${YELLOW}No workspaces matched${NC}"
        return
    fi

    local count
    count=$(printf '%s\n' "$results" | wc -l)

    printf "\n${YELLOW}%-4s %-30s %-6s %-7s %-9s %s${NC}\n" "#" "WORKSPACE" "KEYS" "HITS" "USED" "BREAKDOWN"

    local rank=0 matched total ws detail stamp
    while IFS=$'\t' read -r matched total ws detail; do
        rank=$((rank + 1))
        stamp=$(stat -c %Y "$base_path/$ws/.workspace_info" 2>/dev/null || stat -c %Y "$base_path/$ws")
        printf "%-4s ${GREEN}%-30s${NC} %-6s %-7s ${BLUE}%-9s${NC} %s\n" \
            "$rank" "$ws" "$matched/${#keywords[@]}" "$total" "$(relative_time "$stamp")" "$detail"
    done < <(printf '%s\n' "$results" | head -n "$limit")

    [ "$count" -gt "$limit" ] && echo -e "${BLUE}... $((count - limit)) more${NC}"
    echo -e "${BLUE}Total: $count workspaces matched${NC}"
}

# ============================================================================
# COMMAND ROUTER
# ============================================================================

handle_command() {
    local cmd="$1"
    shift

    case "$cmd" in
        create) create_workspace "$@" ;;
        open) open_workspace "$@" ;;
        list|ls) list_workspaces ;;
        delete|rm) delete_workspace "$@" ;;
        rename|mv) rename_workspace "$@" ;;
        clone|cp) clone_workspace "$@" ;;
        template) manage_templates "$@" ;;
        tree) show_tree "$@" ;;
        info) show_info "$@" ;;
        recent) show_recent ;;
        search) search_workspaces "$@" ;;
        help|-h|--help) usage ;;
        *) echo -e "${RED}Unknown command${NC}" ;;
    esac
}

parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --editor) EDITOR="$2"; shift 2 ;;
            --no-open) NO_OPEN="true"; shift ;;
            --no-close) NO_CLOSE="true"; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            *) handle_command "$@" ; exit 0 ;;
        esac
    done
}

main() {
    init_workspace
    load_config

    [ $# -eq 0 ] && list_workspaces && exit 0

    parse_options "$@"
}

main "$@"
