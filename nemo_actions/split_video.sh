#!/bin/bash
dir="$1"
cd "$dir" || exit 1

times_file="times.txt"
if [ ! -f "$times_file" ]; then
    zenity --error --text="times.txt not found in $dir"
    exit 1
fi

video=$(head -n 1 "$times_file" | xargs)
if [ ! -f "$video" ]; then
    zenity --error --text="Video file '$video' not found in $dir"
    exit 1
fi

# Read ALL segments into an array
mapfile -t segments < <(tail -n +2 "$times_file")

to_seconds() {
    local t="${1// /}"
    IFS=: read -r a b c <<< "$t"
    if [ -n "$c" ]; then
        echo $((10#$a * 3600 + 10#$b * 60 + 10#$c))
    elif [ -n "$b" ]; then
        echo $((10#$a * 60 + 10#$b))
    else
        echo 0
    fi
}

count=1
total_seconds=0
pids=()

echo "Starting parallel extraction (max 2 at a time)..."

for line in "${segments[@]}"; do
    [ -z "${line// }" ] && continue
    line="${line// /}"
    start="${line%%-*}"
    stop="${line#*-}"
    start_sec=$(to_seconds "$start")
    stop_sec=$(to_seconds "$stop")
    
    if [ "$stop_sec" -gt "$start_sec" ]; then
        total_seconds=$((total_seconds + stop_sec - start_sec))
    fi
    
    out="${count}.mp4"
    
    # Run ffmpeg in background
    ffmpeg -hide_banner -loglevel warning \
        -ss "$start_sec" -to "$stop_sec" \
        -i "$video" \
        -c:v libx264 -preset fast -crf 18 \
        -c:a copy \
        "$out" &
    
    pids+=($!)
    echo "Started segment $count: $start → $stop (PID $!)"
    
    # Limit to max 2 concurrent jobs
    if [ ${#pids[@]} -ge 2 ]; then
        wait -n  # Wait for at least one job to finish
        # Clean up finished PIDs (optional but good practice)
        new_pids=()
        for pid in "${pids[@]}"; do
            if kill -0 "$pid" 2>/dev/null; then
                new_pids+=("$pid")
            fi
        done
        pids=("${new_pids[@]}")
    fi
    
    count=$((count + 1))
done

# Wait for all remaining jobs
wait

num_segments=$((count - 1))

if [ "$num_segments" -eq 0 ]; then
    zenity --info --text="No segments found. Nothing to do."
    exit 0
fi

# Format total duration
hours=$((total_seconds / 3600))
minutes=$(((total_seconds % 3600) / 60))
seconds=$((total_seconds % 60))
total_formatted=$(printf "%02d:%02d:%02d" $hours $minutes $seconds)

zenity --info --text="Extraction finished!\nCreated $num_segments video segment(s).\n\nExpected length: $total_formatted"

# === MERGE / FINALIZE PHASE ===
if [ "$num_segments" -eq 1 ]; then
    # Single segment: just rename it (no need to merge)
    mv -f "1.mp4" "merged.mp4"
    zenity --info --text="Single segment processed!\n\nmerged.mp4 created ($total_formatted)"
else
    # Multiple segments: merge them
    echo "Merging $num_segments segments into merged.mp4..."
    
    concat_list=$(mktemp concat_list.XXXXXX.txt)
    for i in $(seq 1 $num_segments); do
        echo "file '$i.mp4'" >> "$concat_list"
    done

    if ffmpeg -hide_banner -loglevel warning \
        -f concat -safe 0 -i "$concat_list" \
        -c copy "merged.mp4"; then
        
        rm -f "$concat_list"
        
        # Delete temporary segments
        for i in $(seq 1 $num_segments); do
            rm -f "$i.mp4"
        done
        
        zenity --info --text="Merge completed successfully!\n\nmerged.mp4 created ($total_formatted)\nTemporary segments deleted."
    else
        rm -f "$concat_list"
        zenity --error --text="Merge failed! Segments were left intact."
    fi
fi
