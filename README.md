# Blog workflow and dashboard

This repository is a Quarto website for blog posts, with an additional metadata registry and a Shiny dashboard for managing the editorial pipeline.

## Repository layout

The site is configured as a Quarto website with `_site` as the output directory, plus standard pages such as `index.qmd` and `about.qmd`.

Recommended structure for workflow management:

- `docs/blog_registry.md` — human-readable catalog of post ideas, drafts, and published pieces.
- `docs/blog_registry.csv` — structured registry for RStudio and the Shiny dashboard.
- `shiny/app.R` — reactive dashboard for browsing and editing post metadata.
- dated post folders such as `2026-07-23-example-post/` — Quarto post content and related assets.

## Blog registry fields

The CSV registry is the main structured source of truth for editorial metadata.

Expected columns:

- `post_id`
- `title`
- `lead_quote`
- `gist`
- `idea_date`
- `draft_started`
- `published_date`
- `publication`
- `status`
- `path`
- `assets`
- `substack_url`
- `website_url`
- `notes`
- `r_project`
- `tags`

Suggested status values:

- `idea`
- `drafting`
- `editing`
- `scheduled`
- `published`
- `unassigned`

Suggested publication values:

- `substack`
- `website`
- `both`
- `unassigned`

## Shiny dashboard

The Shiny app reads `docs/blog_registry.csv`, lets the user filter and inspect posts, and supports write-back editing of metadata fields directly into the CSV file.

Primary features:

- Filter by status and publication.
- Search by title, gist, or tags.
- Show posts missing key metadata.
- Load a selected post into an edit form.
- Save edits back to `docs/blog_registry.csv`.

To run the dashboard from the repository root in RStudio:

```r
shiny::runApp("shiny")
