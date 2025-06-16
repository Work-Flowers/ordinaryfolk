# setup -------------------------------------------------------------------

library(bigrquery)
library(tidyverse)
library(googlesheets4)
library(ellmer)
library(jsonlite)
library(lubridate)
library(purrr)
library(httr)
library(rlang)


# === CONFIGURATION ===

bq_auth("dennis@work.flowers")
project_id <- "noah-e30be"
sheet_url <- "https://docs.google.com/spreadsheets/d/your-sheet-id"

# === STEP 1: Pull recent ad_ids and creative_ids from BigQuery ===

three_months_ago <- Sys.Date() %m-% months(1)

query <- glue("
  SELECT DISTINCT
	  CAST(creative_id AS STRING) AS creative_id
  FROM facebook_ads.ad_history
  WHERE created_time >= '{three_months_ago}'
")

ad_data <- bq_project_query(project_id, query) %>%
  bq_table_download()

# === STEP 2: For each creative_id, fetch a fresh image_url from the FB API ===

is_image_url <- function(url) {
  is.character(url) && length(url) == 1 &&
    grepl("^https?://.*\\.(jpg|jpeg|png|gif|webp|bmp|svg)$", url, ignore.case = TRUE)
}

find_image_in_list <- function(x) {
  # If x is a vector of URLs, loop over each
  if (is.character(x) && length(x) > 1) {
    for (i in x) {
      if (is_image_url(i)) return(i)
    }
  } else if (is_image_url(x)) {
    return(x)
  } else if (is.list(x) || is.data.frame(x)) {
    for (item in x) {
      result <- find_image_in_list(item)
      if (!is.null(result)) return(result)
    }
  }
  return(NULL)
}

get_image_url_only <- function(creative_id) {
  api_url <- glue::glue("https://graph.facebook.com/v19.0/{creative_id}")
  res <- tryCatch({
    httr::GET(
      url = api_url,
      query = list(
        fields = "id,image_url,object_story_spec,asset_feed_spec", 
        access_token = keyring::key_get("meta", "of")
      )
    )
  }, error = function(e) NULL)
  
  if (is.null(res) || res$status_code != 200) return(NA_character_)
  content <- httr::content(res, as = "parsed", simplifyVector = TRUE)
  
  # 1. Direct image_url
  if (is_image_url(content$image_url)) return(content$image_url)
  
  # 2. Try object_story_spec (e.g., for carousels)
  img_from_object_story <- find_image_in_list(content$object_story_spec)
  if (!is.null(img_from_object_story)) return(img_from_object_story)
  
  # 3. Try asset_feed_spec (dynamic ads)
  img_from_asset_feed <- find_image_in_list(content$asset_feed_spec)
  if (!is.null(img_from_asset_feed)) return(img_from_asset_feed)
  
  # If nothing found
  return(NA_character_)
}

# Map to get image URLs for all ads (adds image_url column)
ad_data <- ad_data %>%
  mutate(image_url = map_chr(creative_id, get_image_url_only)) %>%
  filter(!is.na(image_url) & image_url != "")

# === STEP 3: Classify ad images using ellmer + GPT-4 Vision ===

classify_ad <- function(ad_id, image_url) {  
  message(stringr::str_glue("Classifying ad {ad_id}..."))
  
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
