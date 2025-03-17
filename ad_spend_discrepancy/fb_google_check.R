# Starting Stuff ----------------------------------------------------------
pacman::p_load(
  tidyverse,
  lubridate,
  scales,
  zoo,
  patchwork,
  keyring,
  googlesheets4,
  PrettyCols
)

gs4_auth("dennis@work.flowers")
gs_url <- "https://docs.google.com/spreadsheets/d/1_XWOXag-iUo8BHjDh7-5pgwhv3rcFU1xG62TCRIIO6A/"

df_google <- read_sheet(ss, sheet = "Google HK SG", range = "A13:T57675")
df_fb_noah <- read_sheet(ss, sheet = "FB Noah", range = "A3:H42357")
df_fb_zoey <- read_sheet(ss, sheet = "FB Zoey", range = "A3:F1080")