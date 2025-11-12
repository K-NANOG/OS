#!/run/current-system/sw/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="$SCRIPT_DIR/nixos"
BACKUP_DIR="$SCRIPT_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Parse command line arguments
DRY_RUN=false
COMMAND=""

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            if [ -z "$COMMAND" ]; then
                COMMAND="$arg"
            fi
            shift
            ;;
    esac
done

echo "NixOS Configuration Backup and Update Script"
echo "============================================"

create_backup() {
    echo "Creating backup directory: $BACKUP_DIR/$TIMESTAMP"
    mkdir -p "$BACKUP_DIR/$TIMESTAMP"
    
    if [ -d "$NIXOS_CONFIG_DIR" ]; then
        echo "Backing up current Nix configurations..."
        cp -r "$NIXOS_CONFIG_DIR"/* "$BACKUP_DIR/$TIMESTAMP/"
        echo "Backup created in: $BACKUP_DIR/$TIMESTAMP"
    else
        echo "No existing Nix configuration directory found at $NIXOS_CONFIG_DIR"
    fi
}

update_from_system() {
    echo "Updating configurations from /etc/nixos/..."
    
    # Check if we can write to the nixos directory
    if ! mkdir -p "$NIXOS_CONFIG_DIR" 2>/dev/null; then
        echo "Error: Cannot create nixos directory $NIXOS_CONFIG_DIR"
        echo "You may need to fix ownership with: sudo chown -R $USER:$(id -gn) $NIXOS_CONFIG_DIR"
        exit 1
    fi
    
    # Check write permissions
    if [ ! -w "$NIXOS_CONFIG_DIR" ]; then
        echo "Error: No write permission to $NIXOS_CONFIG_DIR"
        echo "You may need to fix ownership with: sudo chown -R $USER:$(id -gn) $NIXOS_CONFIG_DIR"
        exit 1
    fi
    
    if [ -f "/etc/nixos/configuration.nix" ]; then
        if cp "/etc/nixos/configuration.nix" "$NIXOS_CONFIG_DIR/" 2>/dev/null; then
            echo "Updated configuration.nix"
        else
            echo "Error: Failed to copy configuration.nix (permission denied?)"
            exit 1
        fi
    else
        echo "Warning: /etc/nixos/configuration.nix not found"
    fi
    
    if [ -f "/etc/nixos/hardware-configuration.nix" ]; then
        if cp "/etc/nixos/hardware-configuration.nix" "$NIXOS_CONFIG_DIR/" 2>/dev/null; then
            echo "Updated hardware-configuration.nix"
        else
            echo "Error: Failed to copy hardware-configuration.nix (permission denied?)"
            exit 1
        fi
    else
        echo "Warning: /etc/nixos/hardware-configuration.nix not found"
    fi
    
    for file in /etc/nixos/*.nix; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "configuration.nix" ] && [ "$(basename "$file")" != "hardware-configuration.nix" ]; then
            if cp "$file" "$NIXOS_CONFIG_DIR/" 2>/dev/null; then
                echo "Updated $(basename "$file")"
            else
                echo "Warning: Failed to copy $(basename "$file") (permission denied?)"
            fi
        fi
    done
}

deploy_to_system() {
    echo "Deploying configurations to /etc/nixos/..."
    
    if [ ! -d "$NIXOS_CONFIG_DIR" ]; then
        echo "Error: No Nix configuration directory found at $NIXOS_CONFIG_DIR"
        exit 1
    fi
    
    sudo cp "$NIXOS_CONFIG_DIR"/* /etc/nixos/
    echo "Configurations deployed to /etc/nixos/"
    
    echo "Rebuilding NixOS system..."
    sudo nixos-rebuild switch
}

show_help() {
    echo "Usage: $0 [OPTION] [--dry-run]"
    echo ""
    echo "A NixOS configuration management tool that helps you:"
    echo "- Backup your current configurations"
    echo "- Sync between /etc/nixos/ and your repository"
    echo "- Deploy configurations with system rebuild"
    echo ""
    echo "Options:"
    echo "  backup          Create backup of current configurations"
    echo "  update          Update repo configs from /etc/nixos/"
    echo "  deploy          Deploy repo configs to /etc/nixos/ and rebuild"
    echo "  full-update     Backup current, then update from system"
    echo "  full-deploy     Backup current system, then deploy and rebuild"
    echo "  list-backups    List available backups"
    echo "  restore BACKUP  Restore from specific backup (use timestamp)"
    echo "  status          Show configuration status and differences"
    echo "  help            Show this help message"
    echo ""
    echo "Flags:"
    echo "  --dry-run       Show what would be done without making changes"
    echo ""
    echo "Examples:"
    echo "  $0 update              # Pull latest configs from /etc/nixos/"
    echo "  $0 deploy              # Push configs to /etc/nixos/ and rebuild"
    echo "  $0 deploy --dry-run    # Preview what deploy would do"
    echo "  $0 status              # Check differences between repo and system"
    echo "  $0 full-update         # Backup then update from system"
    echo "  $0 restore 20240101_120000  # Restore specific backup"
    echo ""
    echo "Note: If you get permission errors, you may need to fix ownership:"
    echo "  sudo chown -R \$USER:\$(id -gn) $NIXOS_CONFIG_DIR"
}

list_backups() {
    echo "Available backups:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -1 "$BACKUP_DIR" 2>/dev/null || echo "No backups found"
    else
        echo "No backup directory found"
    fi
}

restore_backup() {
    local backup_name="$1"
    if [ -z "$backup_name" ]; then
        echo "Error: Backup name required"
        echo "Use: $0 list-backups to see available backups"
        exit 1
    fi
    
    local backup_path="$BACKUP_DIR/$backup_name"
    if [ ! -d "$backup_path" ]; then
        echo "Error: Backup $backup_name not found"
        exit 1
    fi
    
    echo "Restoring from backup: $backup_name"
    create_backup  # Backup current state first
    
    mkdir -p "$NIXOS_CONFIG_DIR"
    cp -r "$backup_path"/* "$NIXOS_CONFIG_DIR/"
    echo "Restored configurations from backup: $backup_name"
}

show_status() {
    echo "Configuration Status"
    echo "===================="
    echo "Repository: $NIXOS_CONFIG_DIR"
    echo "System:     /etc/nixos/"
    echo ""
    
    if [ ! -d "$NIXOS_CONFIG_DIR" ]; then
        echo "No repository configuration found at $NIXOS_CONFIG_DIR"
        return 1
    fi
    
    echo "Checking differences..."
    
    # Check configuration.nix
    if [ -f "$NIXOS_CONFIG_DIR/configuration.nix" ] && [ -f "/etc/nixos/configuration.nix" ]; then
        if diff -q "$NIXOS_CONFIG_DIR/configuration.nix" "/etc/nixos/configuration.nix" >/dev/null 2>&1; then
            echo "✓ configuration.nix: in sync"
        else
            echo "✗ configuration.nix: differs"
            echo "  Use 'diff $NIXOS_CONFIG_DIR/configuration.nix /etc/nixos/configuration.nix' to see differences"
        fi
    else
        echo "⚠ configuration.nix: missing in repo or system"
    fi
    
    # Check hardware-configuration.nix
    if [ -f "$NIXOS_CONFIG_DIR/hardware-configuration.nix" ] && [ -f "/etc/nixos/hardware-configuration.nix" ]; then
        if diff -q "$NIXOS_CONFIG_DIR/hardware-configuration.nix" "/etc/nixos/hardware-configuration.nix" >/dev/null 2>&1; then
            echo "✓ hardware-configuration.nix: in sync"
        else
            echo "✗ hardware-configuration.nix: differs"
            echo "  Use 'diff $NIXOS_CONFIG_DIR/hardware-configuration.nix /etc/nixos/hardware-configuration.nix' to see differences"
        fi
    else
        echo "⚠ hardware-configuration.nix: missing in repo or system"
    fi
    
    # Check for other .nix files
    if ls /etc/nixos/*.nix >/dev/null 2>&1; then
        for file in /etc/nixos/*.nix; do
            filename=$(basename "$file")
            if [ "$filename" != "configuration.nix" ] && [ "$filename" != "hardware-configuration.nix" ]; then
                if [ -f "$NIXOS_CONFIG_DIR/$filename" ]; then
                    if diff -q "$NIXOS_CONFIG_DIR/$filename" "$file" >/dev/null 2>&1; then
                        echo "✓ $filename: in sync"
                    else
                        echo "✗ $filename: differs"
                    fi
                else
                    echo "⚠ $filename: not in repository"
                fi
            fi
        done
    fi
}

# Show dry-run warning
if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "🔍 DRY RUN MODE - No changes will be made"
    echo ""
fi

case "${COMMAND:-help}" in
    "backup")
        if [ "$DRY_RUN" = true ]; then
            echo "Would create backup in: $BACKUP_DIR/$TIMESTAMP"
            if [ -d "$NIXOS_CONFIG_DIR" ]; then
                echo "Would backup files:"
                ls -la "$NIXOS_CONFIG_DIR"
            fi
        else
            create_backup
        fi
        ;;
    "update")
        if [ "$DRY_RUN" = true ]; then
            echo "Would create backup, then update from /etc/nixos/ to $NIXOS_CONFIG_DIR"
            echo "Files that would be copied:"
            ls -la /etc/nixos/*.nix 2>/dev/null || echo "No .nix files found in /etc/nixos/"
        else
            create_backup
            update_from_system
        fi
        ;;
    "deploy")
        if [ "$DRY_RUN" = true ]; then
            echo "Would deploy configurations from $NIXOS_CONFIG_DIR to /etc/nixos/"
            echo "Would run: sudo nixos-rebuild switch"
            if [ -d "$NIXOS_CONFIG_DIR" ]; then
                echo "Files that would be deployed:"
                ls -la "$NIXOS_CONFIG_DIR"
            fi
        else
            deploy_to_system
        fi
        ;;
    "full-update")
        if [ "$DRY_RUN" = true ]; then
            echo "Would create backup, then update from /etc/nixos/ to $NIXOS_CONFIG_DIR"
        else
            create_backup
            update_from_system
        fi
        ;;
    "full-deploy")
        if [ "$DRY_RUN" = true ]; then
            echo "Would create backup, then deploy and rebuild system"
        else
            create_backup
            deploy_to_system
        fi
        ;;
    "list-backups")
        list_backups
        ;;
    "restore")
        if [ "$DRY_RUN" = true ]; then
            echo "Would restore from backup: ${2:-[BACKUP_NAME_REQUIRED]}"
        else
            restore_backup "$2"
        fi
        ;;
    "status")
        show_status
        ;;
    "help"|*)
        show_help
        ;;
esac

if [ "$DRY_RUN" = false ]; then
    echo "Operation completed successfully!"
fi