# Starting Stuff ----------------------------------------------------------
pacman::p_load(
  tidyverse,
  lubridate,
  scales,
  zoo,
  patchwork,
  keyring,
  bigrquery,
  PrettyCols
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
      monthly_recurring_revenue > lag(monthly_recurring_revenue, 1) ~ "mrr expansion",
      monthly_recurring_revenue < lag(monthly_recurring_revenue, 1) ~ "mrr contraction",
      monthly_recurring_revenue > 0 & month_start > created_at & is.na(lag(monthly_recurring_revenue, 1)) ~ "resurrected",
      monthly_recurring_revenue > 0  ~ "mrr flat"
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
  ) |> 
  mutate(across(status, ~fct_relevel(., "new", "mrr expansion", "mrr contraction", "mrr flat")))

df_total_actives <- df_cust_classified |> 
  filter(monthly_recurring_revenue > 0) |> 
  group_by(month_start) |> 
  summarize(
    across(monthly_recurring_revenue, sum),
    n = n()
  )
  
df_churn <- df_cust_summary |> 
  filter(status == "churned") |> 
  select(
    month_start,
    n_churned = n,
    mrr_delta
  ) |> 
  inner_join(df_total_actives, by = "month_start") |> 
  arrange(month_start) |> 
  mutate(
    churn_rate = n_churned / lag(n, 1),
    dollar_churn_rate = mrr_delta / lag(monthly_recurring_revenue, 1)
  )

# plot customers ----------------------------------------------------------
(
  p_actives <- df_cust_summary |> 
    filter(
      mrr > 0,
      month_start >= as.yearmon("2023-01")
      ) |> 
    ggplot(aes(month_start, n)) +
    geom_col(aes(fill = status)) +
    scale_x_yearmon(format = "%b %y", n = 5) +
    scale_y_continuous(labels = label_comma()) +
    PrettyCols::scale_fill_pretty_d("Bold") +
    labs(
      y = "No. of Customers",
      x = NULL,
      fill = "Customer Status",
      title = "No.of Active Customers by Status",
      subtitle = "Source: Stripe"
    )
)

p_churn <- df_churn |> 
  filter(month_start >= as.yearmon("2023-01")) |> 
  ggplot(aes(month_start, churn_rate)) +
  geom_line(color = "blue") + 
  scale_x_yearmon(format = "%b %y", n = 5) +
  scale_y_continuous(labels = label_percent()) +
  labs(
    y = "Churn Rate",
    x = NULL,
    title = "% of Customers Churning from Prior Month",
    subtitle = "Source: Stripe"
  )
