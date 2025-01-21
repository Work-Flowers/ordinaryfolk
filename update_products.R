
# setup -------------------------------------------------------------------
pacman::p_load(
  tidyverse,
  keyring,
  httr,
  jsonlite,
  stringr
)

# get data from sheet 
df_map <- read_csv("Product IDs.csv")


# function to update products ---------------------------------------------------------

update_product <- function(product_id, condition_name, region) {
  
  response <- POST(
    url = stringr::str_glue("https://api.stripe.com/v1/products/{product_id}"),
    add_headers(
      Authorization = paste("Bearer", keyring::key_get("of_stripe", region)),
      `Content-Type` = "application/x-www-form-urlencoded"
    ),
    body = list(`metadata[condition]` = condition_name),
    encode = "form"
  )
  return(fromJSON(content(response, as = "text", encoding = "UTF-8"), flatten = TRUE))
} 


# run loop ----------------------------------------------------------------

for (i in 1:nrow(df_map)) {
  
  product_id <- df_map$product_id[i]
  condition_name <- df_map$condition[i]
  region <- df_map$country[i]
  
  response <- update_product(product_id, condition_name, region)
  
  if (is.null(response$error)) {
    message(str_glue("Set condition of {product_id} to {condition_name}. {i} of {nrow(df_map)}"))
  } else {
    message(str_glue("Failed to update {product_id}. Error: {response$error$message}"))
  }
}
