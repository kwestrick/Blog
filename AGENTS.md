# Blog Project — Assistant Context

## Overview

Quarto website blog with a Shiny dashboard for editorial workflow management. Approximately 53 posts tracked in a CSV registry.

## Key files

- `docs/blog_registry.csv` — single source of truth for post metadata (13 fields, see README for schema)
- `shiny/app.R` — Shiny dashboard for browsing, filtering, and editing post metadata
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
- Setup column (⚙️) scaffolds directories using `draft_started` date or today's date
- Delete (✖) moves the entire post directory to `archive/` and removes the CSV row
- JavaScript event delegation handles inline dropdown changes

## Data loading

```r
library(tidyverse)
post_data <- read_csv("docs/blog_registry.csv", show_col_types = FALSE)
```

## Reference data

`docs/LFTF Posts Topics.docx.md` — original markdown table from which the 52 post titles were extracted and populated into the registry.
