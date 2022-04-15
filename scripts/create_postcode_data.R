# Script to load in postcode data. ----------------------------------------

# Data sourced from: https://gist.github.com/randomecho/5020859

library(dplyr)
library(readr)
library(stringr)

postcode_data <- read_csv("./data/au-postcodes-lat-lon.csv") %>% 
  select(-...6) %>% 
  janitor::clean_names() %>% 
  mutate(postcode = str_replace_all(postcode, "[:punct:]", ""),
         suburb = str_replace_all(suburb, "'", ""),
         state = str_replace_all(state, "'", ""),
         lon = as.numeric(str_replace_all(lon, "[)]", "")))

save(postcode_data, file = "./data/postcodes.Rda")