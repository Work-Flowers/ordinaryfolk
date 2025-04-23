# Starting Stuff ----------------------------------------------------------
pacman::p_load(
  tidyverse,
  lubridate,
  scales,
  zoo,
  patchwork,
  keyring,
  googlesheets4,
  PrettyCols,
  bigrquery
)

gs4_auth("dennis@work.flowers")
gs_url <- "https://docs.google.com/spreadsheets/d/1_XWOXag-iUo8BHjDh7-5pgwhv3rcFU1xG62TCRIIO6A/"


billing <- "noah-e30be"
bq_auth("dennis@work.flowers")

query_google <- read_file("google_ads_query.sql")
query_fb <- read_file("facebook_ads_query.sql")



# pull data ---------------------------------------------------------------

# pull data from Google Sheet
ss <- gs4_get(gs_url)

df_google_export <- readRDS(file = "dfGoogle.rds")
# df_google <- read_sheet(ss, sheet = "Google HK SG", range = "A13:T57675")
df_fb_noah_export <- read_sheet(ss, sheet = "FB Noah", range = "A3:H42357")
df_fb_zoey_export <- read_sheet(ss, sheet = "FB Zoey", range = "A3:F1080")

# saveRDS(df_google_export, file = "dfGoogle.rds")
saveRDS(df_fb_noah_export, file = "dfFacebookNoah.rds")

# pull data from bigquery

tb_google <- bq_project_query(billing, query_google)
df_google_raw <- bq_table_download(tb_google)

tb_fb <- bq_project_query(billing, query_fb)
df_fb_raw <- bq_table_download(tb_fb)


# wrangle and compare google ----------------------------------------------

df_google_export_monthly <- df_google_export |> 
  select(
    date = Day,
    campaign = Campaign,
    cost_local = Cost
  ) |> 
  mutate(
    channel = "google",
    ym = as.yearmon(date)
    ) |> 
  group_by(
    channel,
    ym
  ) |> 
  summarise(across(cost_local, sum), .groups = "drop")

df_google_bq_monthly <- df_google_raw |> 
  mutate(ym = as.yearmon(date)) |> 
  group_by(ym) |> 
  summarise(across(cost_local, sum), .groups = "drop")

df_google_compare <- df_google_export_monthly |> 
  left_join(df_google_bq_monthly, by = "ym")


# wrangle and compare fb --------------------------------------------------

df_fb_noah_cleaned <- df_fb_noah_export |> 
  select(
    date = Day,
    cost_local = `Amount spent`,
    campaign = `Campaign name`
  )

df_fb_zoey_cleaned <- df_fb_zoey_export |> 
  select(
    date = Day,
    cost_local = `Amount spent`,
    campaign = `Campaign name`
  )

df_fb_export_cleaned <- bind_rows(df_fb_noah_cleaned, df_fb_zoey_cleaned)

df_fb_export_monthly <- df_fb_export_cleaned |> 
  mutate(
    channel = "facebook",
    ym = as.yearmon(date)
    ) |> 
  group_by(channel, ym) |> 
  summarise(across(cost_local, sum), .groups = "drop")

df_fb_bq_monthly <- df_fb_raw |> 
  mutate(
    channel = "facebook",
    ym = as.yearmon(date)
    ) |> 
  group_by(ym) |> 
  summarise(across(cost_local, sum), .groups = "drop")

df_fb_compare <- df_fb_export_monthly |> 
  left_join(df_fb_bq_monthly, by = "ym", suffix = c(".export", ".bigquery"))


# union the exports -------------------------------------------------------

df_export_all <- bind_rows(df_fb_export_monthly, df_google_export_monthly) |> 
  filter(!is.na(ym)) |> 
  mutate(year = year(ym))

df_export_annual <- df_export_all |> 
  group_by(year, channel) |> 
  summarise(across(cost_local, sum), .groups = "drop")
