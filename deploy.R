# deploy.R
# Utilities for syncing and deploying the Blog Editorial Dashboard
# to Posit Connect Cloud.
#
# Typical workflow after making edits in the cloud app:
#   1. Click "Download registry CSV" in the app sidebar
#   2. Save the downloaded file over docs/blog_registry.csv
#   3. Run deploy_dashboard() here to sync and redeploy

library(rsconnect)

deploy_dashboard <- function() {
  # Sync QMD front matter → registry before deploying
  source("sync_registry.R")
  message("✔ Registry synced from post index.qmd files")

  # Sync local registry into the shiny bundle before deploying
  file.copy("docs/blog_registry.csv", "shiny/blog_registry.csv", overwrite = TRUE)
  message("✔ Synced docs/blog_registry.csv → shiny/blog_registry.csv")

  rsconnect::deployApp(
    appDir   = "shiny",
    appTitle = "Blog Editorial Dashboard",
    account  = "westeva",
    server   = "connect.posit.cloud"
  )
}
