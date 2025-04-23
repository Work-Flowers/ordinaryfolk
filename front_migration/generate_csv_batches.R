
# purpose -----------------------------------------------------------------

# generate batch of csv files of 3,000 rows each, which is the row limit for 
# csv imports into front

# Starting Stuff ----------------------------------------------------------
pacman::p_load(
  tidyverse,
  lubridate,
  scales,
  zoo,
  patchwork,
  keyring,
  bigrquery
)


billing <- "noah-e30be"
bq_auth("dennis@work.flowers")
query <- read_file("stripe_customers.sql")

# import data -------------------------------------------------------------

tb <- bq_project_query(billing, query)
df_raw <- bq_table_download(tb)

contacts_df <- df_raw |> 
  mutate(
    `Last Transaction Date` = as.numeric(as.POSIXct(last_transaction_date, format = "%Y-%m-%d %H:%M:%S", tz = "UTC"))
    ) |> 
  select(
    Region = region,
    name,
    email,
    phone,
    `Stripe Customer ID` = customer_id,
    `Is Active Subscriber` = is_active_subscriber,
    `Last Transaction Date`
  ) |> 
  arrange(
    Region,
    email
  )

# break into batches ------------------------------------------------------

# Define the chunk size
chunk_size <- 3000

# Create a directory to store the CSV files

# Get the total number of rows
total_rows <- nrow(contacts_df)

# Calculate the number of chunks
num_chunks <- ceiling(total_rows / chunk_size)

# Loop through and write each chunk to a separate CSV file
for (i in seq_len(num_chunks)) {
  start_row <- ((i - 1) * chunk_size) + 1
  end_row <- min(i * chunk_size, total_rows)
  
  # Extract the subset
  chunk <- contacts_df[start_row:end_row, ]
  
  # Define the file name
  file_name <- paste0("contacts_part_", i, ".csv")
  
  # Write the CSV
  write_csv(chunk, file_name)
  
  # Print progress
  message(paste("Saved:", file_name))
}

message("All files have been successfully saved.")
