#!/bin/bash

sudo_stat=sudo_status.txt
sudo_keep_alive() {
  echo $$ >> $sudo_stat
  trap 'rm -f $sudo_stat >/dev/null 2>&1' 0
  trap "clenup; exit 2" 1 2 3 15
  while [ -f $sudo_stat ]; do
    sudo -v
    sleep 10
  done &
}

setup_tpm2_abrmd() {
  sudo apt update
  sudo apt install tpm2-abrmd -y
  sudo systemctl enable --now tpm2-abrmd
}

setup_dependencies() {
  sudo apt update
  sudo apt install clevis clevis-luks clevis-tpm2 tpm2-tools clevis-initramfs -y
}

setup_luks_for_device() {
    local device=$1
    if [ -z "$device" ]; then
        echo "Device parameter is required"
        exit 1
    fi
    sudo clevis luks bind -d "$device" tpm2 '{"pcr_ids":"7"}'
}

update_initramfs() {
    sudo update-initramfs -u -k all
}

# do not run as root or with sudo
if [ $(id -u) -eq 0 ]; then
  echo "Do not run as root or with sudo"
  exit 1
fi

show_help() {
    printf "Usage: $0 [--stage1 | --stage2]\n"
    printf "  --stage1            Run the first stage of the script\n"
    printf "  --stage2  <device>  Run the second stage of the script, for the device /dev/xxxx\n"
    printf "  --help              Show this help\n"
    printf "\n"
    printf "To get the device name, run 'lsblk' or 'fdisk -l' and look for the encrypted partition\n"
}

if [ $# -eq 0 ]; then
    show_help
    exit 1
fi
sudo -v
sudo_keep_alive

case "$1" in
    --stage1)
        echo "Running stage 1"
        setup_tpm2_abrmd
        setup_dependencies
        sudo usermod -a -G tss $USER
        ;;
    --stage2)
        if [ -z "$2" ]; then
            echo "Device parameter is required"
            exit 1
        fi
        echo "Running stage 2"
        setup_luks_for_device $2
        update_initramfs

        printf "\n Complete\nReboot the system to apply the changes\n"
        ;;
    *)
        show_help
        exit 1
        ;;
esac

