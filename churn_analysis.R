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
  mutate(across(month_start, as.yearmon)) |> 
  group_by(region, customer_id, month_start, currency) |> 
  summarise(
    across(monthly_recurring_revenue, sum),
    across(created_at, ~min(as.yearmon(.))),
    .groups = "drop"
    ) |> 
  mutate(active_flag = monthly_recurring_revenue > 0)


df_cust_classified <- df_customers |> 
  group_by(customer_id) |> 
  arrange(month_start) |> 
  mutate(
    status = case_when(
      month_start == created_at ~ "new",
      monthly_recurring_revenue == 0 & lag(monthly_recurring_revenue, 1) > 0 ~ "churned",
      monthly_recurring_revenue > lag(monthly_recurring_revenue, 1) ~ "expansion",
      monthly_recurring_revenue < lag(monthly_recurring_revenue, 1) ~ "contraction",
      monthly_recurring_revenue > 0 & month_start > created_at & is.na(lag(monthly_recurring_revenue, 1)) ~ "resurrected",
      monthly_recurring_revenue > 0  ~ "retained"
      ),
    mrr_delta = monthly_recurring_revenue - coalesce(lag(monthly_recurring_revenue, 1), 0)
    ) |> 
  ungroup() |> 
  arrange(customer_id, month_start)

df_cust_summary <- df_cust_classified |> 
  group_by(month_start, status) |> 
  summarize(
    n = n(),
    mrr = sum(monthly_recurring_revenue),
    across(mrr_delta, sum),
    .groups = "drop"
  )

