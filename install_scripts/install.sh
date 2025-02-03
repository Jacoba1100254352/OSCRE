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
    ########################################################################
    # macOS Installation Script
    ########################################################################
    echo "Detected macOS. Running macOS installation script..."

    # Check if the OS is macOS Big Sur (11) or later
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
    echo "Installing Xquartz..."
    brew install --cask xquartz || error_exit "Failed to install Xquartz."

    # Install required packages
    echo "Installing required packages..."
    brew install cairo ngspice libxpm macvim dbus jpeg || error_exit "Failed to install required packages."
    brew services start dbus

    # PATH EXPORTS
    export LDFLAGS="-L/usr/local/opt/jpeg/lib"
    export CPPFLAGS="-I/usr/local/opt/jpeg/include"

    # Add environment variables to shell configuration
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
    echo "Cleaning up previous Tcl and Tk installations..."
    rm -rf /usr/local/opt/tcl-tk/*

    echo "Compiling Tcl..."
    mkdir -p /usr/local/opt/tcl-tk
    tar -xzf "${INCLUDE_DIR}/tcl8.6.13-src.tar.gz" -C /tmp || error_exit "Failed to extract Tcl."
    cd /tmp/tcl8.6.13/unix || error_exit "Tcl source directory not found."
    ./configure --prefix=/usr/local/opt/tcl-tk || error_exit "Failed to configure Tcl."
    make || error_exit "Failed to make Tcl."
    make install || error_exit "Failed to install Tcl."

    echo "Compiling Tk..."
    tar -xzf "${INCLUDE_DIR}/tk8.6.13-src.tar.gz" -C /tmp || error_exit "Failed to extract Tk."
    cd /tmp/tk8.6.13/unix || error_exit "Tk source directory not found."
    ./configure --prefix=/usr/local/opt/tcl-tk --with-tcl=/usr/local/opt/tcl-tk/lib --with-x --x-includes=/opt/X11/include --x-libraries=/opt/X11/lib || error_exit "Failed to configure Tk."
    make || error_exit "Failed to make Tk."
    make install || error_exit "Failed to install Tk."

    sudo ln -s /usr/local/opt/tcl-tk/lib/libtk8.6.dylib /opt/X11/lib/libtk8.6.dylib || error_exit "Failed to symlink libtk."

    # XSchem
    echo "Cloning XSchem repository..."
    git clone https://github.com/StefanSchippers/xschem.git /tmp/xschem || error_exit "Failed to clone XSchem repository."
    cd /tmp/xschem || error_exit "Failed to navigate to xschem directory."
    git checkout 973d01f || error_exit "Failed to checkout the specific commit for release 3.4.5."

    echo "Configuring XSchem..."
    ./configure --prefix="/Users/$(whoami)/opt/xschem" || error_exit "Failed to configure xschem."

    echo "Modifying Makefile.conf..."
    sed -i.bak 's|CFLAGS=.*|CFLAGS=-std=c99 -I/opt/X11/include -I/opt/X11/include/cairo -I/usr/local/opt/tcl-tk/include -I/usr/local/include -I/usr/local/opt/jpeg/include -O2|' Makefile.conf
    sed -i.bak 's|LDFLAGS=.*|LDFLAGS=-L/opt/X11/lib -L/usr/local/opt/tcl-tk/lib -L/usr/local/lib -L/usr/local/opt/jpeg/lib -lm -lcairo -ljpeg -lX11 -lXrender -lxcb -lxcb-render -lX11-xcb -lXpm -ltcl8.6 -ltk8.6|' Makefile.conf

    echo "Building XSchem..."
    make clean || error_exit "Failed to clean XSchem build."
    make || error_exit "Failed to build XSchem."

    echo "Installing XSchem..."
    make install || error_exit "Failed to install XSchem."

    echo "XSchem installation completed successfully."

    # Be Spice Wave
    echo "Installing BeSpiceWave.app"
    DMG_FILE="include/analog_flavor_eval_osx_2024_06_24.dmg"
    MOUNT_POINT=$(hdiutil attach "$DMG_FILE" | grep "/Volumes/" | awk '{for (i=3; i<=NF; i++) printf "%s ", $i; print ""}' | sed 's/ *$//')

    if [ -z "$MOUNT_POINT" ]; then
        error_exit "Failed to mount DMG file at: $MOUNT_POINT"
    fi

    echo "DMG mounted at: $MOUNT_POINT"
    echo "Contents of $MOUNT_POINT:"
    ls "$MOUNT_POINT"

    APP_PATH="$MOUNT_POINT/BeSpiceWave.app"

    if [ -d "$APP_PATH" ]; then
        cp -R "$APP_PATH" /Applications/ || error_exit "Failed to copy BeSpiceWave.app to /Applications"
    else
        error_exit "BeSpiceWave.app not found in mounted volume."
    fi

    hdiutil detach "$MOUNT_POINT"
    if [ $? -ne 0 ]; then
        error_exit "Failed to unmount DMG file."
    fi

    echo "BeSpice Wave installation completed successfully."

elif [[ "$KERNEL_INFO" == *microsoft* ]]; then
    ########################################################################
    # WSL Installation Script
    ########################################################################
    echo "Detected WSL (Windows Subsystem for Linux)."
    echo "Running WSL installation script..."

    # Update and upgrade
    sudo apt update -y && sudo apt upgrade -y || error_exit "Failed to update/upgrade packages."

    echo "Installing required packages..."
    while read -r p ; do sudo apt-get install -y $p ; done < <(cat << "EOF"
git build-essential libx11-dev libxpm-dev libxaw7-dev
libcairo2-dev libxrender-dev gcc g++ gfortran
make cmake bison flex m4 tcsh csh autoconf automake libtool libreadline-dev
gawk wget libncurses-dev tig pkg-config libjpeg-dev
tcl8.6 tk8.6 tcl8.6-dev tk8.6-dev libgtk-3-dev
EOF
    )

    # Optional: Install x11-apps to test GUI forwarding
    sudo apt-get install -y x11-apps

    # Prompt the user about installing an X server on Windows
    echo "--------------------------------------------------------------------------------"
    echo "WSL Note:"
    echo "  - To run GUI applications (like xschem), you need an X server on Windows."
    echo "  - You can use VcXsrv, Xming, or similar. Once installed and running, set your DISPLAY."
    echo "  - For example, you can add the following lines to your ~/.bashrc (or ~/.zshrc):"
    echo "      export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0"
    echo "      export LIBGL_ALWAYS_INDIRECT=1"
    echo "--------------------------------------------------------------------------------"

    # xschem Installation
    echo "Cloning xschem..."
    git clone https://github.com/StefanSchippers/xschem.git xschem-src || error_exit "Failed to clone xschem."
    cd xschem-src

    echo "Configuring xschem..."
    ./configure || error_exit "Failed to configure xschem."
    echo "Building xschem..."
    sudo make || error_exit "Failed to build xschem."
    echo "Installing xschem..."
    sudo make install || error_exit "Failed to install xschem."
    cd ..

    # NGspice Installation
    echo "Installing NGspice..."
    git clone https://git.code.sf.net/p/ngspice/ngspice ngspice-ngspice || error_exit "Failed to clone ngspice."
    cd ngspice-ngspice

    ./autogen.sh --adms || error_exit "Failed to run autogen.sh for ngspice."
    mkdir release
    cd release
    ../configure --with-x --with-xspice --enable-openmp --enable-adms --with-readline=yes --disable-debug || error_exit "ngspice configure failed."
    sudo make -j4 || error_exit "Failed to compile ngspice."
    sudo make install || error_exit "Failed to install ngspice."

    # Example: copy specialized modeling blocks if needed
    sudo cp -r ../rad_modeling_blocks /usr/local/share || true

    # Add rad_modeling_blocks to the xschem library path
    mkdir -p ~/.xschem
    {
        echo "append XSCHEM_LIBRARY_PATH :/usr/local/share/rad_modeling_blocks"
        echo "append XSCHEM_LIBRARY_PATH :$HOME"
        echo "set XSCHEM_START_WINDOW {/usr/local/share/rad_modeling_blocks/top.sch}"
    } >> ~/.xschem/xschemrc

    echo "WSL installation completed successfully. Remember to run an X server in Windows!"

elif [ "$OS_TYPE" == "Linux" ]; then
    ########################################################################
    # Linux Installation Script
    ########################################################################
    echo "Detected Linux. Running Linux installation script..."

    set -eu -o pipefail

    sudo -n true
    test $? -eq 0 || error_exit "You should have sudo privilege to run this script."

    echo "Installing the must-have pre-requisites..."
    while read -r p ; do sudo apt-get install -y $p ; done < <(cat << "EOF"
git build-essential libx11-dev libxpm-dev libxaw7-dev
libcairo2-dev libxrender-dev gcc g++ gfortran
make cmake bison flex m4 tcsh csh autoconf automake libtool libreadline-dev
gawk wget libncurses-dev tig pkg-config libjpeg-dev
tcl8.6 tk8.6 tcl8.6-dev tk8.6-dev libgtk-3-dev
EOF
    )

    echo "Installing xschem..."
    git clone https://github.com/StefanSchippers/xschem.git xschem-src
    cd xschem-src
    ./configure
    sudo make
    sudo make install
    cd ..

    echo "Installing NGspice..."
    git clone https://git.code.sf.net/p/ngspice/ngspice ngspice-ngspice
    cd ngspice-ngspice
    ./autogen.sh --adms
    mkdir release
    cd release
    ../configure  --with-x --with-xspice --enable-openmp --enable-adms --with-readline=yes --disable-debug
    sudo make -j4
    sudo make install

    # Copy radiation simulation blocks from repository to universal location
    sudo cp -r ../rad_modeling_blocks /usr/local/share || true

    # Add rad_modeling_blocks to the xschem library path
    echo "append XSCHEM_LIBRARY_PATH :/usr/local/share/rad_modeling_blocks" >> ~/.xschem/xschemrc
    echo "append XSCHEM_LIBRARY_PATH :$HOME" >> ~/.xschem/xschemrc
    echo "set XSCHEM_START_WINDOW {/usr/local/share/rad_modeling_blocks/top.sch}" >> ~/.xschem/xschemrc

    echo "Installation completed successfully."

else
    error_exit "Unsupported operating system. This script supports macOS, Linux, and WSL only."
fi

# End of script
