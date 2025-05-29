#!/bin/bash

# Workspace Manager - Enhanced Version
script_name="workspace"
base_path="/home/$USER/Documents/workspaces"
templates_path="/home/$USER/Documents/workspace-templates"
script_directory="/home/$USER/Documents/os-scripts/"
config_file="/home/$USER/.workspace_config"

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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
    echo -e "  ${GREEN}template create${NC} [NAME]     Create template from current directory"
    echo -e "  ${GREEN}template list${NC}             List available templates"
    echo -e "  ${GREEN}template use${NC} [TEMPLATE] [WORKSPACE]  Create workspace from template"
    echo -e "  ${GREEN}template delete${NC} [NAME]    Delete template"
    echo
    echo -e "${YELLOW}Utility Commands:${NC}"
    echo -e "  ${GREEN}tree${NC} [NAME]          Show workspace structure"
    echo -e "  ${GREEN}info${NC} [NAME]          Show workspace information"
    echo -e "  ${GREEN}recent${NC}               Show recently accessed workspaces"
    echo -e "  ${GREEN}search${NC} [TERM]        Search workspaces by name/content"
    echo -e "  ${GREEN}backup${NC} [NAME]        Backup workspace to archive"
    echo -e "  ${GREEN}restore${NC} [ARCHIVE]    Restore workspace from archive"
    echo
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  ${GREEN}-h, --help${NC}           Show this help message"
    echo -e "  ${GREEN}-v, --verbose${NC}        Verbose output"
    echo -e "  ${GREEN}--editor [EDITOR]${NC}    Specify editor (code, vim, nano, etc.)"
    echo -e "  ${GREEN}--no-open${NC}            Don't open editor after creation"
    echo
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 create my-project"
    echo -e "  $0 open my-project"
    echo -e "  $0 template use python-basic my-new-app"
    echo -e "  $0 delete old-project"
    exit 0
}

# Initialize directories and config
init_workspace() {
    mkdir -p "$base_path" "$templates_path" "$script_directory"
    if [ ! -f "$config_file" ]; then
        echo "editor=code" > "$config_file"
        echo "auto_open=true" >> "$config_file"
    fi
}

# Load configuration
load_config() {
    if [ -f "$config_file" ]; then
        source "$config_file"
    fi
    EDITOR=${editor:-code}
    AUTO_OPEN=${auto_open:-true}
}

# Log workspace access for recent tracking
log_access() {
    local workspace="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp|$workspace" >> "$base_path/.access_log"
    # Keep only last 50 entries
    tail -n 50 "$base_path/.access_log" > "$base_path/.access_log.tmp" && mv "$base_path/.access_log.tmp" "$base_path/.access_log"
}

# Create new workspace
create_workspace() {
    local name="$1"
    local template="$2"
    
    if [ -z "$name" ]; then
        read -p "Enter workspace name: " name
    fi
    
    if [ -z "$name" ]; then
        echo -e "${RED}Error: Workspace name cannot be empty${NC}"
        exit 1
    fi
    
    local workspace_path="$base_path/$name"
    
    if [ -d "$workspace_path" ]; then
        echo -e "${RED}Error: Workspace '$name' already exists${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Creating workspace: $name${NC}"
    mkdir -p "$workspace_path"
    
    # Create from template if specified
    if [ -n "$template" ]; then
        if [ -d "$templates_path/$template" ]; then
            cp -r "$templates_path/$template"/* "$workspace_path/"
            echo -e "${GREEN}Applied template: $template${NC}"
        else
            echo -e "${YELLOW}Warning: Template '$template' not found, creating empty workspace${NC}"
        fi
    fi
    
    # Create basic structure
    mkdir -p "$workspace_path"/{src,docs,tests}
    echo "# $name" > "$workspace_path/README.md"
    echo "Created: $(date)" > "$workspace_path/.workspace_info"
    echo "Last accessed: $(date)" >> "$workspace_path/.workspace_info"
    
    echo -e "${GREEN}Workspace '$name' created successfully${NC}"
    log_access "$name"
    
    # Open in editor if enabled
    if [ "$AUTO_OPEN" = "true" ] && [ "$NO_OPEN" != "true" ]; then
        open_workspace "$name"
    fi
}

# Open existing workspace
open_workspace() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Available workspaces:${NC}"
        list_workspaces
        echo
        read -p "Enter workspace name to open: " name
    fi
    
    if [ -z "$name" ]; then
        echo -e "${RED}Error: No workspace specified${NC}"
        exit 1
    fi
    
    local workspace_path="$base_path/$name"
    
    if [ ! -d "$workspace_path" ]; then
        echo -e "${RED}Error: Workspace '$name' does not exist${NC}"
        echo -e "${YELLOW}Available workspaces:${NC}"
        list_workspaces
        exit 1
    fi
    
    # Update last accessed time
    echo "Last accessed: $(date)" >> "$workspace_path/.workspace_info"
    log_access "$name"
    
    echo -e "${GREEN}Opening workspace: $name${NC}"
    cd "$workspace_path"
    
    if command -v "$EDITOR" >/dev/null 2>&1; then
        "$EDITOR" .
    else
        echo -e "${YELLOW}Editor '$EDITOR' not found. Workspace opened at: $workspace_path${NC}"
        echo -e "${BLUE}Contents:${NC}"
        ls -la
    fi
}

# List all workspaces
list_workspaces() {
    if [ ! -d "$base_path" ] || [ -z "$(ls -A "$base_path" 2>/dev/null)" ]; then
        echo -e "${YELLOW}No workspaces found${NC}"
        return
    fi
    
    echo -e "${CYAN}Available workspaces:${NC}"
    local count=0
    for workspace in "$base_path"/*; do
        if [ -d "$workspace" ]; then
            local name=$(basename "$workspace")
            local info=""
            if [ -f "$workspace/.workspace_info" ]; then
                info=$(tail -n 1 "$workspace/.workspace_info" | cut -d: -f2-)
            fi
            printf "${GREEN}%-20s${NC} %s\n" "$name" "$info"
            ((count++))
        fi
    done
    echo -e "${BLUE}Total: $count workspaces${NC}"
}

# Delete workspace
delete_workspace() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Available workspaces:${NC}"
        list_workspaces
        echo
        read -p "Enter workspace name to delete: " name
    fi
    
    if [ -z "$name" ]; then
        echo -e "${RED}Error: No workspace specified${NC}"
        exit 1
    fi
    
    local workspace_path="$base_path/$name"
    
    if [ ! -d "$workspace_path" ]; then
        echo -e "${RED}Error: Workspace '$name' does not exist${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Workspace contents:${NC}"
    ls -la "$workspace_path"
    echo
    read -p "Are you sure you want to delete workspace '$name'? (y/N): " confirm
    
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        rm -rf "$workspace_path"
        echo -e "${GREEN}Workspace '$name' deleted successfully${NC}"
    else
        echo -e "${BLUE}Deletion cancelled${NC}"
    fi
}

# Rename workspace
rename_workspace() {
    local old_name="$1"
    local new_name="$2"
    
    if [ -z "$old_name" ]; then
        echo -e "${CYAN}Available workspaces:${NC}"
        list_workspaces
        echo
        read -p "Enter current workspace name: " old_name
    fi
    
    if [ -z "$new_name" ]; then
        read -p "Enter new workspace name: " new_name
    fi
    
    if [ -z "$old_name" ] || [ -z "$new_name" ]; then
        echo -e "${RED}Error: Both old and new names are required${NC}"
        exit 1
    fi
    
    local old_path="$base_path/$old_name"
    local new_path="$base_path/$new_name"
    
    if [ ! -d "$old_path" ]; then
        echo -e "${RED}Error: Workspace '$old_name' does not exist${NC}"
        exit 1
    fi
    
    if [ -d "$new_path" ]; then
        echo -e "${RED}Error: Workspace '$new_name' already exists${NC}"
        exit 1
    fi
    
    mv "$old_path" "$new_path"
    echo -e "${GREEN}Workspace renamed from '$old_name' to '$new_name'${NC}"
}

# Clone workspace
clone_workspace() {
    local from="$1"
    local to="$2"
    
    if [ -z "$from" ]; then
        echo -e "${CYAN}Available workspaces:${NC}"
        list_workspaces
        echo
        read -p "Enter workspace to clone from: " from
    fi
    
    if [ -z "$to" ]; then
        read -p "Enter new workspace name: " to
    fi
    
    if [ -z "$from" ] || [ -z "$to" ]; then
        echo -e "${RED}Error: Both source and destination names are required${NC}"
        exit 1
    fi
    
    local from_path="$base_path/$from"
    local to_path="$base_path/$to"
    
    if [ ! -d "$from_path" ]; then
        echo -e "${RED}Error: Source workspace '$from' does not exist${NC}"
        exit 1
    fi
    
    if [ -d "$to_path" ]; then
        echo -e "${RED}Error: Destination workspace '$to' already exists${NC}"
        exit 1
    fi
    
    cp -r "$from_path" "$to_path"
    echo "Cloned from: $from" >> "$to_path/.workspace_info"
    echo "Created: $(date)" >> "$to_path/.workspace_info"
    echo -e "${GREEN}Workspace '$from' cloned to '$to'${NC}"
    log_access "$to"
}

# Template management
manage_templates() {
    local action="$1"
    local name="$2"
    local workspace="$3"
    
    case "$action" in
        create)
            if [ -z "$name" ]; then
                read -p "Enter template name: " name
            fi
            if [ -z "$name" ]; then
                echo -e "${RED}Error: Template name cannot be empty${NC}"
                exit 1
            fi
            
            local template_path="$templates_path/$name"
            if [ -d "$template_path" ]; then
                echo -e "${RED}Error: Template '$name' already exists${NC}"
                exit 1
            fi
            
            mkdir -p "$template_path"
            cp -r ./* "$template_path/" 2>/dev/null || true
            echo "Template: $name" > "$template_path/.template_info"
            echo "Created: $(date)" >> "$template_path/.template_info"
            echo -e "${GREEN}Template '$name' created from current directory${NC}"
            ;;
        list)
            if [ ! -d "$templates_path" ] || [ -z "$(ls -A "$templates_path" 2>/dev/null)" ]; then
                echo -e "${YELLOW}No templates found${NC}"
                return
            fi
            
            echo -e "${CYAN}Available templates:${NC}"
            for template in "$templates_path"/*; do
                if [ -d "$template" ]; then
                    local template_name=$(basename "$template")
                    local info=""
                    if [ -f "$template/.template_info" ]; then
                        info=$(tail -n 1 "$template/.template_info" | cut -d: -f2-)
                    fi
                    printf "${GREEN}%-20s${NC} %s\n" "$template_name" "$info"
                fi
            done
            ;;
        use)
            if [ -z "$name" ] || [ -z "$workspace" ]; then
                echo -e "${RED}Error: Both template name and workspace name are required${NC}"
                exit 1
            fi
            create_workspace "$workspace" "$name"
            ;;
        delete)
            if [ -z "$name" ]; then
                echo -e "${CYAN}Available templates:${NC}"
                manage_templates list
                echo
                read -p "Enter template name to delete: " name
            fi
            
            local template_path="$templates_path/$name"
            if [ ! -d "$template_path" ]; then
                echo -e "${RED}Error: Template '$name' does not exist${NC}"
                exit 1
            fi
            
            read -p "Are you sure you want to delete template '$name'? (y/N): " confirm
            if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
                rm -rf "$template_path"
                echo -e "${GREEN}Template '$name' deleted${NC}"
            else
                echo -e "${BLUE}Deletion cancelled${NC}"
            fi
            ;;
        *)
            echo -e "${RED}Error: Invalid template action '$action'${NC}"
            echo -e "${YELLOW}Available actions: create, list, use, delete${NC}"
            exit 1
            ;;
    esac
}

# Show workspace tree
show_tree() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Available workspaces:${NC}"
        list_workspaces
        echo
        read -p "Enter workspace name: " name
    fi
    
    local workspace_path="$base_path/$name"
    
    if [ ! -d "$workspace_path" ]; then
        echo -e "${RED}Error: Workspace '$name' does not exist${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Structure of workspace '$name':${NC}"
    if command -v tree >/dev/null 2>&1; then
        tree "$workspace_path"
    else
        find "$workspace_path" -type f | head -20
        echo -e "${YELLOW}(Install 'tree' command for better visualization)${NC}"
    fi
}

# Show workspace info
show_info() {
    local name="$1"
    
    if [ -z "$name" ]; then
        echo -e "${CYAN}Available workspaces:${NC}"
        list_workspaces
        echo
        read -p "Enter workspace name: " name
    fi
    
    local workspace_path="$base_path/$name"
    
    if [ ! -d "$workspace_path" ]; then
        echo -e "${RED}Error: Workspace '$name' does not exist${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Workspace Information: $name${NC}"
    echo -e "${BLUE}Path:${NC} $workspace_path"
    echo -e "${BLUE}Size:${NC} $(du -sh "$workspace_path" | cut -f1)"
    echo -e "${BLUE}Files:${NC} $(find "$workspace_path" -type f | wc -l)"
    echo -e "${BLUE}Directories:${NC} $(find "$workspace_path" -type d | wc -l)"
    
    if [ -f "$workspace_path/.workspace_info" ]; then
        echo -e "${BLUE}Details:${NC}"
        cat "$workspace_path/.workspace_info" | sed 's/^/  /'
    fi
}

# Show recent workspaces
show_recent() {
    if [ ! -f "$base_path/.access_log" ]; then
        echo -e "${YELLOW}No recent activity found${NC}"
        return
    fi
    
    echo -e "${CYAN}Recently accessed workspaces:${NC}"
    tail -n 10 "$base_path/.access_log" | tac | while IFS='|' read -r timestamp workspace; do
        if [ -d "$base_path/$workspace" ]; then
            printf "${GREEN}%-20s${NC} %s\n" "$workspace" "$timestamp"
        fi
    done
}

# Search workspaces
search_workspaces() {
    local term="$1"
    
    if [ -z "$term" ]; then
        read -p "Enter search term: " term
    fi
    
    if [ -z "$term" ]; then
        echo -e "${RED}Error: Search term cannot be empty${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}Searching for: $term${NC}"
    
    # Search in workspace names
    echo -e "${YELLOW}Matching workspace names:${NC}"
    find "$base_path" -maxdepth 1 -type d -name "*$term*" -exec basename {} \; | grep -v "^workspaces$" || echo "  No matches"
    
    # Search in file contents
    echo -e "${YELLOW}Matching file contents:${NC}"
    if command -v grep >/dev/null 2>&1; then
        grep -r "$term" "$base_path" --exclude-dir=".git" 2>/dev/null | head -10 | while read -r line; do
            echo "  $line"
        done
    fi
}

# Main command handler
handle_command() {
    local command="$1"
    shift
    
    case "$command" in
        create)
            create_workspace "$1" "$2"
            ;;
        open)
            open_workspace "$1"
            ;;
        list|ls)
            list_workspaces
            ;;
        delete|rm)
            delete_workspace "$1"
            ;;
        rename|mv)
            rename_workspace "$1" "$2"
            ;;
        clone|cp)
            clone_workspace "$1" "$2"
            ;;
        template)
            manage_templates "$@"
            ;;
        tree)
            show_tree "$1"
            ;;
        info)
            show_info "$1"
            ;;
        recent)
            show_recent
            ;;
        search)
            search_workspaces "$1"
            ;;
        backup)
            echo -e "${YELLOW}Backup feature coming soon...${NC}"
            ;;
        restore)
            echo -e "${YELLOW}Restore feature coming soon...${NC}"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            if [ -z "$command" ]; then
                list_workspaces
                exit 0
            fi
            echo -e "${RED}Error: Unknown command '$command'${NC}"
            echo -e "${YELLOW}Use '$0 --help' for usage information${NC}"
            exit 1
            ;;
    esac
}

# Parse global options
parse_options() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --editor)
                EDITOR="$2"
                shift 2
                ;;
            --no-open)
                NO_OPEN="true"
                shift
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            *)
                handle_command "$@"
                exit 0
                ;;
        esac
    done
    
    # If no command provided, show list
    list_workspaces
}

# Main execution
main() {
    init_workspace
    load_config
    
    if [ $# -eq 0 ]; then
        list_workspaces
        exit 0
    fi
    
    parse_options "$@"
}

main "$@"
