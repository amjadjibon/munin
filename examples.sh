#!/bin/bash
set -e

# Create bin directory if it doesn't exist
mkdir -p bin

# Optimization level. Odin defaults to -o:minimal, which leaves a lot of
# per-frame rendering performance on the table. Override with e.g.
#   ODIN_OPT=-o:none ./examples.sh
ODIN_OPT="${ODIN_OPT:--o:speed}"

echo "Building examples..."

build_example() {
    local dir="$1"
    local name="$2"
    local out="bin/$name"
    local attempts=3
    local attempt=1

    while [ "$attempt" -le "$attempts" ]; do
        local tmp_out="${out}.$$.$attempt.tmp"

        if odin build "$dir" $ODIN_OPT -out:"$tmp_out"; then
            mv "$tmp_out" "$out"
            return 0
        fi

        local status=$?
        rm -f "$tmp_out"

        if [ "$attempt" -eq "$attempts" ]; then
            return "$status"
        fi

        echo "Build failed for $name (attempt $attempt/$attempts), retrying..."
        attempt=$((attempt + 1))
        sleep 0.2
    done
}

# Iterate over matching directories in examples/
for dir in examples/*; do
    if [ -d "$dir" ] && [ -f "$dir/main.odin" ]; then
        name=$(basename "$dir")
        echo "Building $name..."
        # Build the example and output to bin/
        build_example "$dir" "$name"
    fi
done

echo "All examples built successfully!"
