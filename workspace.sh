#!/bin/bash

# Workspace Manager - Enhanced Version + FZF selection
script_name="workspace"
base_path="/home/$USER/Documents/workspaces"
templates_path="/home/$USER/Documents/workspace-templates"
script_directory="/home/$USER/Documents/os-scripts/"
config_file="/home/$USER/.workspace_config"

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
    echo -e "\n${YELLOW}Usage:${NC} $0 [COMMAND] [OPTIONS]"
    echo
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${GREEN}create${NC} [NAME]        Create new workspace"
    echo -e "  ${GREEN}open${NC} [NAME]          Open existing workspace"
    echo -e "  ${GREEN}list${NC}                List all workspaces"
    echo -e "  ${GREEN}delete${NC} [NAME]        Delete workspace"
    echo -e "  ${GREEN}rename${NC} [OLD] [NEW]   Rename workspace"
    echo -e "  ${GREEN}clone${NC} [FROM] [TO]    Clone workspace"
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
    echo -e "  ${GREEN}search${NC} [TERM]        Search workspaces"
    echo -e "  ${GREEN}backup${NC} [NAME]        Backup workspace"
    echo -e "  ${GREEN}restore${NC} [ARCHIVE]    Restore workspace"
    echo
    exit 0
}

# Initialization
init_workspace() {
    mkdir -p "$base_path" "$templates_path" "$script_directory"
    if [ ! -f "$config_file" ]; then
        echo "editor=code" > "$config_file"
        echo "auto_open=true" >> "$config_file"
    fi
}

load_config() {
    [ -f "$config_file" ] && source "$config_file"
    EDITOR=${editor:-code}
    AUTO_OPEN=${auto_open:-true}
}

log_access() {
    local workspace="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$workspace" >> "$base_path/.access_log"
    tail -n 50 "$base_path/.access_log" > "$base_path/.temp" && mv "$base_path/.temp" "$base_path/.access_log"
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
    choice=$(find "$base_path" -maxdepth 1 -mindepth 1 -type d -printf "%f\n" \
        | fzf --prompt="Workspace > ")

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
        "$EDITOR" .
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

    echo -e "${CYAN}Available workspaces:${NC}"

    local count=0

    for workspace in "$base_path"/*; do
        if [ -d "$workspace" ]; then
            local name
            name=$(basename "$workspace")

            local info=""
            if [ -f "$workspace/.workspace_info" ]; then
                # last line, remove the "key:" portion
                info=$(tail -n 1 "$workspace/.workspace_info" | cut -d: -f2-)
            fi

            # aligned name + info
            printf "${GREEN}%-20s${NC} %s\n" "$name" "$info"

            ((count++))
        fi
    done

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
    local term="$1"
    [ -z "$term" ] && read -p "Search term: " term
    grep -r "$term" "$base_path" 2>/dev/null | head -20
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
