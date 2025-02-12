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
bq_auth("dennis@work.flowers")
# pull data ---------------------------------------------------------------

sql <- "SELECT * FROM noah-e30be.all_stripe.subscription_metrics"

tb <- bq_project_query(billing, sql)
df_raw <- bq_table_download(tb)

# saveRDS(df_raw, "raw.rds")


# customer-level analysis -------------------------------------------------

df_customers <- df_raw |> 
  mutate(across(month_start, as.yearmon)) |> 
  group_by(region, customer_id, month_start, currency) |> 
  summarise(
    across(mrr_usd, sum),
    across(created_at, ~min(as.yearmon(.))),
    .groups = "drop"
    ) |> 
  mutate(active_flag = mrr_usd > 0)


df_cust_classified <- df_customers |> 
  group_by(customer_id) |> 
  arrange(month_start) |> 
  mutate(
    status = case_when(
      month_start == created_at ~ "new",
      mrr_usd == 0 & lag(mrr_usd, 1) > 0 ~ "churned",
      mrr_usd > 0 & month_start > created_at & lag(mrr_usd, 1) == 0 ~ "reactivated",
      mrr_usd > lag(mrr_usd, 1) ~ "mrr expansion",
      mrr_usd < lag(mrr_usd, 1) ~ "mrr contraction",
      mrr_usd > 0  ~ "mrr flat"
      ),
    mrr_delta = mrr_usd - coalesce(lag(mrr_usd, 1), 0)
    ) |> 
  ungroup() |> 
  arrange(customer_id, month_start)

df_cust_summary <- df_cust_classified |> 
  group_by(month_start, status) |> 
  summarize(
    n = n_distinct(customer_id),
    across(c(mrr_usd, mrr_delta), sum),
    .groups = "drop"
  ) |> 
  mutate(across(status, ~fct_relevel(., "new", "reactivated", "mrr expansion", "mrr contraction", "mrr flat")))

df_total_actives <- df_cust_classified |> 
  filter(mrr_usd > 0) |> 
  group_by(month_start) |> 
  summarize(
    across(mrr_usd, sum),
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
    dollar_churn_rate = -mrr_delta / lag(mrr_usd, 1)
  )

# plot customers ----------------------------------------------------------

p_actives <- df_cust_summary |> 
  filter(
    mrr_usd > 0,
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

p_mrr <- df_cust_summary |> 
  filter(
    mrr_usd > 0,
    month_start >= as.yearmon("2023-01")
  ) |> 
  ggplot(aes(month_start, mrr_usd)) +
  geom_col(aes(fill = status)) +
  scale_x_yearmon(format = "%b %y", n = 5) +
  scale_y_continuous(labels = label_dollar()) +
  PrettyCols::scale_fill_pretty_d("Bold") +
  labs(
    y = "Total MRR",
    x = NULL,
    fill = "Customer Status",
    title = "Total MRR by Customer Status",
    subtitle = "Source: Stripe"
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

p_dollar_churn <- df_churn |> 
  filter(month_start >= as.yearmon("2023-01")) |> 
  ggplot(aes(month_start, dollar_churn_rate)) +
  geom_line(color = "blue") + 
  scale_x_yearmon(format = "%b %y", n = 5) +
  scale_y_continuous(labels = label_percent()) +
  labs(
    y = "Dollar Churn Rate",
    x = NULL,
    title = "% of MRR Churning from Prior Month",
    subtitle = "Source: Stripe"
  )


(p_actives + p_churn) / (p_mrr + p_dollar_churn)
