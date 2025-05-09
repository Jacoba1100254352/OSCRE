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

    # Variables for paths
    BASE_DIR=$(pwd)
    INCLUDE_DIR="${BASE_DIR}/include"
    INSTALL_SCRIPTS_DIR="${BASE_DIR}/Install Scripts"

    # Check if the required tar.gz files exist
    if [ ! -f "${INCLUDE_DIR}/tcl8.6.13-src.tar.gz" ]; then
        error_exit "Tcl source file not found at ${INCLUDE_DIR}/tcl8.6.13-src.tar.gz"
    fi

    if [ ! -f "${INCLUDE_DIR}/tk8.6.13-src.tar.gz" ]; then
        error_exit "Tk source file not found at ${INCLUDE_DIR}/tk8.6.13-src.tar.gz"
    fi

    # Install Homebrew if not installed
    if ! command -v brew &> /dev/null; then
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error_exit "Failed to install Homebrew."
    fi


    # XQuartz
    # Install Xquartz
    echo "Installing Xquartz..."
    brew install --cask xquartz || error_exit "Failed to install Xquartz."

    # Install required packages
    echo "Installing required packages..."
    brew install cairo ngspice libxpm macvim dbus jpeg || error_exit "Failed to install required packages."
    brew services start dbus


    # PATH EXPORTS
    # Set environment variables for JPEG
    export LDFLAGS="-L/usr/local/opt/jpeg/lib"
    export CPPFLAGS="-I/usr/local/opt/jpeg/include"

    # Add environment variables to shell configuration (do not run as root)
    echo "Updating shell configuration..."
    SHELL_CONFIG=""
    if [ -f ~/.bashrc ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [ -f ~/.zshrc ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    else
        echo "Neither ~/.bashrc nor ~/.zshrc found. The following are being run manually:
        export DYLD_LIBRARY_PATH=\"/usr/local/opt/tcl-tk/lib:/opt/X11/lib\"
        export PATH=\"/Users/$(whoami)/opt/xschem/bin:\$PATH\"
        export DISPLAY=:0"
        # echo "Please add the above line to .bashrc or .zshrc when possible"
        export DYLD_LIBRARY_PATH="/usr/local/opt/tcl-tk/lib:/opt/X11/lib"
        export PATH="/Users/$(whoami)/opt/xschem/bin:$PATH"
        export DISPLAY=:0
    fi

    if [ -n "$SHELL_CONFIG" ]; then
        if ! grep -q 'export DYLD_LIBRARY_PATH="/usr/local/opt/tcl-tk/lib:/opt/X11/lib"' "$SHELL_CONFIG"; then
            echo 'export DYLD_LIBRARY_PATH="/usr/local/opt/tcl-tk/lib:/opt/X11/lib"' >> "$SHELL_CONFIG"
        fi

        if ! grep -q 'export PATH="/Users/$(whoami)/opt/xschem/bin:$PATH"' "$SHELL_CONFIG"; then
            echo 'export PATH="/Users/$(whoami)/opt/xschem/bin:$PATH"' >> "$SHELL_CONFIG"
        fi

        if ! grep -q 'export DISPLAY=:0' "$SHELL_CONFIG"; then
            echo 'export DISPLAY=:0' >> "$SHELL_CONFIG"
        fi

        if ! grep -q 'export DYLD_LIBRARY_PATH=/opt/local/lib/postgresql94:/usr/lib' "$SHELL_CONFIG"; then
            echo 'export DYLD_LIBRARY_PATH=/opt/local/lib/postgresql94:/usr/lib' >> "$SHELL_CONFIG"
        fi
    fi


    # TCL-TK
    # Remove any existing files in /usr/local/opt/tcl-tk
    echo "Cleaning up previous Tcl and Tk installations..."
    rm -rf /usr/local/opt/tcl-tk/*

    # Extract and compile Tcl
    echo "Compiling Tcl..."
    mkdir -p /usr/local/opt/tcl-tk
    tar -xzf "${INCLUDE_DIR}/tcl8.6.13-src.tar.gz" -C /tmp || error_exit "Failed to extract Tcl."
    cd /tmp/tcl8.6.13/unix || error_exit "Tcl source directory not found."
    ./configure --prefix=/usr/local/opt/tcl-tk || error_exit "Failed to configure Tcl."
    make || error_exit "Failed to make Tcl."
    make install || error_exit "Failed to install Tcl."

    # Extract and compile Tk
    echo "Compiling Tk..."
    tar -xzf "${INCLUDE_DIR}/tk8.6.13-src.tar.gz" -C /tmp || error_exit "Failed to extract Tk."
    cd /tmp/tk8.6.13/unix || error_exit "Tk source directory not found."
    ./configure --prefix=/usr/local/opt/tcl-tk --with-tcl=/usr/local/opt/tcl-tk/lib --with-x --x-includes=/opt/X11/include --x-libraries=/opt/X11/lib || error_exit "Failed to configure Tk."
    make || error_exit "Failed to make Tk."
    make install || error_exit "Failed to install Tk."

    # Symlink libtk
    sudo ln -s /usr/local/opt/tcl-tk/lib/libtk8.6.dylib /opt/X11/lib/libtk8.6.dylib || error_exit "Failed to symlink libtk."


    # XSchem
    # Clone XSchem
    echo "Cloning XSchem repository..."
    git clone https://github.com/StefanSchippers/xschem.git /tmp/xschem || error_exit "Failed to clone XSchem repository."
    cd /tmp/xschem || error_exit "Failed to navigate to xschem directory."
    git checkout 973d01f || error_exit "Failed to checkout the specific commit for release 3.4.5."

    # Configure xschem
    echo "Configuring XSchem..."
    ./configure --prefix="/Users/$(whoami)/opt/xschem" || error_exit "Failed to configure xschem."

    # Modify Makefile.conf
    echo "Modifying Makefile.conf..."
    sed -i.bak 's|CFLAGS=.*|CFLAGS=-std=c99 -I/opt/X11/include -I/opt/X11/include/cairo -I/usr/local/opt/tcl-tk/include -I/usr/local/include -I/usr/local/opt/jpeg/include -O2|' Makefile.conf
    sed -i.bak 's|LDFLAGS=.*|LDFLAGS=-L/opt/X11/lib -L/usr/local/opt/tcl-tk/lib -L/usr/local/lib -L/usr/local/opt/jpeg/lib -lm -lcairo -ljpeg -lX11 -lXrender -lxcb -lxcb-render -lX11-xcb -lXpm -ltcl8.6 -ltk8.6|' Makefile.conf

    # Build XSchem
    echo "Building XSchem..."
    make clean || error_exit "Failed to clean XSchem build."
    make || error_exit "Failed to build XSchem."

    # Install XSchem
    echo "Installing XSchem..."
    make install || error_exit "Failed to install XSchem."

    echo "XSchem installation completed successfully."


    # Be Spice Wave
    echo "Installing BeSpiceWave.app"

    # Define the DMG file path
    DMG_FILE="include/analog_flavor_eval_osx_2024_06_24.dmg"

    # Attach the DMG file and get the mount point
    MOUNT_POINT=$(hdiutil attach "$DMG_FILE" | grep "/Volumes/" | awk '{for (i=3; i<=NF; i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

    # Check if the DMG file was mounted successfully
    if [ -z "$MOUNT_POINT" ]; then
        error_exit "Failed to mount DMG file at: $MOUNT_POINT"
    fi

    echo "DMG mounted at: $MOUNT_POINT"

    # List contents of the mounted volume to identify the correct application path
    echo "Contents of $MOUNT_POINT:"
    ls "$MOUNT_POINT"

    # Define the expected paths for the application
    APP_PATH="$MOUNT_POINT/BeSpiceWave.app"

    # Copy the application or files to the Applications folder (or any other desired location)
    if [ -d "$APP_PATH" ]; then
        cp -R "$APP_PATH" /Applications/ || error_exit "Failed to copy BeSpiceWave.app to /Applications"
    else
        error_exit "BeSpiceWave.app not found in mounted volume."
    fi

    # Unmount the DMG file
    hdiutil detach "$MOUNT_POINT"

    # Check if the unmount was successful
    if [ $? -ne 0 ]; then
        error_exit "Failed to unmount DMG file."
    fi

    echo "BeSpice Wave installation completed successfully."

elif [[ "$KERNEL_INFO" == *microsoft* ]]; then
    ########################################################################
    # WSL Installation Script       (Same as Linux)
    ########################################################################
    set -euo pipefail

    #----------------------------------------
    # helper for fatal errors
    error_exit() {
        echo "Error: $1" >&2
        exit 1
    }

    #----------------------------------------
    # 1) detect OS
    OS_TYPE=$(uname -s)
    KERNEL_INFO=$(uname -r)
    if [[ "$OS_TYPE" != "Linux" ]]; then
        error_exit "This script is intended for Linux. Detected: $OS_TYPE"
    fi
    echo "Detected Linux (kernel $KERNEL_INFO)."

    #----------------------------------------
    # 2) ensure sudo
    if ! sudo -n true 2>/dev/null; then
        error_exit "Requires sudo privileges to proceed."
    fi

    #----------------------------------------
    # 3) define paths and check sources
    BASE_DIR=$(pwd)
    INCLUDE_DIR="${BASE_DIR}/include"
    INSTALL_SCRIPTS_DIR="${BASE_DIR}/Install Scripts"

    [[ -f "${INCLUDE_DIR}/tcl8.6.13-src.tar.gz" ]] || \
        error_exit "Missing Tcl archive at ${INCLUDE_DIR}/tcl8.6.13-src.tar.gz"

    [[ -f "${INCLUDE_DIR}/tk8.6.13-src.tar.gz" ]] || \
        error_exit "Missing Tk  archive at ${INCLUDE_DIR}/tk8.6.13-src.tar.gz"

    #----------------------------------------
    # 4) install distro packages
    echo "Installing required packages via apt..."
    sudo apt-get update
    sudo apt-get install -y \
        git build-essential \
        libx11-dev libxpm-dev libxext-dev libxaw7-dev libxrender-dev \
        libcairo2-dev libjpeg-dev \
        tcl8.6-dev tk8.6-dev \
        libreadline-dev flex bison gawk \
        autoconf automake libtool libtool-bin \
        wget curl libx11-xcb-dev xterm ngspice

    #----------------------------------------
    # 5) compile & install Tcl/Tk from source
    TCLTK_PREFIX="/usr/local"
    echo "Installing Tcl/Tk under $TCLTK_PREFIX..."
    sudo rm -rf "$TCLTK_PREFIX/lib/tcl8.6" "$TCLTK_PREFIX/lib/tk8.6"
    sudo mkdir -p "$TCLTK_PREFIX"

    # Tcl
    rm -rf /tmp/tcl8.6.13
    tar -xzf "${INCLUDE_DIR}/tcl8.6.13-src.tar.gz" -C /tmp
    cd /tmp/tcl8.6.13/unix
    ./configure --prefix="$TCLTK_PREFIX" \
        || error_exit "Tcl configure failed."
    make                                                   \
        || error_exit "Tcl make failed."
    sudo make install                                     \
        || error_exit "Tcl install failed."

    # Tk
    rm -rf /tmp/tk8.6.13
    tar -xzf "${INCLUDE_DIR}/tk8.6.13-src.tar.gz" -C /tmp
    cd /tmp/tk8.6.13/unix
    ./configure --prefix="$TCLTK_PREFIX" \
                --with-tcl="$TCLTK_PREFIX/lib" \
                --with-x                    \
                --x-includes=/usr/include/X11 \
                --x-libraries=/usr/lib        \
        || error_exit "Tk configure failed."
    make                                                   \
        || error_exit "Tk make failed."
    sudo make install                                     \
        || error_exit "Tk install failed."

    # refresh linker cache
    sudo ldconfig

    #----------------------------------------
    # 6) update shell config for runtime
    echo "Updating shell configuration..."
    SHELL_CONFIG=""
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_CONFIG="$HOME/.zshrc"
    fi

    ENV_EXPORTS=$(cat <<EOF
# ---- added by xschem install script ----
export LD_LIBRARY_PATH="$TCLTK_PREFIX/lib:\$LD_LIBRARY_PATH"
export PATH="\$HOME/opt/xschem/bin:\$PATH"
export DISPLAY="\${DISPLAY:-:0}"
# -----------------------------------------
EOF
    )

    if [[ -n "$SHELL_CONFIG" ]]; then
        if ! grep -Fq "added by xschem install script" "$SHELL_CONFIG"; then
            echo "$ENV_EXPORTS" >> "$SHELL_CONFIG"
            echo "Appended environment exports to $SHELL_CONFIG."
        else
            echo "Shell config already contains xschem exports; skipping."
        fi
    else
        echo "No ~/.bashrc or ~/.zshrc found. Please add these lines to your shell config:"
        echo "$ENV_EXPORTS"
    fi

    # apply to current session
    if [[ -z "${LD_LIBRARY_PATH:-}" ]]; then
        export LD_LIBRARY_PATH="$TCLTK_PREFIX/lib"
    else
        export LD_LIBRARY_PATH="$TCLTK_PREFIX/lib:$LD_LIBRARY_PATH"
    fi

    export PATH="/usr/local/bin:$PATH"
    export DISPLAY="${DISPLAY:-:0}"


    #----------------------------------------
    # 7) clone, build & install XSchem
    echo "Cloning XSchem..."
    rm -rf /tmp/xschem
    git clone https://github.com/StefanSchippers/xschem.git /tmp/xschem \
        || error_exit "Failed to clone XSchem."
    cd /tmp/xschem
    git checkout 973d01f                                 \
        || error_exit "Failed to checkout commit 973d01f."

    echo "Configuring XSchem..."
    ./configure --prefix="/usr/local"              \
        || error_exit "XSchem configure failed."

    echo "Patching Makefile.conf..."
    sed -i.bak \
    -e 's|CFLAGS=.*|CFLAGS=-std=c99 -I/usr/include/X11 -I/usr/include/cairo -I/usr/local/include -I/usr/include/jpeg -O2|' \
    -e 's|LDFLAGS=.*|LDFLAGS=-L/usr/lib -L/usr/local/lib -lm -lcairo -ljpeg -lX11 -lXrender -lxcb -lxcb-render -lXpm -ltcl8.6 -ltk8.6|' \
    Makefile.conf

    echo "Building XSchem..."
    make clean && make                                   \
        || error_exit "XSchem build failed."

    echo "Installing XSchem..."
    sudo make install                                    \
        || error_exit "XSchem install failed."

    echo "XSchem installation completed!"

    #----------------------------------------
    echo "WSL installation completed successfully. Remember to run an X server in Windows!"
    #----------------------------------------


elif [ "$OS_TYPE" == "Linux" ]; then
    ########################################################################
    # Linux Installation Script
    ########################################################################
    echo "Detected Linux. Running Linux installation script..."

    set -euo pipefail

    #----------------------------------------
    # helper for fatal errors
    error_exit() {
        echo "Error: $1" >&2
        exit 1
    }

    #----------------------------------------
    # 1) detect OS
    OS_TYPE=$(uname -s)
    KERNEL_INFO=$(uname -r)
    if [[ "$OS_TYPE" != "Linux" ]]; then
        error_exit "This script is intended for Linux. Detected: $OS_TYPE"
    fi
    echo "Detected Linux (kernel $KERNEL_INFO)."

    #----------------------------------------
    # 2) ensure sudo
    if ! sudo -n true 2>/dev/null; then
        error_exit "Requires sudo privileges to proceed."
    fi

    #----------------------------------------
    # 3) define paths and check sources
    BASE_DIR=$(pwd)
    INCLUDE_DIR="${BASE_DIR}/include"
    INSTALL_SCRIPTS_DIR="${BASE_DIR}/Install Scripts"

    [[ -f "${INCLUDE_DIR}/tcl8.6.13-src.tar.gz" ]] || \
        error_exit "Missing Tcl archive at ${INCLUDE_DIR}/tcl8.6.13-src.tar.gz"

    [[ -f "${INCLUDE_DIR}/tk8.6.13-src.tar.gz" ]] || \
        error_exit "Missing Tk  archive at ${INCLUDE_DIR}/tk8.6.13-src.tar.gz"

    #----------------------------------------
    # 4) install distro packages
    echo "Installing required packages via apt..."
    sudo apt-get update
    sudo apt-get install -y \
        git build-essential \
        libx11-dev libxpm-dev libxext-dev libxaw7-dev libxrender-dev \
        libcairo2-dev libjpeg-dev \
        tcl8.6-dev tk8.6-dev \
        libreadline-dev flex bison gawk \
        autoconf automake libtool libtool-bin \
        wget curl libx11-xcb-dev xterm ngspice

    #----------------------------------------
    # 5) compile & install Tcl/Tk from source
    TCLTK_PREFIX="/usr/local"
    echo "Installing Tcl/Tk under $TCLTK_PREFIX..."
    sudo rm -rf "$TCLTK_PREFIX/lib/tcl8.6" "$TCLTK_PREFIX/lib/tk8.6"
    sudo mkdir -p "$TCLTK_PREFIX"

    # Tcl
    rm -rf /tmp/tcl8.6.13
    tar -xzf "${INCLUDE_DIR}/tcl8.6.13-src.tar.gz" -C /tmp
    cd /tmp/tcl8.6.13/unix
    ./configure --prefix="$TCLTK_PREFIX" \
        || error_exit "Tcl configure failed."
    make                                                   \
        || error_exit "Tcl make failed."
    sudo make install                                     \
        || error_exit "Tcl install failed."

    # Tk
    rm -rf /tmp/tk8.6.13
    tar -xzf "${INCLUDE_DIR}/tk8.6.13-src.tar.gz" -C /tmp
    cd /tmp/tk8.6.13/unix
    ./configure --prefix="$TCLTK_PREFIX" \
                --with-tcl="$TCLTK_PREFIX/lib" \
                --with-x                    \
                --x-includes=/usr/include/X11 \
                --x-libraries=/usr/lib        \
        || error_exit "Tk configure failed."
    make                                                   \
        || error_exit "Tk make failed."
    sudo make install                                     \
        || error_exit "Tk install failed."

    # refresh linker cache
    sudo ldconfig

    #----------------------------------------
    # 6) update shell config for runtime
    echo "Updating shell configuration..."
    SHELL_CONFIG=""
    if [[ -f "$HOME/.bashrc" ]]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        SHELL_CONFIG="$HOME/.zshrc"
    fi

    ENV_EXPORTS=$(cat <<EOF
# ---- added by xschem install script ----
export LD_LIBRARY_PATH="$TCLTK_PREFIX/lib:\$LD_LIBRARY_PATH"
export PATH="\$HOME/opt/xschem/bin:\$PATH"
export DISPLAY="\${DISPLAY:-:0}"
# -----------------------------------------
EOF
    )

    if [[ -n "$SHELL_CONFIG" ]]; then
        if ! grep -Fq "added by xschem install script" "$SHELL_CONFIG"; then
            echo "$ENV_EXPORTS" >> "$SHELL_CONFIG"
            echo "Appended environment exports to $SHELL_CONFIG."
        else
            echo "Shell config already contains xschem exports; skipping."
        fi
    else
        echo "No ~/.bashrc or ~/.zshrc found. Please add these lines to your shell config:"
        echo "$ENV_EXPORTS"
    fi

    # apply to current session
    if [[ -z "${LD_LIBRARY_PATH:-}" ]]; then
        export LD_LIBRARY_PATH="$TCLTK_PREFIX/lib"
    else
        export LD_LIBRARY_PATH="$TCLTK_PREFIX/lib:$LD_LIBRARY_PATH"
    fi

    export PATH="/usr/local/bin:$PATH"
    export DISPLAY="${DISPLAY:-:0}"


    #----------------------------------------
    # 7) clone, build & install XSchem
    echo "Cloning XSchem..."
    rm -rf /tmp/xschem
    git clone https://github.com/StefanSchippers/xschem.git /tmp/xschem \
        || error_exit "Failed to clone XSchem."
    cd /tmp/xschem
    git checkout 973d01f                                 \
        || error_exit "Failed to checkout commit 973d01f."

    echo "Configuring XSchem..."
    ./configure --prefix="/usr/local"              \
        || error_exit "XSchem configure failed."

    echo "Patching Makefile.conf..."
    sed -i.bak \
    -e 's|CFLAGS=.*|CFLAGS=-std=c99 -I/usr/include/X11 -I/usr/include/cairo -I/usr/local/include -I/usr/include/jpeg -O2|' \
    -e 's|LDFLAGS=.*|LDFLAGS=-L/usr/lib -L/usr/local/lib -lm -lcairo -ljpeg -lX11 -lXrender -lxcb -lxcb-render -lXpm -ltcl8.6 -ltk8.6|' \
    Makefile.conf

    echo "Building XSchem..."
    make clean && make                                   \
        || error_exit "XSchem build failed."

    echo "Installing XSchem..."
    sudo make install                                    \
        || error_exit "XSchem install failed."

    echo "XSchem installation completed!"

    #----------------------------------------
    echo "Installation completed successfully."
    #----------------------------------------

else
    error_exit "Unsupported operating system. This script supports macOS, Linux, and WSL only."
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
