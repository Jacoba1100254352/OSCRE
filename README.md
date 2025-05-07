# OSCRE

Open-Source Radiation Hardening circuit-level Simulator in conjunction with SCALE

## Introduction

## Installation

source the install script located in `install_scripts`:
```sh
./install.sh
```

Likewise to uninstall, source the uninstall script:
```sh
./uninstall.sh
```

## Instructions and Run examples

Once installed, simply run xschem from the terminal with the following command:
```sh
xschem
```

### How to Use xschem and ngspice Together

1. **Create Schematic in xschem:**
    - Draw your circuit.
    - Save the schematic as `my_circuit.sch`.

2. **Generate the Netlist:**
    - Ensure your schematic is open.
    - Go to `Simulation` > `Set netlist dir`. Set your netlist directory.
    - Go to `Options` > `Netlist format / Symbol mode`. Ensure your saving your netlist as a spice file
    - In the top right, press the button that looks like an arrow pointing to a piece of paper to create the netlist

3. **Simulate with ngspice:**
    - In the terminal, run the simulation while in the directory of the spice file:
      ```sh
      ngspice my_circuit.spice
      ```
    - Save the output to a file (e.g., `ngspice_output.txt`).

## Skywater PDK
The Skywater PDK install scripts have only been completed for MacOS and Linux and may not 
be directly supported in future updates. (Tested with macOS 15 and Linux Mint (Cinnamon)).

## Documentation
**For more thorough directions and documentation, refer to the `Documentation` folder in this repo.**

