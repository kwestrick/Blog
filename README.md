# Blog Workflow and Dashboard

This repository is a Quarto website for blog posts, with a metadata registry and a Shiny dashboard for managing the editorial pipeline.

## Repository layout

```
Blog/
├── posts/YYYY/YYYY-MM-DD-slug/   # Blog post directories
│   ├── index.qmd                 # Post content and YAML front matter
│   └── images/                   # Post-specific images
├── _template/index.qmd           # Template for new posts
├── docs/
│   └── blog_registry.csv         # Post metadata registry (local source of truth)
├── shiny/
│   ├── app.R                     # Workflow dashboard (local + cloud, auto-detected)
│   └── blog_registry.csv         # Registry bundled with cloud deployment
├── deploy.R                      # deploy_dashboard() helper — sync + redeploy
├── sync_registry.R               # Syncs index.qmd front matter → blog_registry.csv
├── archive/                      # Deleted post directories (preserved structure)
├── new_post.sh                   # Post scaffolding script
├── index.qmd                     # Site homepage with post listing
├── about.qmd                     # About page
├── _quarto.yml                   # Quarto site configuration
└── styles.css                    # Site styles
```

## Two systems, two purposes

Editorial metadata and post content are managed separately and intentionally:

| System | File | Authoritative for |
|--------|------|-------------------|
| Registry | `docs/blog_registry.csv` | `lead_quote`, `gist`, `notes`, `status`, `publication`, `chart_path` |
| Post content | `posts/**/index.qmd` | `title`, `date`, `categories`, `image`, `description`, body text |

`sync_registry.R` bridges the two by reading front matter from each `index.qmd` and updating the registry. Fields that are editorial-only (lead quote, gist, notes, publication, status) are never overwritten by the sync.

## Blog registry

`docs/blog_registry.csv` is the source of truth for editorial metadata.

### Fields

| Field | Description |
|-------|-------------|
| `post_id` | Auto-generated integer key; also written into each `index.qmd` YAML for cross-referencing |
| `title` | Post title (synced from `index.qmd`) |
| `lead_quote` | Opening quote for the post |
| `gist` | Brief summary of the post idea |
| `draft_started` | Date drafting began (filled from `index.qmd` `date:` if blank) |
| `published_date` | Publication date (filled from `index.qmd` `date:` when `draft: false`) |
| `status` | Editorial status: `idea`, `drafting`, `editing`, `scheduled`, `published`, `unassigned` |
| `publication` | Target outlet: `substack`, `website`, `both`, `unassigned` |
| `path` | Relative path to the post directory (synced from file system) |
| `tags` | Semicolon-separated topic tags (synced from `index.qmd` `categories:`) |
| `chart_path` | Path to chart/graph/map/table assets |
| `image_path` | Path to image/photo assets (synced from `index.qmd` `image:`) |
| `notes` | Free-text notes |

## Post template

`_template/index.qmd` is pre-filled to speed up new post setup. When a post is scaffolded, `title`, `date`, and `post_id` are substituted automatically; everything else is ready to edit:

```yaml
---
title: "Post Title"              # ← replaced at scaffold time
description: "..."               # ← fill in manually
author: "Kenneth Westrick"       # ← pre-filled
date: today                      # ← replaced with actual date at scaffold time
post_id: 0                       # ← replaced with registry post_id at scaffold time
categories:                      # ← delete inapplicable categories
  [Leadership & Ethics, Geopolitics, Immigration, Economics,
   Saving Democracy, Science & Technology, Global Environment, Future]
image: images/featured-image.png # ← replace filename when image is ready
draft: true                      # ← set to false when ready to publish
---
```

The `post_id` field in the YAML provides a direct one-to-one lookup between the `index.qmd` file and the corresponding row in `blog_registry.csv`.

## Shiny dashboard

Run the dashboard locally from the repository root:

```r
shiny::runApp("shiny", launch.browser = TRUE)
```

The app detects its environment automatically: running locally gives full access with no login; the deployed cloud version requires authentication and disables file system operations.

### Authentication (cloud only)

The cloud deployment is protected with a custom login screen. Credentials are stored as a plain list near the top of `shiny/app.R`.

**To add or change a user**, edit the `credentials` list in `shiny/app.R` and redeploy:

```r
credentials <- list(
  admin   = "password",
  newuser = "their_password"
)
```

### Posts tab

- Filterable table with inline status and publication dropdowns (color-coded)
- 📄 icon shows the file path on hover
- ⚙️ icon scaffolds the post directory on click (becomes ✅ when done) — **local only**
- Post titles are clickable links that load the Edit tab
- Green/red dot indicators for chart, image, and tag completeness
- ✖ delete icon removes the registry entry and archives the post directory to `archive/` — **local only**

### Edit Selected Post tab

Full metadata editing form with Load / Save / Clear / Back to Posts controls. Summary panels show total posts, published count, unpublished count, and missing-field count.

### Sidebar

| Control | Local | Cloud |
|---------|-------|-------|
| Refresh data | ✅ | ✅ |
| Create new post | ✅ | — |
| Download registry CSV | — | ✅ |
| Sign out | — | ✅ |
| Filters (status, publication, search, missing-only) | ✅ | ✅ |

## Creating posts

Two workflows (local only):

1. **Sidebar "Create new post"** — enter a title, click create. Runs `new_post.sh` to scaffold the directory, injects `title`, `date`, and `post_id` into `index.qmd`, and auto-registers the post in the registry with status `idea`.
2. **Setup icon (⚙️) in Posts tab** — for registry entries that exist but don't yet have a directory. Uses the `draft_started` date (or today) for the directory name.

Both paths write `post_id` into the new `index.qmd` front matter automatically.

## Post directory structure

```
posts/YYYY/YYYY-MM-DD-slug/
├── index.qmd    # Pre-filled with title, date, post_id from _template/index.qmd
└── images/      # Empty subfolder for post assets
```

The directory name becomes the URL slug. The file is always named `index.qmd` so the URL ends cleanly at the directory without a filename:

```
/posts/2026/2026-07-25-my-post-title/
```

## Syncing the registry

`sync_registry.R` scans every `posts/**/index.qmd`, reads its YAML front matter, and updates `docs/blog_registry.csv`. Run it any time after editing post files:

```r
source("sync_registry.R")
```

**What it updates:**

| Registry field | Source | Rule |
|----------------|--------|------|
| `title` | `index.qmd` `title:` | Always sync if changed |
| `path` | File system | Always sync |
| `image_path` | `index.qmd` `image:` | Always sync |
| `tags` | `index.qmd` `categories:` | Always sync |
| `draft_started` | `index.qmd` `date:` | Fill only if blank |
| `published_date` | `index.qmd` `date:` (when `draft: false`) | Fill only if blank |
| `status` | `index.qmd` `draft:` | `unassigned` → `published` when `draft: false` |

**Never overwritten:** `lead_quote`, `gist`, `notes`, `publication`, `status` (except unassigned → published).

Posts found on disk but absent from the registry are added as new rows. The script prints a full change log and a missing-field audit on every run.

## Deploying to Connect Cloud

Use `deploy.R` to sync and redeploy in one step:

```r
source("deploy.R")
deploy_dashboard()
```

`deploy_dashboard()` runs three steps in order:

1. **`source("sync_registry.R")`** — syncs `index.qmd` front matter into `docs/blog_registry.csv`
2. **`file.copy(...)`** — copies `docs/blog_registry.csv` → `shiny/blog_registry.csv`
3. **`rsconnect::deployApp(...)`** — pushes the Shiny bundle to Connect Cloud

**Syncing cloud edits back to local:**

The deployed app writes edits to its own server-side copy of the registry. To pull those edits back:

1. Click **"Download registry CSV"** in the app sidebar
2. Save the file over `docs/blog_registry.csv`
3. Run `deploy_dashboard()` when ready to redeploy

## Quarto site

The site listing in `index.qmd` uses `contents: "posts/**/*.qmd"` to recursively discover all posts across year directories. Output renders to `_site/`. Categories are free-form — any category listed in a post's `categories:` front matter field is automatically surfaced in the listing filter.
