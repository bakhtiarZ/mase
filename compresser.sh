#!/bin/bash

# Specify the directory containing the files
directory="/scratch/bm920/forkmase/mase/activ_maps"

# Specify the path to your C binary
binary="/scratch/bm920/forkmase/CompressedLUT/compressedlut"

# Check if the directory exists
if [ ! -d "$directory" ]; then
    echo "Directory $directory does not exist."
    exit 1
fi

# Check if the binary exists
if [ ! -x "$binary" ]; then
    echo "Binary $binary does not exist or is not executable."
    exit 1
fi

# Loop through each file in the directory
for file in "$directory"/*; do
    # Check if the file is a regular file
    if [ -f "$file" ]; then
        echo "Processing file: $file"
        # Run the binary on the file
        "$binary" "$file"
    fi
done

echo "Processing complete."

