# Script to clean the raw data for analysis. ------------------------------

library(dplyr)
library(lubridate)
library(stringr)
library(janitor)
library(tidytext)
library(tidyr)

load("C:/Users/chari/Documents/afp-data/raw_data.Rda")
load("./data/postcodes.Rda")

# Clean the transactions dataset. ----
transactions <- transactions_raw %>% 
  clean_names() %>% 
  mutate(date = ymd(date)) %>% 
  mutate(source = str_replace_all(source, "/", ""))

# Clean the non-financial actions dataset. ----

nonfin_actions <- nonfin_actions_raw %>% 
  clean_names() %>% 
  rename(action_name = non_financial_action_non_financial_action_name,
         record_type = non_financial_action_record_type)

# Prepare a "master" dataset from the contacts dataset. ----

# Prepare the postcodes dataset for a join with contacts.
postcode_join <- postcode_data %>% 
  select(postcode, state_y = state, lat, lon) %>% 
  group_by(postcode, state_y) %>% 
  summarise(lat = mean(lat, na.rm = TRUE),
            lon = mean(lon, na.rm = TRUE)) %>% 
  ungroup() %>% 
  group_by(postcode) %>% 
  slice_head(n = 1) %>% 
  ungroup()

# Prepare a list of deceased supporters.
deceased <- transactions %>% 
  filter(do_not_mail_reason == "Deceased") %>% 
  distinct(supporter_id, .keep_all = TRUE)

# Prepare a list of previous campaigns per supporter.
prev_campaigns <- transactions %>%
  filter(date < "2017-01-01") %>%
  mutate(source = str_replace_all(source, "-", " "),
         source = str_replace_all(source, "[0-9]", " ")) %>% 
  unnest_tokens(campaign, source, to_lower = FALSE) %>% 
  distinct(supporter_id, campaign) %>% 
  mutate(value = campaign) %>% 
  pivot_wider(names_from = campaign, values_from = value) %>% 
  unite("previous_campaigns", AFP:last_col(), sep = "|", na.rm = TRUE)

# Prepare a list of previous source_2 channels.
prev_source_2 <- transactions %>% 
  mutate(source_2 = tolower(source_2),
         source_2 = str_replace_all(source_2, "-", "")) %>%
  filter(date < "2017-01-01") %>%
  filter(!is.na(source_2)) %>% 
  distinct(supporter_id, source_2) %>%
  mutate(value = source_2) %>% 
  pivot_wider(names_from = source_2, values_from = value) %>% 
  unite("prev_source_2", directmail:last_col(), sep = "|", na.rm = TRUE)

contacts <- contacts_raw %>% 
  clean_names() %>% 
  rename(state = mailing_state_province,
         postcode = mailing_zip_postal_code,
         country = mailing_country,
         comms_preference = af_p_communication_preference_encoded,
         num_gifts_last_365_days = number_of_gifts_last_365_days,
         num_gifts_this_year = number_of_gifts_this_year,
         num_gifts_last_year = number_of_gifts_last_year,
         num_gifts_two_years_ago = number_of_gifts_two_years_ago) %>% 
  
  # Do some feature engineering with machine learning in mind. 
  mutate(avg_gift_amount = if_else(total_number_of_gifts > 0, total_gifts / total_number_of_gifts, 0),
         avg_gift_amount_last_365_days = if_else(num_gifts_last_365_days > 0, total_gifts_last_365_days / num_gifts_last_365_days, 0),
         avg_gift_amount_this_year = if_else(num_gifts_this_year > 0, total_gifts_this_year / num_gifts_this_year, 0),
         avg_gift_amount_last_year = if_else(num_gifts_last_year > 0, total_gifts_last_year / num_gifts_last_year, 0),
         avg_gift_amount_two_years_ago = if_else(num_gifts_two_years_ago > 0, total_gifts_two_years_ago / num_gifts_two_years_ago, 0)) %>% 
  
  # Add latitude and longitude.
  mutate(country = str_to_title(country)) %>% 
  left_join(postcode_join, by = "postcode") %>% 
  mutate(state = case_when(country == "Australia" & is.na(state) ~ state_y,
                           TRUE ~ state)) %>% 
  select(-state_y) %>% 
  
  # Clean the country variable.
  mutate(country = case_when(is.na(country) & grepl("(NSW|QLD|WA|ACT|NT)", state) ~ "Australia",
                             TRUE ~ country)) %>% 
  
  # Clean the state variable.
  mutate(state = case_when(state == "N.S.W." ~ "NSW",
                           state == "MAN" ~ "MANAWATU-WANGANUI",
                           state == "WAI" ~ "WAIKATO",
                           state == "CAN" ~ "CANTERBURY",
                           state == "VICTORIA" & country == "Australia" ~ "VIC",
                           state == "QUEENSLAND" ~ "QLD",
                           state == "OTA" ~ "OTAGO",
                           state == "CA" ~ "CALIFORNIA",
                           state == "BOP" ~ "BAY OF PLENTY",
                           state == "AKL" ~ "AUCKLAND",
                           state == "WEL" ~ "WELLINGTON",
                           TRUE ~ state)) %>% 
  
  # Change NAs to Unknown in religion and gender.
  replace_na(list(religion = "Unknown", 
                  gender = "Unknown", 
                  comms_preference = "Unknown",
                  state = "Unknown")) %>% 
  
  # Remove deceased supporters.
  anti_join(deceased, by = "supporter_id") %>% 
  
  # Add previous campaigns.
  left_join(prev_campaigns, by = "supporter_id") %>% 
  replace_na(list(previous_campaigns = "Unknown")) %>% 
  
  # Indicate whether the supporter has participated in non-financial actions previously.
  left_join((nonfin_actions %>% 
               mutate(nonfin_action = "Participated") %>% 
               select(supporter_id, nonfin_action)),
            by = "supporter_id") %>% 
  replace_na(list(nonfin_action = "Not Participated")) %>% 
  
  # Clean the comms preference column.
  mutate(comms_preference = str_replace_all(comms_preference, "\\}\\{", ","),
         comms_preference = str_replace_all(comms_preference, "\\}", ""),
         comms_preference = str_replace_all(comms_preference, "\\{", ""),
         comms_preference = str_replace_all(comms_preference, "AFP-", "")) %>% 
  
  # Join previous source_2 channels.
  left_join(prev_source_2, by = "supporter_id") %>% 
  replace_na(list(prev_source_2 = "Not Participated"))

# Map the campaign codes to normal descriptions. ----

campaign_list <- tibble(
  campaign = c("RG", "SG", "CB", "IND", "HV", "REF", "CF", "RC", "CH", "GIFT", "MAG", "NEWS"),
  desc = c("Regular Giving", "Single Giving", "Christmas Bowl", "Individual", "High Value", "Refugees", "Community Fundraising", "Ration Challenge", "Church", "Gifts for Peace", "Supporter Magazine", "Newsletter")
)

# Save data to disk.

save(contacts, transactions, nonfin_actions, campaign_list, file = "C:/Users/chari/Documents/afp-data/clean_data.Rda")