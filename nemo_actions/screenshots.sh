#!/bin/bash

# The file selected in Nemo
FILEPATH="$1"
BASENAME=$(basename "$FILEPATH")
NAME="${BASENAME%.*}"

# Ask user for number of screenshots
COUNT=$(zenity --entry \
    --title="Video Screenshots" \
    --text="How many equally spaced screenshots do you want?" \
    --entry-text="5")

[ $? -ne 0 ] && exit 0

if ! [[ "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ]; then
    zenity --error --text="Please enter a valid positive number."
    exit 1
fi

# Get video duration in seconds (float)
DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILEPATH")

if [ -z "$DURATION" ]; then
    zenity --error --text="Could not read video duration."
    exit 1
fi

# Compute interval
INTERVAL=$(echo "$DURATION / ($COUNT + 1)" | bc -l)

# Create output folder
OUTDIR="$(dirname "$FILEPATH")"

# Extract frames
for ((i=1; i<=COUNT; i++)); do
    # timestamp = interval * i
    TS=$(echo "$INTERVAL * $i" | bc -l)
    OUTFILE="${OUTDIR}/${NAME}_screenshot_${i}.png"


    ffmpeg -y -ss "$TS" -i "$FILEPATH" -vframes 1 "$OUTFILE" >/dev/null 2>&1
done

zenity --info --text="Saved $COUNT screenshots in folder: $OUTDIR"

