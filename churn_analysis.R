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
pacman::p_load_current_gh("denchiuten/tsViz")
theme_set(theme_ts())

billing <- "noah-e30be"
# pull data ---------------------------------------------------------------

sql <- "SELECT * FROM noah-e30be.all_stripe.subscription_history"

tb <- bq_project_query(billing, sql)
df_raw <- bq_table_download(tb)

saveRDS(df_raw, "raw.rds")


# customer-level analysis -------------------------------------------------

df_customers <- df_raw |> 
  group_by(region, customer_id, month_start, currency) |> 
  summarise(
    across(monthly_recurring_revenue, sum), 
    .groups = "drop"
    ) |> 
  mutate(active_flag = monthly_recurring_revenue > 0)
