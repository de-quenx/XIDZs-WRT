#!/bin/bash

. ./scripts/INCLUDE.sh

rename_firmware() {
    echo -e "${STEPS} Renaming firmware files..."

    # Validasi direktori firmware
    local firmware_dir="$GITHUB_WORKSPACE/$WORKING_DIR/compiled_images"
    if [[ ! -d "$firmware_dir" ]]; then
        error_msg "Invalid firmware directory: ${firmware_dir}"
    fi

    # Pindah ke direktori firmware
    cd "${firmware_dir}" || {
       error_msg "Failed to change directory to ${firmware_dir}"
    }

    # Pola pencarian dan penggantian
    local search_replace_patterns=(
        # Format: "search|replace"

        # bcm27xx
        "-bcm27xx-bcm2709-rpi-2-ext4-factory|Broadcom_RaspberryPi_2B-Ext4_Factory"
        "-bcm27xx-bcm2709-rpi-2-ext4-sysupgrade|Broadcom_RaspberryPi_2B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2709-rpi-2-squashfs-factory|Broadcom_RaspberryPi_2B-Squashfs_Factory"
        "-bcm27xx-bcm2709-rpi-2-squashfs-sysupgrade|Broadcom_RaspberryPi_2B-Squashfs_Sysupgrade"
        
        "-bcm27xx-bcm2710-rpi-3-ext4-factory|Broadcom_RaspberryPi_3B-Ext4_Factory"
        "-bcm27xx-bcm2710-rpi-3-ext4-sysupgrade|Broadcom_RaspberryPi_3B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2710-rpi-3-squashfs-factory|Broadcom_RaspberryPi_3B-Squashfs_Factory"
        "-bcm27xx-bcm2710-rpi-3-squashfs-sysupgrade|Broadcom_RaspberryPi_3B-Squashfs_Sysupgrade"

        "-bcm27xx-bcm2711-rpi-4-ext4-factory|Broadcom_RaspberryPi_4B-Ext4_Factory"
        "-bcm27xx-bcm2711-rpi-4-ext4-sysupgrade|Broadcom_RaspberryPi_4B-Ext4_Sysupgrade"
        "-bcm27xx-bcm2711-rpi-4-squashfs-factory|Broadcom_RaspberryPi_4B-Squashfs_Factory"
        "-bcm27xx-bcm2711-rpi-4-squashfs-sysupgrade|Broadcom_RaspberryPi_4B-Squashfs_Sysupgrade"
        
        "-bcm27xx-bcm2712-rpi-5-ext4-factory|Broadcom_RaspberryPi_5-Ext4_Factory"
        "-bcm27xx-bcm2712-rpi-5-ext4-sysupgrade|Broadcom_RaspberryPi_5-Ext4_Sysupgrade"
        "-bcm27xx-bcm2712-rpi-5-squashfs-factory|Broadcom_RaspberryPi_5-Squashfs_Factory"
        "-bcm27xx-bcm2712-rpi-5-squashfs-sysupgrade|Broadcom_RaspberryPi_5-Squashfs_Sysupgrade"
        
        # Allwinner ULO
        "-h5-orangepi-pc2-|Allwinner_OrangePi_PC2"
        "-h5-orangepi-prime-|Allwinner_OrangePi_Prime"
        "-h5-orangepi-zeroplus-|Allwinner_OrangePi_ZeroPlus"
        "-h5-orangepi-zeroplus2-|Allwinner_OrangePi_ZeroPlus2"
        "-h6-orangepi-1plus-|Allwinner_OrangePi_1Plus"
        "-h6-orangepi-3-|Allwinner_OrangePi_3"
        "-h6-orangepi-3lts-|Allwinner_OrangePi_3LTS"
        "-h6-orangepi-lite2-|Allwinner_OrangePi_Lite2"
        "-h616-orangepi-zero2-|Allwinner_OrangePi_Zero2"
        "-h618-orangepi-zero2w-|Allwinner_OrangePi_Zero2W"
        "-h618-orangepi-zero3-|Allwinner_OrangePi_Zero3"
        
        # Rockchip ULO
        "-rk3566-orangepi-3b-|Rockchip_OrangePi_3B"
        "-rk3588s-orangepi-5-|Rockchip_OrangePi_5"
        "-firefly_roc-rk3328-cc-|Firefly-RK3328"
        
        # Xunlong Official
        "-xunlong_orangepi-r1-plus-lts-squashfs-sysupgrade|Orangepi-R1-Plus-LTS-squashfs-sysupgrade"
        "-xunlong_orangepi-r1-plus-lts-ext4-sysupgrade|Orangepi-R1-Plus-LTS-ext4-sysupgrade"
        "-xunlong_orangepi-r1-plus-squashfs-sysupgrade|Orangepi-R1-Plus-squashfs-sysupgrade"
        "-xunlong_orangepi-r1-plus-ext4-sysupgrade|Orangepi-R1-Plus-ext4-sysupgrade" 
        "-xunlong_orangepi-pc2-squashfs-sdcard|Orangepi-Pc2-squashfs-sdcard"
        "-xunlong_orangepi-pc2-ext4-sdcard|Orangepi-Pc2-ext4-sdcard"
        "-xunlong_orangepi-zero-plus-squashfs-sdcard|Orangepi-Zero-Plus-squashfs-sdcard"
        "-xunlong_orangepi-zero-plus-ext4-sdcard|Orangepi-Zero-Plus-ext4-sdcard"
        "-xunlong_orangepi-zero2-squashfs-sdcard|Orangepi-Zero2-squashfs-sdcard"
        "-xunlong_orangepi-zero2-ext4-sdcard|Orangepi-Zero2-ext4-sdcard"   
        "-xunlong_orangepi-zero3-squashfs-sdcard|Orangepi-Zero3-squashfs-sdcard"
        "-xunlong_orangepi-zero3-ext4-sdcard|Orangepi-Zero3-ext4-sdcard"
        
        # friendlyarm Official
        "-friendlyarm_nanopi-r2c-ext4-sysupgrade|Friendlyarm_Nanopi-R2C-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2c-plus-ext4-sysupgrade|Friendlyarm_Nanopi-R2C-Plus-ext4-sysupgrade"
        "-friendlyarm_nanopi-r2s-ext4-sysupgrade|Friendlyarm_Nanopi-R2S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r3s-ext4-sysupgrade|Friendlyarm_Nanopi-R3S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r4s-ext4-sysupgrade|Friendlyarm_Nanopi-R4S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r5s-ext4-sysupgrade|Friendlyarm_Nanopi-R5S-ext4-sysupgrade"
        "-friendlyarm_nanopi-r6s-ext4-sysupgrade|Friendlyarm_Nanopi-R6S-ext4-sysupgrade"
        "-friendlyarm_nanopi-neo2-ext4-sysupgrade|Friendlyarm_Nanopi-Neo2-ext4-sysupgrade"
        "-friendlyarm_nanopi-neo-plus2-ext4-sysupgrade|Friendlyarm_Nanopi-Neo-Plus2-ext4-sysupgrade"
        "-friendlyarm_nanopi-r1s-h5-ext4-sysupgrade|Friendlyarm_Nanopi-R1-H5-ext4-sysupgrade"
        "-firefly_roc-rk3328-cc-ext4-sysupgrade|Firefly_Roc-RK3328-CC-ext4-sysupgrade"
        
        "-firefly_roc-rk3328-cc-squashfs-sysupgrade|Firefly_Roc-RK3328-CC-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2c-squashfs-sysupgrade|Friendlyarm_Nanopi-R2C-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2c-plus-squashfs-sysupgrade|Friendlyarm_Nanopi-R2C-Plus-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r2s-squashfs-sysupgrade|Friendlyarm_Nanopi-R2S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r3s-squashfs-sysupgrade|Friendlyarm_Nanopi-R3S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r4s-squashfs-sysupgrade|Friendlyarm_Nanopi-R4S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r5s-squashfs-sysupgrade|Friendlyarm_Nanopi-R5S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r6s-squashfs-sysupgrade|Friendlyarm_Nanopi-R6S-squashfs-sysupgrade"
        "-friendlyarm_nanopi-neo2-squashfs-sysupgrade|Friendlyarm_Nanopi-Neo2-squashfs-sysupgrade"
        "-friendlyarm_nanopi-neo-plus2-squashfs-sysupgrade|Friendlyarm_Nanopi-Neo-Plus2-squashfs-sysupgrade"
        "-friendlyarm_nanopi-r1s-h5-squashfs-sysupgrade|Friendlyarm_Nanopi-R1S-H5-squashfs-sysupgrade"
         
        # Amlogic ULO
        "-s905x-b860h-|Amlogic-s905x-B860H"
        "-s905x-hg680p-|Amlogic-s905x-HG680P"
        "-s905x2-b860hv5-|Amlogic-s905x2-B860Hv5"
        "-s905x2-hg680-fj-|Amlogic-s905x2-HG680-FJ"
        "-s905x3-|Amlogic-s905x3"
        "-s905x4-|Amlogic-s905x4"
        
        # Amlogic Ophub
        "_s905x_|Amlogic_s905x_HG680P"
        "_s905x-b860h_|Amlogic_s905x_B860H"
        "_s905d_|Amlogic s905d Phicomm-N1"
        "_s905l-mg101_|Amlogic s905l Mibox-4"
        "_s905l_|Amlogic s905l B860AV2"
        "_s905l2_|Amlogic s905l2 M301A"
        "_s905l3_|Amlogic s905l3 HG680-LC"
        "_s905l3b-e900v22e_|Amlogic s905l3b MGV2000"
        "_s905lb-q96-mini_|Amlogic s905lb Q96-mini"
        "_s905l3a-m401a_|Amlogic s905l3a B863AV3"
        "_s905-mxqpro-plus_|Amlogic s905 MXQ-Pro+"
        "_s922x-gtking_|Amlogic_s922x_GtKing"
        "_s922x_|Amlogic_s922x_GtKing-Pro"
        "_s922x-gtkingpro-h_|Amlogic_s922x_GtKing-Pro-H"
        "_s922x-ugoos-am6_|Amlogic_s922x_UGOOS-AM6-Plus"
        "_s912-nexbox-a1_|Amlogic_s912_Nexbox-A1-A95X"
        "_s912-nexbox-a2_|Amlogic_s912_Nexbox-A95X-A2"
        "_s905l2_|Amlogic_s905l2_MGV_M301A"
        "_s905x2-x96max-2g_|Amlogic_s905x2-x96Max2Gb-A95X-F2"
        "_s905x2_|Amlogic_s905x2_x96Max-4Gb-Tx5-Max"
        "_s905x2-b860h-v5_|Amlogic_s905x2_B860Hv5"
        "_s905x2-hg680-fj_|Amlogic_s905x2_HG680-FJ"
        "_s905x3-x96air_|Amlogic_s905x3-X96Air100M"
        "_s905x3-x96air-gb_|Amlogic_s905x3-x96Air1Gbps"
        "_s905x3-hk1_|Amlogic_s905x3-HK1BOX"
        "_s905x3_|Amlogic_s905x3_X96MAX+_100Mb"
        "_s905x3-x96max_|Amlogic_s905x3_X96MAX+_1Gb"
        "_s905x3-a95xf3-gb_|Amlogic_s905x3_A95xF3-1Gb"
        "_s905x3-a95xf3_|Amlogic_s905x3_A95xF3-100M"
        "_s905x3-x88-pro-x3_|Amlogic_s905x3_X88-Pro-X3"
        "_s905x4-advan_|Amlogic_s905x4_Advan"
        "_s905w_|Amlogic_s905w_TX3_Mini"
        "_s905w-x96-mini_|Amlogic_s905w-X96-Mini"
        
        # Allwinner Ophub
        "_allwinner_orangepi-3_|Orangepi_3"
        "_allwinner_orangepi-zplus_|Orangepi_ZeroPlus"
        "_allwinner_orangepi-zplus2_|Orangepi_Zero_Plus2"
        "_allwinner_orangepi-zero2_|Orangepi_Zero2"
        "_allwinner_orangepi-zero3_|Orangepi_Zero_3"
        
        # RK3318 Ophub
        "_rk3318-box_|RK3318-Box"
        # RK3328 Ophub
        "_renegade-rk3328_|Renegade_Firefly-RK3328"
        
        # friendlyarm Ophub
        "_nanopi-r5s_|Nanopi-r5s"
        "_nanopi-r5c_|Nanopi-r5c"
        
        # x86_64 Official
        "x86-64-generic-ext4-combined-efi|X86_64_Generic_Ext4_Combined_EFI"
        "x86-64-generic-ext4-combined|X86_64_Generic_Ext4_Combined"
        "x86-64-generic-ext4-rootfs|X86_64_Generic_Ext4_Rootfs"
        "x86-64-generic-squashfs-combined-efi|X86_64_Generic_Squashfs_Combined_EFI"
        "x86-64-generic-squashfs-combined|X86_64_Generic_Squashfs_Combined"
        "x86-64-generic-squashfs-rootfs|X86_64_Generic_Squashfs_Rootfs"
        "x86-64-generic-rootfs|X86_64_Generic_Rootfs"
    )

   for pattern in "${search_replace_patterns[@]}"; do
        local search="${pattern%%|*}"
        local replace="${pattern##*|}"

        for file in *"${search}"*.img.gz; do
            if [[ -f "$file" ]]; then
                local kernel=""
                if [[ "$file" =~ k[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9-]+)? ]]; then
                    kernel="${BASH_REMATCH[0]}"
                fi
                local new_name
                if [[ -n "$kernel" ]]; then
                    new_name="${OP_BASE}-${BRANCH}-${replace}-${kernel}-${TUNNEL}_Builds_By_Xidz-X.img.gz"
                else
                    new_name="${OP_BASE}-${BRANCH}-${replace}-${TUNNEL}_Builds_By_Xidz-X.img.gz"
                fi
                echo -e "${INFO} Renaming: $file → $new_name"
                mv "$file" "$new_name" || {
                    echo -e "${WARN} Failed to rename $file"
                    continue
                }
            fi
        done
        for file in *"${search}"*.tar.gz; do
            if [[ -f "$file" ]]; then
                local new_name
                new_name="${OP_BASE}-${BRANCH}-${replace}-${TUNNEL}_Builds_By_Xidz-X.img.gz"
                echo -e "${INFO} Renaming: $file → $new_name"
                mv "$file" "$new_name" || {
                    echo -e "${WARN} Failed to rename $file"
                    continue
                }
            fi
        done
    done

    sync && sleep 3
    echo -e "${INFO} Rename operation completed."
}

rename_firmware
