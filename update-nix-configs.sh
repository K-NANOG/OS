#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_CONFIG_DIR="$SCRIPT_DIR/nixos"
BACKUP_DIR="$SCRIPT_DIR/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

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
    mkdir -p "$NIXOS_CONFIG_DIR"
    
    if [ -f "/etc/nixos/configuration.nix" ]; then
        cp "/etc/nixos/configuration.nix" "$NIXOS_CONFIG_DIR/"
        echo "Updated configuration.nix"
    else
        echo "Warning: /etc/nixos/configuration.nix not found"
    fi
    
    if [ -f "/etc/nixos/hardware-configuration.nix" ]; then
        cp "/etc/nixos/hardware-configuration.nix" "$NIXOS_CONFIG_DIR/"
        echo "Updated hardware-configuration.nix"
    else
        echo "Warning: /etc/nixos/hardware-configuration.nix not found"
    fi
    
    for file in /etc/nixos/*.nix; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "configuration.nix" ] && [ "$(basename "$file")" != "hardware-configuration.nix" ]; then
            cp "$file" "$NIXOS_CONFIG_DIR/"
            echo "Updated $(basename "$file")"
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
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  backup          Create backup of current configurations"
    echo "  update          Update repo configs from /etc/nixos/"
    echo "  deploy          Deploy repo configs to /etc/nixos/ and rebuild"
    echo "  full-update     Backup current, then update from system"
    echo "  full-deploy     Backup current system, then deploy and rebuild"
    echo "  list-backups    List available backups"
    echo "  restore BACKUP  Restore from specific backup (use timestamp)"
    echo "  help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 update       # Pull latest configs from /etc/nixos/"
    echo "  $0 deploy       # Push configs to /etc/nixos/ and rebuild"
    echo "  $0 full-update  # Backup then update from system"
    echo "  $0 restore 20240101_120000  # Restore specific backup"
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

case "${1:-help}" in
    "backup")
        create_backup
        ;;
    "update")
        create_backup
        update_from_system
        ;;
    "deploy")
        deploy_to_system
        ;;
    "full-update")
        create_backup
        update_from_system
        ;;
    "full-deploy")
        create_backup
        deploy_to_system
        ;;
    "list-backups")
        list_backups
        ;;
    "restore")
        restore_backup "$2"
        ;;
    "help"|*)
        show_help
        ;;
esac

echo "Operation completed successfully!"