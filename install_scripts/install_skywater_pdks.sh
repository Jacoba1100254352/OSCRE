#!/bin/bash

# Function to print an error message and exit
function error_exit {
    echo "$1" 1>&2
    exit 1
}

# Detect the operating system
OS_TYPE=$(uname)
KERNEL_INFO=$(uname -r)

if [ "$OS_TYPE" == "Darwin" ]; then
    # macOS Installation Script
    echo "Detected macOS. Running macOS installation script..."

    # Check if the OS is macOS Big Sur or later
    OS_VERSION=$(sw_vers -productVersion)
    MAJOR_VERSION=$(echo "$OS_VERSION" | cut -d'.' -f1)

    if [ "$MAJOR_VERSION" -lt 11 ]; then
        error_exit "This script requires macOS Big Sur (11) or later. You are running macOS $OS_VERSION."
    fi
    
    
    # PYENV (create and activate)
    python3.12 -m venv ~/my_venv_pdk_rad_hard
    source ~/my_venv_pdk_rad_hard/bin/activate
    pip install --upgrade pip
    pip install setuptools


    # MAGIC
    echo "Installing Magic (a prerequisit for the PDKs)"
    git clone https://github.com/RTimothyEdwards/magic
    cd magic
    brew install cairo tcl-tk python3
    brew install --cask xquartz
    ./scripts/configure_mac
    make database/database.h
    make -j$(sysctl -n hw.ncpu)
    sudo make install # may need sudo depending on your setup
    cd ..


    # OPEN PDK
    echo "Installing OPEN PDK..."
    git clone https://github.com/RTimothyEdwards/open_pdks
    cd open_pdks

    ./configure --enable-sky130-pdk --enable-sram-sky130
    make
    sudo make install
    make veryclean
    
    
    # Creating simlinks for PDKs
    # Directory containing the source files and directories
    SOURCE_DIR="./open_pdks/sources"
    
    # Target directory for the symbolic links
    TARGET_DIR="/usr/local/share"
    
    # Symlink each directory in the source directory to the target directory
    for dir in $SOURCE_DIR/*; do
        # Extract just the directory name
        dir_name=$(basename "$dir")
        
        # Create symlink in target directory pointing to the source directory
        ln -s "$PWD/$dir" "$TARGET_DIR/$dir_name"
    done
    
    echo "Symbolic links created successfully."
    
    
    # PYENV (deactivate)
    deactivate
    rm -rf ~/my_venv_pdk_rad_hard

elif [[ "$KERNEL_INFO" == *microsoft* ]]; then
    sudo apt update
    sudo apt upgrade
    
    
    
elif [ "$OS_TYPE" == "Linux" ]; then
    ########################################################################
    # Linux Installation Script
    ########################################################################
    echo "Detected Linux. Running Linux installation script..."

    set -eu -o pipefail # fail on error and report it, debug all lines

    sudo -n true    # Run as a superuser and do not ask for a password. Exit status as successful.
    test $? -eq 0 || error_exit "you should have sudo privilege to run this script"

    echo "installing the must-have pre-requisites"
    while read -r p ; do sudo apt-get install -y $p ; done < <(cat << "EOF"
        git build-essential flex bison m4 tcsh csh
        libx11-dev tcl-dev tk-dev libcairo2 libcairo2-dev
        libxcb1 libx11-xcb-dev libxrender1 libxrender-dev libxpm4 libxpm-dev libncurses-dev
        gawk libtool readline-common libreadline-dev autoconf automake
        gcc g++ gfortran make cmake libfl-dev wget tig
EOF
    )

    # MAGIC
    echo "Installing MAGIC..."
    git clone https://github.com/RTimothyEdwards/magic
    cd magic

    ./configure
    sudo make
    sudo make install
    cd ..

    # OPEN PDK
    echo "Installing OPEN PDK..."
    git clone https://github.com/RTimothyEdwards/open_pdks
    cd open_pdks

    ./configure
    sudo make
    sudo make install

    ./configure --enable-sky130-pdk --enable-sram-sky130
    sudo make -j2
    sudo make install

#    ./configure --enable-sky130-pdk --enable-sram-sky130
#    make
#    sudo make install
#    make veryclean

    echo "Installation completed successfully."
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
