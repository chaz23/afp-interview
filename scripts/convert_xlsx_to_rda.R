# Script to save excel dataset to .Rda format. ----------------------------

library(readxl)

file_path <- "./data/ActForPeaceInterviewDataset.xlsx"

col_types <- list(
  contacts = c("text", "numeric", rep("text", 7), rep("numeric", 10)),
  transactions = c("text", "text", "text", "text", "date", "text", "text", "numeric", "skip", "skip"),
  nonfin_actions = c(rep("text", 6))
)

contacts_raw <- read_excel(path = file_path, sheet = "Contacts", col_types = col_types$contacts)
transactions_raw <- read_excel(path = file_path, sheet = "Transactions", col_types = col_types$transactions)
nonfin_actions_raw <- read_excel(path = file_path, sheet = "Non-Financial-Actions", col_types = col_types$nonfin_actions)

save(contacts_raw, transactions_raw, nonfin_actions_raw, file = "./data/raw_data.Rda")