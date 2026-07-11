#!/bin/bash

# Get crop percentage from user via Zenity dialog
CROP_PERCENT=$(zenity --entry \
    --title="Crop Video from Top" \
    --text="Enter crop percentage of height from the top (e.g. 13):" \
    --entry-text="13" \
    --width=400)

# If user cancels or leaves empty
if [ -z "$CROP_PERCENT" ]; then
    zenity --error --text="No percentage entered. Operation cancelled." --width=300
    exit 1
fi

# Validate it's a number
if ! [[ "$CROP_PERCENT" =~ ^[0-9]+$ ]] || [ "$CROP_PERCENT" -lt 0 ] || [ "$CROP_PERCENT" -gt 99 ]; then
    zenity --error --text="Please enter a valid number between 0 and 99." --width=300
    exit 1
fi

# Process each selected file
for f in "$@"; do
    # Skip if not a regular file
    [ -f "$f" ] || continue

    # Get video height
    HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$f")

    if [ -z "$HEIGHT" ]; then
        zenity --warning --text="Could not read height of:\n$f" --width=400
        continue
    fi

    # Calculate pixels to crop
    CROP_PIXELS=$(( HEIGHT * CROP_PERCENT / 100 ))

    # Output filename in the same directory
    OUTFILE="${f%.mp4}_cropped.mp4"

    # Show progress/info
    echo "Cropping ${CROP_PIXELS}px from top of $(basename "$f") → $(basename "$OUTFILE")"

    # Run ffmpeg (crop from top, good quality, fast preset, copy audio)
    ffmpeg -i "$f" \
           -vf "crop=in_w:in_h-${CROP_PIXELS}:0:${CROP_PIXELS}" \
           -crf 18 -preset veryfast -c:a copy \
           -y "$OUTFILE"

    if [ $? -eq 0 ]; then
        echo "✓ Done: $OUTFILE"
    else
        zenity --error --text="Failed to process:\n$(basename "$f")" --width=400
    fi
done

zenity --info --title="Crop Complete" --text="Finished cropping ${CROP_PERCENT}% from the top of selected video(s)." --width=350
