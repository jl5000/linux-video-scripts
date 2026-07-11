#!/bin/bash

# Ask user for rotation angle
angle=$(zenity --entry --title="Rotation Angle" --text="Enter rotation angle (e.g. 90):")
[ -z "$angle" ] && exit 0

# Loop through all files passed by Nemo
for f in "$@"; do
    dir="$(dirname "$f")"
    base="$(basename "$f" .mp4)"
    out="${dir}/${base}_rotated.mp4"

    exiftool -rotation="$angle" -out "$out" "$f"
done

