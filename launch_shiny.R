# Launch script for Blog Shiny dashboard
# This runs automatically on system startup via LaunchAgent

# Set working directory to blog root
setwd("/Users/kwestrick/Library/CloudStorage/Dropbox/MyBusiness/Development/RCode/Blog")

# Load required libraries
library(shiny)

# Launch the app on localhost:3838
# The app will continue running and restart automatically if it crashes
shiny::runApp(
  "shiny",
  host = "127.0.0.1",
  port = 3838,
  launch.browser = FALSE  # Don't auto-open browser on startup
)
