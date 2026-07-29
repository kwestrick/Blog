# Blog Project — Assistant Context

## Overview

Quarto website blog with a Shiny dashboard for editorial workflow management. 54 posts tracked in a CSV registry.

## Key files

- `docs/blog_registry.csv` — local source of truth for post metadata (13 fields, see README for schema)
- `shiny/blog_registry.csv` — copy of the registry bundled with the deployed app; must be kept in sync with `docs/blog_registry.csv` before each deployment
- `shiny/app.R` — Shiny dashboard for browsing, filtering, and editing post metadata; single file with `is_local` detection that adapts behavior for local vs. cloud
- `deploy.R` — helper script; `deploy_dashboard()` syncs the CSV and redeploys to Connect Cloud
- `new_post.sh` — bash script to scaffold new post directories
- `_template/index.qmd` — template used by `new_post.sh`
- `index.qmd` — site homepage; listing uses `contents: "posts/**/*.qmd"`
- `_quarto.yml` — Quarto site configuration

## Post directory convention

Posts live at `posts/YYYY/YYYY-MM-DD-slug/index.qmd` with an `images/` subfolder. Deleted posts are archived to `archive/` preserving their full path structure.

## Registry CSV columns

`post_id`, `title`, `lead_quote`, `gist`, `draft_started`, `published_date`, `status`, `publication`, `path`, `tags`, `notes`, `chart_path`, `image_path`

- `post_id` is an auto-generated sequential integer used as an internal key. Not displayed in the UI.
- `status` values: `idea`, `drafting`, `editing`, `scheduled`, `published`, `unassigned`
- `publication` values: `substack`, `website`, `both`, `unassigned`

## Shiny dashboard details

- Inline dropdowns for status/publication save immediately to CSV on change
- Edit form uses explicit "Save changes" button
- Post titles in the table are clickable links that switch to the Edit tab
- Setup column (⚙️) scaffolds directories using `draft_started` date or today's date (local only; disabled in cloud deployment)
- Delete (✖) removes the CSV row; also archives the post directory locally (file move disabled in cloud deployment)
- JavaScript event delegation handles inline dropdown changes
- "Download registry CSV" button in sidebar exports the current CSV for local sync
- "Sign out" button returns to the login screen

## Cloud deployment

- Deployed to Posit Connect Cloud: https://connect.posit.cloud/westeva/content/019f99ba-ec67-dff8-4e6d-9888f25a6fa5
- Account: `westeva` on `connect.posit.cloud`
- Deploy command (use this instead of calling `rsconnect::deployApp` directly):
  ```r
  source("deploy.R")
  deploy_dashboard()
  ```
- Authentication: custom login screen in `shiny/app.R` (no external packages); credentials stored as a named list near the top of the file
- The Free plan on Connect Cloud does not support server-level access control; authentication is handled app-side

## CSV sync workflow

The deployed app writes edits to its own copy of `blog_registry.csv` on Connect Cloud's server. To keep in sync:

1. After making edits in the cloud app, use the **"Download registry CSV"** button in the sidebar
2. Save the downloaded file to `docs/blog_registry.csv` locally
3. Before the next deployment, copy it to the shiny bundle:
   ```r
   file.copy("docs/blog_registry.csv", "shiny/blog_registry.csv", overwrite = TRUE)
   ```

## Data loading

```r
library(tidyverse)
post_data <- read_csv("docs/blog_registry.csv", show_col_types = FALSE)
```

## Reference data

`docs/LFTF Posts Topics.docx.md` — original markdown table from which the 54 post titles were extracted and populated into the registry.

## Session notes (2026-07-29)

- Added new post: "An Antiquated 'Maginot Line' Approach to Foreign Policy" (post_id 54, in draft)
- Added example post for testing document icon (post_id 53, in drafting)
- Cleaned up: archived duplicate skeleton post (`2026-07-25-trumps-maginot-line-approach-to-foreign-policy`)
- Registry synced and Shiny bundle updated; working tree clean
- Ready for next deployment when Maginot post is complete
- Set up LaunchAgent to auto-run Shiny app on system startup (`localhost:3838`)

## Feature backlog

### Next: Prioritize active posts in Posts tab
Reorder the Posts tab table to place "active" posts (status = `drafting`, `editing`, or `scheduled`) at the top of the stack, with inactive/completed posts below. This makes it easier to focus on work-in-progress items.

Implementation notes:
- Modify the data loading/sorting logic in `shiny/app.R` to reorder rows
- Define "active" as status in: `drafting`, `editing`, `scheduled`
- Within each group, maintain existing sort order (or add secondary sort if desired)
- Should work with existing filters (status, publication, search)
