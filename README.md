Workspace Manager - Easy project workspace management

Usage: workspace.sh [COMMAND] [OPTIONS]

Commands:
  create [NAME]        Create new workspace
  open [NAME]          Open existing workspace
  list                List all workspaces
  delete [NAME]        Delete workspace
  rename [OLD] [NEW]   Rename workspace
  clone [FROM] [TO]    Clone workspace

Template Commands:
  template create [NAME]     Create template from current directory
  template list             List available templates
  template use [TEMPLATE] [WORKSPACE]  Create workspace from template
  template delete [NAME]    Delete template

Utility Commands:
  tree [NAME]          Show workspace structure
  info [NAME]          Show workspace information
  recent               Show recently accessed workspaces
  search [TERM]        Search workspaces by name/content
  backup [NAME]        Backup workspace to archive
  restore [ARCHIVE]    Restore workspace from archive

Options:
  -h, --help           Show this help message
  -v, --verbose        Verbose output
  --editor [EDITOR]    Specify editor (code, vim, nano, etc.)
  --no-open            Don't open editor after creation

Examples:
  workspace.sh create my-project
  workspace.sh open my-project
  workspace.sh template use python-basic my-new-app
  workspace.sh delete old-project
