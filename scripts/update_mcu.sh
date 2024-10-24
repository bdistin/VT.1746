#!/usr/bin/env bash

###########################################################################################
### Please set the following paths accordingly.                                         ###
###########################################################################################

### Path to your Klipper folder, by default that is '~/klipper'
klipper_folder=~/klipper

### Path to your Katapult folder, by default that is '~/katapult'
katapult_folder=~/katapult

### Path to your mcu config folder
config_folder=~/printer_data/config/scripts/mcu_configs

### Path to your firmware folder, by default, will be '~/firmware'
firmware_folder=~/firmware

###########################################################################################
### List your MCUs in the following format:                                             ###
###                                                                                     ###
### declare -A mcu0=( # The number after mcu must go in order starting at 0             ###
###    [type]='kraken' # Required                                                       ###
###    [can_address]='5cbcb7c7dc7f' # Optional                                          ###
###    [usb_address]='usb-CanBoot_stm32f446xx_4A0021000651303431333234-if00' # Optional ###
### )                                                                                   ###
###########################################################################################

declare -A mcu0=(
    [type]='sb2209'
    [can_address]='218c30c01781'
)

declare -A mcu1=(
    [type]='kraken'
    [can_address]='d0ff496ea5f3'
    [usb_address]='usb-katapult_stm32h723xx_43000C001551313230353039-if00'
)

declare -A mcu2=(
    [type]='rpi'
)

###########################################################################################
########################### !!! DO NOT EDIT BELOW THIS LINE !!! ###########################
###########################################################################################

declare -n mcu

sudo service klipper stop

mkdir -p $firmware_folder

cd $klipper_folder
git pull --autostash

for mcu in ${!mcu@}; do
  cp -f $config_folder/config.${mcu[type]} $klipper_folder

  echo "---"
  echo "Preparing to build klipper for ${mcu[type]}. Need to open menuconfig, quit, and save to get latest options."
  read -p "Press [Enter] to continue, or [Ctrl+C] to abort"

  make clean KCONFIG_CONFIG="config.${mcu[type]}"
  make menuconfig KCONFIG_CONFIG="config.${mcu[type]}"

  if [[ -n ${mcu[can_address]} ]]; then
    make KCONFIG_CONFIG="config.${mcu[type]}"
    mv $klipper_folder/out/klipper.bin $firmware_folder/${mcu[type]}_klipper.bin

    echo "${mcu[type]} firmware built, please check above for any errors."
    read -p "Press [Enter] to continue flashing, or [Ctrl+C] to abort"

    python3 $katapult_folder/scripts/flash_can.py -i can0 -u ${mcu[can_address]} -f $firmware_folder/${mcu[type]}_klipper.bin

    if [[ -n ${mcu[usb_address]} ]]; then
      echo "We intentionally caused an error on the ${mcu[type]} to boot into the bootloader."
      read -p "Please ignore the errors and Press [Enter] to continue flashing, or [Ctrl+C] to abort"

      python3 $katapult_folder/scripts/flash_can.py -d /dev/serial/by-id/${mcu[usb_address]} -f $firmware_folder/${mcu[type]}_klipper.bin
    fi

    echo "${mcu[type]} firmware flashed, please check above for any errors."
    read -p "Press [Enter] to continue building, or [Ctrl+C] to abort"
  elif [[ "${mcu[type]}" == "rpi" ]]; then
    make flash KCONFIG_CONFIG="config.${mcu[type]}"

    echo "${mcu[type]} firmware flashed, please check above for any errors."
    read -p "Press [Enter] to continue building, or [Ctrl+C] to abort"
  else
    make KCONFIG_CONFIG="config.${mcu[type]}"
    mv $klipper_folder/out/klipper.bin $firmware_folder/${mcu[type]}_klipper.bin

    echo "${mcu[type]} firmware built, please check above for any errors. Firmware is stored here: ${firmware_folder}/${mcu[type]}_klipper.bin and you will need to install it per your board type manually."
    read -p "Press [Enter] to continue, or [Ctrl+C] to abort"
  fi

  cp -f $klipper_folder/config.${mcu[type]} $config_folder
done

sudo service klipper start
