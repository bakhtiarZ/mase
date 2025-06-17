#!/bin/bash

# Set paths
PARENT_DIR="/mnt/ccnas2/bdp/bm920/compute-pool/hls4ml-helper/.scratch"  # <-- Update this to the actual parent dir with latest data dirs
RTL_DIR="/mnt/ccnas2/bdp/bm920/mase/machop/mase_components/neuralConnect/rtl"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="./backups/backup_$TIMESTAMP"

# Step 1: Create timestamped backup directory
mkdir -p "$BACKUP_DIR"

# Step 2: Copy contents of RTL into backup
cp -r "$RTL_DIR"/* "$BACKUP_DIR"/

# Step 3: Delete everything inside RTL except intermediate_buffer.sv
rm -rf "$RTL_DIR"/*
cp /homes/bm920/workspace/compute-pool/source/intermediate_buffer.sv "$RTL_DIR"


# Step 4: Find latest modified directory inside PARENT_DIR
latest_dir=$(find "$PARENT_DIR" -mindepth 1 -maxdepth 1 -type d -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2-)

echo "$latest_dir$"

# Step 5: Copy contents from latest_dir into RTL
cp -r "$latest_dir"/computePoolGen/* "$RTL_DIR"/

echo "Backup stored in $BACKUP_DIR and RTL updated from $latest_dir"
