#!/bin/bash

# Function to print an error message and exit
function error_exit {
    echo "$1" 1>&2
    exit 1
}

CURRENT_DIR="$PWD"


# Detect the operating system
OS_TYPE=$(uname)
KERNEL_INFO=$(uname -r)

if [ "$OS_TYPE" == "Darwin" ]; then
    echo "Starting uninstallation process..."
    
    # REMOVE MAGIC and OPEN_PDKs
    echo "Uninstalling Magic and open_pdks directories"
    if [ -d "$CURRENT_DIR/magic" ]; then
        sudo rm -rf "$CURRENT_DIR/magic" || error_exit "Failed to remove magic directory."
    fi
    if [ -d "$CURRENT_DIR/open_pdks" ]; then
        sudo rm -rf "$CURRENT_DIR/open_pdks" || error_exit "Failed to remove open_pdks directory."
    fi
    if [ -d "/usr/local/share/pdk" ]; then
        sudo rm -rf "/usr/local/share/pdk" || error_exit "Failed to remove shared pdk directory."
    fi
    
    
    # REMOVE PDKs LINK
    # Directory containing the source files and directories
    SOURCE_DIR="./open_pdks/sources"
    
    # Target directory for the symbolic links
    TARGET_DIR="/usr/local/share"
    
    
    # Remove the symlinks in the target directory that point to the source directory
    for dir in $SOURCE_DIR/*; do
        # Extract just the directory name
        dir_name=$(basename "$dir")
        # Path to the potential symlink in the target directory
        symlink_path="$TARGET_DIR/$dir_name"
        # Check if the symlink exists and is indeed a symlink
        if [ -L "$symlink_path" ]; then
            # Remove the symlink
            echo "Removing symlink: $symlink_path"
            rm "$symlink_path"
        else
            echo "No symlink found for $symlink_path, skipping..."
        fi
    done
    
    
    # REMOVE VENV
    if [ -d "~/my_venv_pdk_rad_hard" ]; then
        sudo rm -rf "~/my_venv_pdk_rad_hard" || error_exit "Failed to remove venv my_venv_pdk_rad_hard."
    fi
    
    
    echo "Uninstallation process completed successfully."
elif [ "$OS_TYPE" == "Linux" ]; then
    # Linux Installation Script
    echo "Detected Linux. Running Linux uninstall script..."

    set -eu -o pipefail # fail on error and report it, debug all lines

    sudo -n true    # Run as a superuser and do not ask for a password. Exit status as successful.
    test $? -eq 0 || error_exit "you should have sudo privilege to run this script"

    # MAGIC
    echo "Removing MAGIC..."
    sudo rm -rf magic

    # OPEN PDK
    echo "Removing OPEN PDK..."
    sudo rm -rf open_pdks

    echo "installing the must-have pre-requisites"
    while read -r p ; do sudo apt-get remove -y $p ; done < <(cat << "EOF"
        build-essential flex bison m4 tcsh csh
        libx11-dev tcl-dev tk-dev libcairo2 libcairo2-dev
        libxcb1 libx11-xcb-dev libxrender1 libxrender-dev libxpm4 libxpm-dev libncurses-dev
        gawk libtool readline-common libreadline-dev autoconf automake
        gcc g++ gfortran make cmake libfl-dev wget
EOF
    )

    echo "Uninstall completed successfully."
else
    error_exit "Unsupported operating system. This script supports macOS and Linux only."
fi
