suppressPackageStartupMessages(library(tidyverse))
library(hms)

video <- readLines("times.txt", n = 1)
video <- if_else(str_detect(video, " "), str_c("'", video, "'"), video)

#CUT IT UP
full <-
  read.delim(
    "times.txt",
    sep = "-",
    header = FALSE,
    col.names = c("start", "end"),
    skip = 1,
    stringsAsFactors = FALSE
  ) %>%
  mutate(start = if_else(str_count(start, ":") == 1, str_c("0:", start), start)) %>%
  mutate(end = if_else(str_count(end, ":") == 1, str_c("0:", end), end)) %>%
  separate(start, c("start_hr", "start_min", "start_sec")) %>%
  separate(end, c("end_hr", "end_min", "end_sec")) %>%
  mutate_all(as.numeric) %>%
  mutate(
    start = 60 * 60 * start_hr + 60 * start_min + start_sec,
    end = 60 * 60 * end_hr + 60 * end_min + end_sec
  ) %>%
  mutate(
    script = sprintf('ffmpeg -ss %s -to %s -i %s -c copy "%s.mp4"',
                     start, end, video, row_number())
  )

#calculate total length of cut video 
tot_hms <- full %>% 
            summarise(tot = sum(end-start)) %>% 
            pull(tot) %>%
            hms()


# GENERATE CUT SCRIPT -----------------------------------------------------

str_c("# Total duration of video:", tot_hms, sep = " ") %>% 
  write.table("cut_script.sh", quote = FALSE, row.names = FALSE, col.names = FALSE)

full %>% select(script) %>% 
           write.table("cut_script.sh", append = TRUE, quote = FALSE, row.names = FALSE, col.names = FALSE)

# GENERATE PASTE SCRIPT ---------------------------------------------------

temp <- sprintf("file '%s.mp4'", seq_len(nrow(full)))
writeLines(temp, "files_to_merge.txt")
merge_script <- "ffmpeg -f concat -safe 0 -i files_to_merge.txt -c copy merged.mp4"
write(merge_script, "merge_script.sh")


