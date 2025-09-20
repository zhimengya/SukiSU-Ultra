#!/bin/sh
set -eu

KERNEL_ROOT=$(pwd)

display_usage() {
    echo "Usage: $0 [--cleanup | <commit-or-tag>]"
    echo "  --cleanup:              Cleans up previous modifications made by the script."
    echo "  <commit-or-tag>:        Sets up or updates the KernelSU to specified tag or commit."
    echo "  -h, --help:             Displays this usage information."
    echo "  (no args):              Sets up or updates the KernelSU environment to the latest tagged version."
}

initialize_variables() {
    if test -d "$KERNEL_ROOT/common/drivers"; then
         DRIVER_DIR="$KERNEL_ROOT/common/drivers"
    elif test -d "$KERNEL_ROOT/drivers"; then
         DRIVER_DIR="$KERNEL_ROOT/drivers"
    else
         echo '[ERROR] "drivers/" directory not found.'
         exit 127
    fi

    DRIVER_MAKEFILE=$DRIVER_DIR/Makefile
    DRIVER_KCONFIG=$DRIVER_DIR/Kconfig
}

# Reverts modifications made by this script
perform_cleanup() {
    echo "[+] Cleaning up..."
    [ -L "$DRIVER_DIR/kernelsu" ] && rm "$DRIVER_DIR/kernelsu" && echo "[-] Symlink removed."
    grep -q "kernelsu" "$DRIVER_MAKEFILE" && sed -i '/kernelsu/d' "$DRIVER_MAKEFILE" && echo "[-] Makefile reverted."
    grep -q "kernelsu" "$DRIVER_KCONFIG" && sed -i '/kernelsu/d' "$DRIVER_KCONFIG" && echo "[-] Kconfig reverted."
    if [ -d "$KERNEL_ROOT/KernelSU" ]; then
        rm -rf "$KERNEL_ROOT/KernelSU" && echo "[-] KernelSU directory deleted."
    fi
}

# Sets up or update KernelSU environment
setup_kernelsu() {
    echo "[+] Setting up KernelSU..."
    # Clone the repository
    if [ ! -d "$KERNEL_ROOT/KernelSU" ]; then
        git clone https://gitclone.com/github.com/SukiSU-Ultra/SukiSU-Ultra KernelSU
        echo "[+] Repository cloned."
    fi
    cd "$KERNEL_ROOT/KernelSU"
    git stash && echo "[-] Stashed current changes."
    if [ "$(git status | grep -Po 'v\d+(\.\d+)*' | head -n1)" ]; then
        git checkout main && echo "[-] Switched to main branch."
    fi
    git pull && echo "[+] Repository updated."
    if [ -z "${1-}" ]; then
        git checkout "$(git describe --abbrev=0 --tags)" && echo "[-] Checked out latest tag."
    else
        git checkout "$1" && echo "[-] Checked out $1." || echo "[-] Checkout default branch"
    fi
    cd "$DRIVER_DIR"
    ln -sf "$(realpath --relative-to="$DRIVER_DIR" "$KERNEL_ROOT/KernelSU/kernel")" "kernelsu" && echo "[+] Symlink created."

    # Add entries in Makefile and Kconfig if not already existing
    grep -q "kernelsu" "$DRIVER_MAKEFILE" || echo 'obj-$(CONFIG_KSU) += kernelsu/' >> "$DRIVER_MAKEFILE" && echo "[+] Modified Makefile."
    grep -q 'source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" || sed -i '/endmenu/i\source "drivers/kernelsu/Kconfig"' "$DRIVER_KCONFIG" && echo "[+] Modified Kconfig."
    echo '[+] Done.'
}

# Process command-line arguments
if [ "$#" -eq 0 ]; then
    initialize_variables
    setup_kernelsu
elif [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    display_usage
elif [ "$1" = "--cleanup" ]; then
    initialize_variables
    perform_cleanup
else
    initialize_variables
    setup_kernelsu "$@"
fi
