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
    ########################################################################
    # MacOS Uninstall Script
    ########################################################################
    echo "Starting uninstallation process..."
    
    # Remove xschem-gaw installation
    if [ -d "/tmp/xschem-gaw" ]; then
        echo "Uninstalling xschem-gaw..."
        sudo rm -rf "/tmp/xschem-gaw" || error_exit "Failed to remove xschem-gaw directory."
    fi
    
    # Uninstall xschem
    echo "Uninstalling xschem..."
    if [ -d "/Users/$(whoami)/opt/xschem" ]; then
        sudo rm -rf "/Users/$(whoami)/opt/xschem" || error_exit "Failed to remove xschem directory."
    fi
    if [ -d "/tmp/xschem" ]; then
        sudo rm -rf "/tmp/xschem" || error_exit "Failed to remove xschem directory."
    fi
    if [ -d "/Users/$(whoami)/.xschem" ]; then
        sudo rm -rf "/Users/$(whoami)/.xschem" || error_exit "Failed to remove .xschem directory."
    fi
    
    # Uninstall Tcl and Tk
    echo "Uninstalling Tcl and Tk..."
    if [ -d "/usr/local/opt/tcl-tk" ]; then
        sudo rm -rf "/usr/local/opt/tcl-tk" || error_exit "Failed to remove Tcl-Tk directory."
    fi
    
    # Remove symlink for libtk
    echo "Removing symlink for libtk..."
    if [ -L "/opt/X11/lib/libtk8.6.dylib" ]; then
        sudo rm "/opt/X11/lib/libtk8.6.dylib" || error_exit "Failed to remove symlink for libtk."
    fi
    
    # Uninstall dependencies installed by Homebrew
    echo "Uninstalling Homebrew dependencies..."
    for pkg in cairo ngspice libxpm macvim dbus jpeg gtk+3 pango autoconf automake libtool pkg-config at-spi2-core; do
        if brew list --formula | grep -q "^$pkg\$"; then
            echo "Uninstalling $pkg..."
            brew uninstall --ignore-dependencies "$pkg" || error_exit "Failed to uninstall $pkg."
        else
            echo "$pkg is not installed, skipping..."
        fi
    done
    
    # Remove specific directories if they exist
    echo "Removing specific directories..."
    rm -rf /usr/local/etc/openssl@3
    rm -rf /usr/local/etc/ca-certificates
    rm -rf /usr/local/etc/pmix-mca-params.conf
    rm -rf /usr/local/etc/dbus-1
    
    # Uninstall Xquartz
    echo "Uninstalling Xquartz..."
    brew uninstall --cask xquartz || error_exit "Failed to uninstall Xquartz."
    
    # Remove NO_AT_BRIDGE from bashrc or zshrc
    echo "Updating shell configuration..."
    if [ -f ~/.bashrc ]; then
        SHELL_CONFIG=~/.bashrc
    elif [ -f ~/.zshrc ]; then
        SHELL_CONFIG=~/.zshrc
    else
        echo "Neither ~/.bashrc nor ~/.zshrc found. Please remove 'export NO_AT_BRIDGE=1' manually."
    fi
    
    if [ -n "$SHELL_CONFIG" ]; then
        sed -i '' '/export NO_AT_BRIDGE=1/d' "$SHELL_CONFIG"
    fi
    
    # Source the updated shell configuration (do not run as root)
    echo "Sourcing the updated shell configuration..."
    source "$SHELL_CONFIG" || error_exit "Failed to source $SHELL_CONFIG."
    
    
    # REMOVE BeSpice Wave
    # Uninstall Analog Flavor application
    if [ -d "/Applications/Analog Flavor.app" ]; then
        echo "Uninstalling Analog Flavor application..."
        sudo rm -rf "/Applications/Analog Flavor.app" || error_exit "Failed to remove Analog Flavor application."
    fi
    
    if [ -d "~/analog_flavor_eval" ]; then
        sudo rm -rf "~/analog_flavor_eval" || error_exit "Failed to remove Analog Flavor folder."
    fi
    
    
    echo "Uninstallation process completed successfully."

elif [[ "$KERNEL_INFO" == *microsoft* ]]; then
    ########################################################################
    # WSL Installation Script
    ########################################################################
    echo "Detected WSL (Windows Subsystem for Linux)."
    echo "No uninstall yet"

elif [ "$OS_TYPE" == "Linux" ]; then
    ########################################################################
    # Linux Uninstall Script
    ########################################################################
    echo "Detected Linux. Running Linux uninstall script..."

    set -euo pipefail

    #----------------------------------------
    # helper for fatal errors
    error_exit() {
        echo "Error: $1" >&2
        exit 1
    }

    #----------------------------------------
    # must be Linux
    if [[ "$(uname -s)" != "Linux" ]]; then
        error_exit "This uninstall script is for Linux only."
    fi

    #----------------------------------------
    # check sudo
    if ! sudo -n true 2>/dev/null; then
        error_exit "Requires sudo privileges."
    fi

    echo "Removing XSchem binary, Tcl/Tk libs, headers…"
    sudo rm -f /usr/local/bin/xschem
    sudo rm -f /usr/local/bin/wish8.6 /usr/local/bin/tclsh8.6
    sudo rm -rf /usr/local/lib/libtk8.6* /usr/local/lib/libtcl8.6*
    sudo rm -rf /usr/local/include/tk8.6 /usr/local/include/tcl8.6

    echo "Cleaning up any leftover share files…"
    sudo rm -rf /usr/local/share/xschem
    sudo rm -rf /tmp/tcl8.6.13 /tmp/tk8.6.13 /tmp/xschem

    echo "Updating linker cache…"
    sudo ldconfig

    echo "Undoing shell config edits…"
    SHELL_RC=""
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_RC="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_RC="$HOME/.zshrc"
    fi

    if [[ -n "$SHELL_RC" ]]; then
        # Remove our block of exports
        sed -i '/# ---- added by xschem install script ----/,/# -----------------------------------------/d' "$SHELL_RC"
        echo "Removed XSchem exports from $SHELL_RC"
    else
        echo "No ~/.bashrc or ~/.zshrc detected; skipping shell-config cleanup."
    fi

    echo "Uninstalling APT packages that were installed for XSchem…"
    PACKAGES=(
        libx11-dev libxpm-dev libxext-dev libxaw7-dev \
        libxrender-dev libcairo2-dev libjpeg-dev tcl8.6-dev \
        tk8.6-dev libreadline-dev flex bison gawk autoconf \
        automake libtool libtool-bin libx11-xcb-dev ngspice
    )
    sudo apt-get remove --purge -y "${PACKAGES[@]}"
    sudo apt-get autoremove -y

    echo "Uninstall completed successfully."

else
    error_exit "Unsupported operating system. This script supports macOS and Linux only."
fi

#        nautilus
#        gedit
#        x11-apps
#        build-essential
#        flex
#        bison
#        m4
#        tcsh
#        csh
#        libx11-dev
#        tcl-dev
#        tk-dev
#        libcairo2
#        libcairo2-dev
#        libx11-6
#        libxcb1 libx11-xcb-dev libxrender1 libxrender-dev libxpm4 libxpm-dev libncurses-dev
#        blt freeglut3 mesa-common-dev libgl1-mesa-dev libglu1-mesa-dev tcl-tclreadline libgtk-3-dev
#        tcl8.6 tcl8.6-dev tk8.6 tk8.6-dev
#        gawk
#        graphicsmagick
#        vim-gtk3
#        libxaw7
#        libxaw7-dev fontconfig libxft-dev libxft2
#        libxmu6 libxext-dev libxext6 libxrender1
#        libxrender-dev libtool readline-common libreadline-dev gawk autoconf libtool automake adms gettext ruby-dev
#        python3-dev
#        qtmultimedia5-dev
#        libqt5multimediawidgets5 libqt5multimedia5-plugins libqt5multimedia5 libqt5xmlpatterns5-dev
#        python3-pyqt5 qtcreator pyqt5-dev-tools
#        libqt5svg5-dev gcc g++ gfortran
#        make cmake bison flex
#        libfl-dev libfftw3-dev libsuitesparse-dev libblas-dev liblapack-dev libtool autoconf automake libopenmpi-dev
#        openmpi-bin
#        python3-pip
#        python3-venv python3-virtualenv python3-numpy
#        rustc libprotobuf-dev
#        protobuf-compiler
#        libopenmpi-dev
#        gnat
#        gperf
#        liblzma-dev
#        libgtk2.0-dev
#        swig
#        libboost-all-dev
#        wget
#        libwww-curl-perl
#        tig
