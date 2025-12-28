#!/bin/bash
set -e

# Create bin directory if it doesn't exist
mkdir -p bin

echo "Building examples..."

# Iterate over matching directories in examples/
for dir in examples/*; do
    if [ -d "$dir" ] && [ -f "$dir/main.odin" ]; then
        name=$(basename "$dir")
        echo "Building $name..."
        # Build the example and output to bin/
        odin build "$dir" -out:bin/"$name"
    fi
done

echo "All examples built successfully!"
