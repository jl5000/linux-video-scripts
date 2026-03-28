
# We have a cut script and a number of files
# Some of them are bad, and the cut script has been edited manually to remove the good ones
# This script should iteratively remove a second off each remaining one until the size changes
library(stringr)

# Read cut_script.sh and filter out comments
lines <- readLines("cut_script.sh")
lines <- lines[grepl("^ffmpeg", lines)]

# Function to extract start time, stop time, and output filename
parse_script <- function(line) {
  start <- str_extract(line, "-ss \\d+") |> str_remove("-ss ") |> as.numeric()
  stop <- str_extract(line, "-to \\d+") |> str_remove("-to ") |> as.numeric()
  outfile <- str_extract(line, '"(\\d+\\.mp4)"', group = 1)
  list(start = start, stop = stop, outfile = outfile)
}

# Iterate over each line
for (line in lines) {
  info <- parse_script(line)
  original_size <- if (file.exists(info$outfile)) file.info(info$outfile)$size else 0
  new_size <- original_size
  new_start <- info$start
  
  while (new_size == original_size) {
    new_start <- new_start + 1
    new_cmd <- str_replace(line, paste("-ss", info$start), paste("-ss", new_start))
    system(new_cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)
    Sys.sleep(1)  # Give time for file to be written
    new_size <- if (file.exists(info$outfile)) file.info(info$outfile)$size else 0
  }

}
