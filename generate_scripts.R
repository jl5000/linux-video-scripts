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
    script1 = str_c("vlc",
                    video,
                    "--start-time",
                    start,
                    "--stop-time",
                    end,
                    sep = " "),
    script2 = str_c(":sout=#file{dst=", row_number(), ".mp4}"),
    script3 = ":no-sout-rtp-sap :no-sout-standard-sap :sout-keep",
    script = str_c(script1, script2, script3, sep = " ")
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

merge_script <- "MP4Box"

for(i in 1:nrow(full)) {
  merge_script <- str_c(merge_script, " -cat ", i, ".mp4")
}

str_c(merge_script, "merged.mp4", sep = " ") %>% write("merge_script.sh")

