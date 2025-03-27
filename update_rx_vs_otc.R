
# setup -------------------------------------------------------------------
pacman::p_load(
  tidyverse,
  keyring,
  httr,
  jsonlite,
  stringr,
  bigrquery,
  googlesheets4
)

url <- "https://docs.google.com/spreadsheets/d/1CunUSttBFu0qCATIXGVL8vGGCE1wgGO4uAfq_lQuGro/edit?gid=0#gid=0"
gs4_auth("dennis@work.flowers")
ss <- gs4_get(url)

# get data from sheet 
df_map <- read_sheet(ss, "BigQuery Export")

# function to update products ---------------------------------------------------------

update_product <- function(product_id, rx_otc, region) {
  
  response <- POST(
    url = stringr::str_glue("https://api.stripe.com/v1/products/{product_id}"),
    add_headers(
      Authorization = paste("Bearer", keyring::key_get("of_stripe", toupper(region))),
      `Content-Type` = "application/x-www-form-urlencoded"
    ),
    body = list(`metadata[rx_otc]` = rx_otc),
    encode = "form"
  )
  return(fromJSON(content(response, as = "text", encoding = "UTF-8"), flatten = TRUE))
} 


# run loop ----------------------------------------------------------------


for (i in 1:nrow(df_map)) {

  product_id <- df_map$product_id[i]
  rx_otc <- df_map$category[i]
  region <- df_map$region[i]
  
  response <- update_product(product_id, rx_otc, region)
  
  if (is.null(response$error)) {
    message(str_glue("Set condition of {product_id} to {rx_otc}. {i} of {nrow(df_map)}"))
  } else {
    message(str_glue("Failed to update {product_id}. Error: {response$error$message}"))
  }
}
