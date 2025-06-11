# setup -------------------------------------------------------------------

library(bigrquery)
library(dplyr)
library(googlesheets4)
library(ellmer)
library(jsonlite)
library(lubridate)
library(purrr)
library(httr)
library(glue)


# === CONFIGURATION ===

bq_auth("dennis@work.flowers")
project_id <- "noah-e30be"
dataset <- "your_dataset_name"
table <- "your_ad_history_table"
sheet_url <- "https://docs.google.com/spreadsheets/d/your-sheet-id"
facebook_token <- "EAAG...YOUR_FACEBOOK_ACCESS_TOKEN..." # From your client
Sys.setenv(OPENAI_API_KEY = "sk-...")  # or load from .Renviron

# === STEP 1: Pull recent ad_ids and creative_ids from BigQuery ===

three_months_ago <- Sys.Date() %m-% months(3)

query <- glue("
  SELECT DISTINCT
	  CAST(creative_id AS STRING) AS creative_id
  FROM facebook_ads.ad_history
  WHERE created_time >= '{three_months_ago}'
")

ad_data <- bq_project_query(project_id, query) %>%
  bq_table_download()

# === STEP 2: For each creative_id, fetch a fresh image_url from the FB API ===

get_image_url <- function(creative_id, facebook_token) {
  api_url <- paste0("https://graph.facebook.com/v19.0/", creative_id)
  res <- tryCatch({
    httr::GET(
      url = api_url,
      query = list(fields = "image_url", access_token = facebook_token)
    )
  }, error = function(e) NULL)
  
  if (is.null(res) || res$status_code != 200) return(NA_character_)
  content <- httr::content(res, as = "parsed", type = "application/json")
  image_url <- content$image_url %||% NA_character_
  image_url
}

# Map to get image URLs for all ads (adds image_url column)
ad_data <- ad_data %>%
  mutate(image_url = map_chr(creative_id, ~get_image_url(.x, facebook_token)))

# === STEP 3: Classify ad images using ellmer + GPT-4 Vision ===

classify_ad <- function(ad_id, image_url) {
  message(glue::glue("Classifying ad {ad_id}..."))
  
  if (is.na(image_url) || image_url == "") {
    return(tibble(
      ad_id = ad_id,
      image_url = image_url,
      condition = NA_character_,
      angle = NA_character_,
      classified_at = Sys.time(),
      error = "No image_url"
    ))
  }
  
  result <- tryCatch({
    response <- chat(
      model = "gpt-4-vision-preview",
      messages = list(
        system("You are a marketing expert that classifies Facebook ad images."),
        user(list(
          list(type = "text", text = "Classify this ad:\n1. What medical condition does it address?\n2. What marketing angle is used (e.g., testimonial, educational, urgency, emotional)?\nReturn JSON."),
          list(type = "image_url", image_url = list(url = image_url))
        ))
      ),
      max_tokens = 300
    )()
    
    parsed <- fromJSON(response$content)
    tibble(
      ad_id = ad_id,
      image_url = image_url,
      condition = parsed$condition,
      angle = parsed$angle,
      classified_at = Sys.time(),
      error = NA_character_
    )
  }, error = function(e) {
    tibble(
      ad_id = ad_id,
      image_url = image_url,
      condition = NA_character_,
      angle = NA_character_,
      classified_at = Sys.time(),
      error = e$message
    )
  })
  
  return(result)
}

results <- ad_data %>%
  select(ad_id, image_url) %>%
  distinct() %>%
  pmap_dfr(~ classify_ad(..1, ..2))

# === STEP 4: Write to Google Sheet ===

googlesheets4::gs4_auth()
sheet_write(results, ss = sheet_url, sheet = "Ad Classifications")

message("✅ All done. Results written to Google Sheet.")
