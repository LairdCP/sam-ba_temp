#  ----------------------------------------------------------------------------
#          ATMEL Microcontroller Software Support
#  ----------------------------------------------------------------------------
#  Copyright (c) 2012, Atmel Corporation
#
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions are met:
#
#  - Redistributions of source code must retain the above copyright notice,
#  this list of conditions and the disclaimer below.
#
#  Atmel's name may not be used to endorse or promote products derived from
#  this software without specific prior written permission. 
#
#  DISCLAIMER: THIS SOFTWARE IS PROVIDED BY ATMEL "AS IS" AND ANY EXPRESS OR
#  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT ARE
#  DISCLAIMED. IN NO EVENT SHALL ATMEL BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
#  OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
#  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
#  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
#  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#  ----------------------------------------------------------------------------
set cidr_addr 0xFFFFEE40

# *****************************************************************************
#                      CHIP NAME    CHIPID_CIDR
# *****************************************************************************
array set devicesList {
                        at91sama5d3x 0x8a5c07c1
                      }
global target
global commandLineMode
set isValidChipOfBoard 0
set version_mask 0xFFFFFFE0
set chipname_list [array names ::devicesList]
set chip_id [format "0x%08x" [TCL_Read_Int $target(handle) $cidr_addr err_code]]
puts "Read device Chip ID at $cidr_addr --- get $chip_id"
set proc_id_masked [format "0x%08x" [expr $chip_id & $version_mask]]
foreach {key value} [array get devicesList] {
   set masked_chipId_Cidr [format "0x%08x" [expr $value & $version_mask]]
   if {[regexp $proc_id_masked $masked_chipId_Cidr] != 0} {
       puts "-I- Found chip : $key (Chip ID : $chip_id)"
       set isValidChipOfBoard 1
       break
   }
}

if { $isValidChipOfBoard == 0 } {
    if { $commandLineMode == 1 } {
        puts "-E- Invalid device or board!"
    } else {
        tk_messageBox -title "Invalid chip ID" -message "Can't connect $target(board)\n" -icon error -type ok
    }
    TCL_Close $target(handle)
    exit
}

################################################################################
## BOARD SPECIFIC PARAMETERS
################################################################################
namespace eval BOARD {
    variable sramSize         0x20000
    variable maxBootSize      65328
# Default setting for DDRAM
    # Vdd Memory 1.8V = 0 / Vdd Memory 3.3V = 1
    variable extRamVdd 0
    # External SDRAM = 0 / External DDR2 or LPDDR1 = 1 / LPDDR = 2
    variable extRamType 1
    # Set bus width (16 or 32)
    variable extRamDataBusWidth 32
    # DDRAM Model (0: MT47H64M16HR, 1: MT47H128M16RT 2:MT46H16M32LFB5)
    variable extDDRamModel 2

    # Note: DEVICE/ADDRESSES (A2, A1, A0): The A2, A1 or A0 pins are device address inputs 
    # that are hardwired or left not connected for hardware compatibility with other AT24CXX devices.
    # Modify 'eepromDeviceAddress' to meet the hardware connection.
    variable eepromDeviceAddress 0x51
}

set target(board) at91sama5d3x-wb50nbt

# Source procedures for compatibility with older SAM-BA versions
if { [ catch { source "$libPath(extLib)/common/functions.tcl"} errMsg] } {
    if {$commandLineMode == 0} {
        tk_messageBox -title "File not found" -message "Function file not found:\n$errMsg" -type ok -icon error
    } else {
        puts "-E- Function file not found:\n$errMsg"
        puts "-E- Connection abort"
    }
    exit
}

array set memoryAlgo {
    "SRAM"                    "::laird_wb50nbt_sram"
    "DDRAM"                   "::laird_wb50nbt_ddram"
    "SDMMC"                   "::laird_wb50nbt_sdmmc"
    "DataFlash AT45DB/DCB"    "::laird_wb50nbt_dataflash"
    "SerialFlash AT25/AT26"   "::laird_wb50nbt_serialflash"
    "EEPROM AT24"             "::laird_wb50nbt_eeprom"
    "NandFlash"               "::laird_wb50nbt_nandflash"
    "NorFlash"                "::laird_wb50nbt_norflash"
    "OTP"                     "::laird_wb50nbt_otp"
    "One-wire EEPROM"         "::laird_wb50nbt_ow"
    "DDR2 / SDRAM Map"        "::laird_wb50nbt_ddr2_sdram_map"
    "Peripheral"              "::laird_wb50nbt_peripheral"
    "ROM"                     "::laird_wb50nbt_rom"
    "REMAP"                   "::laird_wb50nbt_remap"
}


################################################################################
## Low Level Initialization
################################################################################
if { [ catch { source "$libPath(extLib)/$target(board)/lowlevelinit.tcl"} errMsg] } {
    set continue no
    if {$commandLineMode == 0} {
        set continue [tk_messageBox -title "File not found" -message "Low level initialization file not found.\nContinue anyway ?" -icon warning -type yesno]
    } else {
        puts "-E- Low level initialization file not found."
        puts "-E- Connection abort!"
    }

    if {$continue == no} {
        TCL_Close $target(handle)
        exit
    }
}
LOWLEVEL::Init

################################################################################
## SRAM
################################################################################
array set laird_wb50nbt_sram {
    dftDisplay  1
    dftDefault  0
    dftAddress  0x00300000
    dftSize     0x10000
    dftSend     "RAM::sendFile"
    dftReceive  "RAM::receiveFile"
    dftScripts  ""
}


################################################################################
## DDRAM
################################################################################
array set laird_wb50nbt_ddram {
    dftDisplay  0
    dftDefault  0
    dftAddress  0x20000000
    dftSize     "$GENERIC::memorySize"
    dftSend     "RAM::sendFile"
    dftReceive  "RAM::receiveFile"
    dftScripts  "::laird_wb50nbt_ddram_scripts"
}
if {$BOARD::extRamType == 1 || $BOARD::extRamType == 2} {
    set laird_wb50nbt_ddram(dftDisplay) 1
}

set RAM::appletAddr          0x308000
set RAM::appletMailboxAddr   0x308004
set RAM::appletFileName      "$libPath(extLib)/$target(board)/applet-extram-sama5d3x.bin"
puts "-I- External RAM Settings :  extRamVdd=$BOARD::extRamVdd, extRamType=$BOARD::extRamType, extRamDataBusWidth=$BOARD::extRamDataBusWidth, extDDRamModel=$BOARD::extDDRamModel"

array set laird_wb50nbt_ddram_scripts {
    "Enable DDRAM"   "GENERIC::Init $RAM::appletAddr $RAM::appletMailboxAddr $RAM::appletFileName [list $::target(comType) $::target(traceLevel) $BOARD::extRamVdd $BOARD::extRamType $BOARD::extRamDataBusWidth $BOARD::extDDRamModel]"
    "Enable DDR2"   "GENERIC::Init $RAM::appletAddr $RAM::appletMailboxAddr $RAM::appletFileName [list $::target(comType) $::target(traceLevel) $BOARD::extRamVdd 1 $BOARD::extRamDataBusWidth $BOARD::extDDRamModel]"
    "Enable LPDDR2" "GENERIC::Init $RAM::appletAddr $RAM::appletMailboxAddr $RAM::appletFileName [list $::target(comType) $::target(traceLevel) $BOARD::extRamVdd 2 $BOARD::extRamDataBusWidth $BOARD::extDDRamModel]"
}

# Initialize SDRAM/DDRAM
if {[catch {GENERIC::Init $RAM::appletAddr $RAM::appletMailboxAddr $RAM::appletFileName [list $::target(comType) $::target(traceLevel) $BOARD::extRamVdd $BOARD::extRamType $BOARD::extRamDataBusWidth $BOARD::extDDRamModel]} dummy_err] } {
    set continue no
    if {$commandLineMode == 0} {
        set continue [tk_messageBox -title "External RAM init" -message "External RAM initialization failed.\nExternal RAM access is required to run applets.\nContinue anyway ?" -icon warning -type yesno]
    } else {
        puts "-E- Error during external RAM initialization."
        puts "-E- External RAM access is required to run applets."
        puts "-E- Connection abort"
    }
    # Close link
    if {$continue == no} {
        TCL_Close $target(handle)
        exit
    }
} else {
        puts "-I- External RAM initialized"
}
################################################################################
## DATAFLASH
################################################################################
array set laird_wb50nbt_dataflash {
    dftDisplay  1
    dftDefault  1
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     "GENERIC::SendFile"
    dftReceive  "GENERIC::ReceiveFile"
    dftScripts  "::laird_wb50nbt_dataflash_scripts"
}

array set laird_wb50nbt_dataflash_scripts {
    "Enable Dataflash (SPI0 CS0)"                        "DATAFLASH::Init 0"
    "Set DF in Power-Of-2 Page Size mode (Binary mode)"  "DATAFLASH::BinaryPage"
    "Send Boot File"                                     "GENERIC::SendBootFileGUI"
    "Erase All"                                          "DATAFLASH::EraseAll"
}
set DATAFLASH::appletAddr          0x20000000
set DATAFLASH::appletMailboxAddr   0x20000004
set DATAFLASH::appletFileName      "$libPath(extLib)/$target(board)/applet-dataflash-sama5d3x.bin"

################################################################################
## SERIALFLASH
################################################################################
array set laird_wb50nbt_serialflash {
    dftDisplay  1
    dftDefault  1
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     "GENERIC::SendFile"
    dftReceive  "GENERIC::ReceiveFile"
    dftScripts  "::laird_wb50nbt_serialflash_scripts"
}

array set laird_wb50nbt_serialflash_scripts {
    "Enable Serialflash (SPI0 CS0)"   "SERIALFLASH::Init 0"
    "Send Boot File"                  "GENERIC::SendBootFileGUI"
    "Erase All"                       "SERIALFLASH::EraseAll"
}

set SERIALFLASH::appletAddr          0x20000000
set SERIALFLASH::appletMailboxAddr   0x20000004
set SERIALFLASH::appletFileName      "$libPath(extLib)/$target(board)/applet-serialflash-sama5d3x.bin"

################################################################################
## EEPROM
################################################################################
array set laird_wb50nbt_eeprom {
    dftDisplay  1
    dftDefault  0
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     "GENERIC::SendFile"
    dftReceive  "GENERIC::ReceiveFile"
    dftScripts  "::laird_wb50nbt_eeprom_scripts"
}

array set laird_wb50nbt_eeprom_scripts {
    "Enable EEPROM AT24C01x"          "EEPROM::Init 0 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C02x"          "EEPROM::Init 1 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C04x"          "EEPROM::Init 2 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C08x"          "EEPROM::Init 3 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C16x"          "EEPROM::Init 4 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C32x"          "EEPROM::Init 5 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C64x"          "EEPROM::Init 6 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C128x"         "EEPROM::Init 7 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C256x"         "EEPROM::Init 8 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C512x"         "EEPROM::Init 9 $BOARD::eepromDeviceAddress"
    "Enable EEPROM AT24C1024x"        "EEPROM::Init 10 $BOARD::eepromDeviceAddress"
    "Send Boot File"                  "GENERIC::SendBootFileGUI"
}

set EEPROM::appletAddr          0x308000
set EEPROM::appletMailboxAddr   0x308004
set EEPROM::appletFileName      "$libPath(extLib)/$target(board)/applet-eeprom-sama5d3x.bin"

################################################################################
## One-Wire EEPROM
################################################################################
array set laird_wb50nbt_ow {
    dftDisplay  1
    dftDefault  0
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     "GENERIC::SendFile"
    dftReceive  "GENERIC::ReceiveFile"
    dftScripts  "::laird_wb50nbt_ow_scripts"
}

array set laird_wb50nbt_ow_scripts {
    "Search One-Wire EEPROM"    "OW::Init"
    "Select Target One-Wire EEPROM"   "OW::SelectDevice"
}

set OW::appletAddr          0x308000
set OW::appletMailboxAddr   0x308004
set OW::appletFileName      "$libPath(extLib)/$target(board)/applet-oweeprom-sama5d3x.bin"

################################################################################
## NANDFLASH
################################################################################
array set laird_wb50nbt_nandflash {
    dftDisplay  1
    dftDefault  0
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     "GENERIC::SendFile"
    dftReceive  "GENERIC::ReceiveFile"
    dftScripts  "::laird_wb50nbt_nandflash_scripts"
}

array set laird_wb50nbt_nandflash_scripts {
    "Enable NandFlash"             "NANDFLASH::Init"
    "Pmecc configuration"          "NANDFLASH::NandHeaderValue"
    "Enable OS PMECC parameters"   "NANDFLASH::NandHeaderValue HEADER 0xc0902405"
    "Send Boot File"               "NANDFLASH::SendBootFilePmecc"
    "Erase All"                    "NANDFLASH::EraseAll"
    "Scrub NandFlash"              "NANDFLASH::EraseAll $NANDFLASH::scrubErase"
    "List Bad Blocks"              "NANDFLASH::BadBlockList"
}

set NANDFLASH::appletAddr          0x20000000
set NANDFLASH::appletMailboxAddr   0x20000004
set NANDFLASH::appletFileName      "$libPath(extLib)/$target(board)/applet-nandflash-sama5d3x.bin"


################################################################################
## SDMMC
################################################################################
array set laird_wb50nbt_sdmmc {
    dftDisplay  1
    dftDefault  0
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     "GENERIC::SendFile"
    dftReceive  "GENERIC::ReceiveFile"
    dftScripts  "::laird_wb50nbt_sdmmc_scripts"
}

array set laird_wb50nbt_sdmmc_scripts {
    "Lanuch SDMMC MassStorage "           "SDMMC::Init"
}

set SDMMC::appletAddr          0x20000000
set SDMMC::appletFileName      "$libPath(extLib)/$target(board)/sdmmc-massstorage.bin"

################################################################################
## NORFLASH
################################################################################
array set laird_wb50nbt_norflash {
    dftDisplay  1
    dftDefault  0
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     "GENERIC::SendFile"
    dftReceive  "GENERIC::ReceiveFile"
    dftScripts  "::laird_wb50nbt_norflash_scripts"
}

array set laird_wb50nbt_norflash_scripts {
    "Enable NorFlash "    "NORFLASH::Init"
    "Erase All"           "NORFLASH::EraseAll"
}
set NORFLASH::appletAddr          0x20000000
set NORFLASH::appletMailboxAddr   0x20000004
set NORFLASH::appletFileName      "$libPath(extLib)/$target(board)/applet-norflash-sama5d3x.bin"

################################################################################
## OTP
################################################################################
array set laird_wb50nbt_otp {
    dftDisplay  1
    dftDefault  0
    dftAddress  0x0
    dftSize     "$GENERIC::memorySize"
    dftSend     ""
    dftReceive  ""
    dftScripts  "::laird_wb50nbt_otp_scripts"
}

array set laird_wb50nbt_otp_scripts {
    "Enable OTP"                   "OTP::Init"
    "OTP Read all"                 "OTP::Read"
    "OTP Fuse "                    "OTP::FuseIF $OTP::otpSizeinWord $OTP::otpCfgName"
}

set OTP::appletAddr          0x308000
set OTP::appletMailboxAddr   0x308004
set OTP::appletFileName      "$libPath(extLib)/$target(board)/applet-otp-sama5d3x.bin"

# Don't change these configuration below (See detail in datasheet) !!!
set OTP::otpSizeinWord       8
set OTP::otpCfgName          [list "R" "R" "R" "R" "R" "R" "R" "R"]

array set laird_wb50nbt_ddr2_sdram_map {
    dftDisplay  0
    dftDefault  0
    dftAddress  0x20000000
    dftSize     0x10000000
    dftSend     ""
    dftReceive  ""
    dftScripts  ""
}

array set laird_wb50nbt_norflash_map {
    dftDisplay  0
    dftDefault  0
    dftAddress  0x10000000
    dftSize     0x10000000
    dftSend     ""
    dftReceive  ""
    dftScripts  ""
}
array set laird_wb50nbt_peripheral {
    dftDisplay  0
    dftDefault  0
    dftAddress  0xF0000000
    dftSize     0x10000000
    dftSend     ""
    dftReceive  ""
    dftScripts  ""
}

array set laird_wb50nbt_rom {
    dftDisplay  0
    dftDefault  0
    dftAddress  0x100000
    dftSize     0x8000
    dftSend     ""
    dftReceive  ""
    dftScripts  ""
}

array set laird_wb50nbt_remap {
    dftDisplay  0
    dftDefault  0
    dftAddress  0x00000000
    dftSize     0x8000
    dftSend     ""
    dftReceive  ""
    dftScripts  ""
}

