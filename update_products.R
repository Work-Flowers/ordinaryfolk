
# setup -------------------------------------------------------------------
pacman::p_load(
  tidyverse,
  keyring,
  httr,
  jsonlite,
  stringr,
  bigrquery
)

# get data from sheet 
df_map <- read_csv("Product IDs.csv")

billing <- "noah-e30be"
bq_auth("dennis@work.flowers")

# pull data ---------------------------------------------------------------

sql <- "
  SELECT 
  	id,
  	name,
  	region AS country
  FROM all_stripe.product
  WHERE JSON_EXTRACT_SCALAR(metadata, '$.condition') IS NULL
"
tb <- bq_project_query(billing, sql)
df_raw <- bq_table_download(tb)

df_conditions <- df_map |> 
  distinct(product_name, condition)
# function to update products ---------------------------------------------------------

update_product <- function(product_id, condition_name, region) {
  
  response <- POST(
    url = stringr::str_glue("https://api.stripe.com/v1/products/{product_id}"),
    add_headers(
      Authorization = paste("Bearer", keyring::key_get("of_stripe", toupper(region))),
      `Content-Type` = "application/x-www-form-urlencoded"
    ),
    body = list(`metadata[condition]` = condition_name),
    encode = "form"
  )
  return(fromJSON(content(response, as = "text", encoding = "UTF-8"), flatten = TRUE))
} 


# run loop ----------------------------------------------------------------

df_final <- df_raw |> 
  inner_join(df_conditions, by = c("name" = "product_name")) |> 
  arrange(name, id)

for (i in 1:nrow(df_final)) {
  
  product_id <- df_final$id[i]
  condition_name <- df_final$condition[i]
  region <- df_final$country[i]
  
  response <- update_product(product_id, condition_name, region)
  
  if (is.null(response$error)) {
    message(str_glue("Set condition of {product_id} to {condition_name}. {i} of {nrow(df_map)}"))
  } else {
    message(str_glue("Failed to update {product_id}. Error: {response$error$message}"))
  }
}
