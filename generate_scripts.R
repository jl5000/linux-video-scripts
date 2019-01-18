library(magrittr)
library(dplyr, warn.conflicts = FALSE)
library(tidyr, warn.conflicts = FALSE)
library(stringr)
library(hms)

#CUT IT UP
times <- read.delim("times.txt", sep = "-", header = FALSE, col.names = c("start", "end"), skip = 1, stringsAsFactors = FALSE)

video <- readLines("times.txt", n = 1)

full <- times %>%  mutate(start = ifelse(str_count(start, ":") == 1, paste0("0:", start), start)) %>% 
                   mutate(end = ifelse(str_count(end, ":") == 1, paste0("0:", end), end)) %>%
                   separate(start, c("start_hr", "start_min", "start_sec")) %>% 
                   separate(end, c("end_hr", "end_min", "end_sec")) %>%
                   mutate_all(as.numeric) %>% 
                   mutate(start = 60*60*start_hr + 60*start_min + start_sec,
                          end = 60*60*end_hr + 60*end_min + end_sec) %>%
                   mutate(script1 = paste("vlc", 
                                          video, 
                                          "--start-time", 
                                          start, 
                                          "--stop-time", 
                                          end),
                          script2 = paste0(":sout=#file{dst=", row_number(), ".mp4}"),
                          script = paste(script1, script2))

#calculate total length of cut video 
tot_hms <- full %>% 
            summarise(tot = sum(end-start)) %>% 
            pull(tot) %>%
            hms()

paste("# Total duration of video:", tot_hms) %>% 
  write.table("cut_script.sh", quote = FALSE, row.names = FALSE, col.names = FALSE)

full %>% select(script) %>% 
           write.table("cut_script.sh", append = TRUE, quote = FALSE, row.names = FALSE, col.names = FALSE)

#PASTE IT TOGETHER
merge_script <- "MP4Box"

for(i in 1:(nrow(times)-1)){
  merge_script <- paste0(merge_script, " -cat ", i, ".mp4")
}

paste(merge_script, "merged.mp4") %>% write("merge_script.sh")


