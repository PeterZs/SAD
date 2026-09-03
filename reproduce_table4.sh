#!/usr/bin/env bash
set -euo pipefail

# Reproduce the SAD PSNR entry from Table 4 on the 24-image Kodak suite.

if [ "$#" -ne 0 ]; then
    echo "Usage: ./reproduce_table4.sh" >&2
    echo "This reproduction script takes no arguments." >&2
    exit 2
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="$ROOT_DIR/results/reproduction/table4/kodak"
OUT_DIR="$ROOT_DIR/results/reproduction/table4/outputs"
SUMMARY_PATH="$ROOT_DIR/results/reproduction/table4/table4_sad_psnr.txt"
BACKEND="${SAD_REPRO_BACKEND:-auto}"

mkdir -p "$DATA_DIR" "$OUT_DIR"

echo "Preparing the 24 Kodak images used in Table 4..."
for image_index in $(seq 1 24); do
    printf -v image_id "%02d" "$image_index"
    image_path="$DATA_DIR/kodim${image_id}.png"
    if [ ! -s "$image_path" ]; then
        download_path="${image_path}.download"
        curl -fsSL --retry 3 \
            "https://r0k.us/graphics/kodak/kodak/kodim${image_id}.png" \
            -o "$download_path"
        mv "$download_path" "$image_path"
    fi
done

echo "Training SAD at the Table 4 rate (16.0 BPP) with backend: $BACKEND"
"$ROOT_DIR/run.sh" "$DATA_DIR" \
    --backend "$BACKEND" \
    --target-bpp 16.0 \
    --out-dir "$OUT_DIR"

batch_log="$(find "$OUT_DIR" -maxdepth 1 -type f -name 'batch_*.log' -print | sort | tail -n 1)"
if [ -z "$batch_log" ]; then
    echo "Could not find the batch log in $OUT_DIR" >&2
    exit 1
fi

awk '
    /^PSNR: / {
        sum += $2
        count += 1
    }
    END {
        if (count != 24) {
            printf "Expected 24 PSNR values, found %d.\n", count > "/dev/stderr"
            exit 1
        }
        printf "Table 4 SAD PSNR (24-image mean): %.2f dB\n", sum / count
        printf "Paper value: 46.00 dB\n"
    }
' "$batch_log" | tee "$SUMMARY_PATH"

echo "Reconstructions and site files: $OUT_DIR"
echo "Summary: $SUMMARY_PATH"
