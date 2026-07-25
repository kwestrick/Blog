# Blog Workflow and Dashboard

This repository is a Quarto website for blog posts, with a metadata registry and a Shiny dashboard for managing the editorial pipeline.

## Repository layout

```
Blog/
├── posts/YYYY/YYYY-MM-DD-slug/   # Blog post directories
│   ├── index.qmd                 # Post content
│   └── images/                   # Post-specific images
├── _template/index.qmd           # Template for new posts
├── docs/
│   └── blog_registry.csv         # Post metadata registry (local source of truth)
├── shiny/
│   ├── app.R                     # Workflow dashboard (local + cloud, auto-detected)
│   └── blog_registry.csv         # Registry bundled with cloud deployment
├── deploy.R                      # deploy_dashboard() helper — sync CSV + redeploy
├── archive/                      # Deleted post directories (preserved structure)
├── new_post.sh                   # Post scaffolding script
├── index.qmd                     # Site homepage with post listing
├── about.qmd                     # About page
├── _quarto.yml                   # Quarto site configuration
└── styles.css                    # Site styles
```

## Blog registry

The CSV at `docs/blog_registry.csv` is the single source of truth for editorial metadata.

### Fields

| Field | Description |
|-------|-------------|
| `post_id` | Auto-generated integer key (internal, not displayed in UI) |
| `title` | Post title |
| `lead_quote` | Opening quote for the post |
| `gist` | Brief summary of the post idea |
| `draft_started` | Date drafting began |
| `published_date` | Publication date |
| `status` | Editorial status: `idea`, `drafting`, `editing`, `scheduled`, `published`, `unassigned` |
| `publication` | Target outlet: `substack`, `website`, `both`, `unassigned` |
| `path` | Relative path to the post directory |
| `chart_path` | Path to chart/graph/map/table assets |
| `image_path` | Path to image/photo assets |
| `tags` | Comma-separated topic tags |
| `notes` | Free-text notes |

## Shiny dashboard

Run the dashboard from the repository root:

```r
shiny::runApp("shiny")
```

The app detects its environment automatically: running locally via `shiny::runApp("shiny")` gives full access with no login; the deployed cloud version requires authentication and disables file system operations.

### Authentication (cloud only)

The cloud deployment is protected with a login screen. Credentials are stored as a plain list in `shiny/app.R` (lines 11-17).

**Current users:**
- `admin` / `grunt11B!`
- `ken` / `ken321Neth!`
- `anton` / `an321Ton!`

**To add or change a user:**

1. Edit the `credentials` list in `shiny/app.R`:
   ```r
   credentials <- list(
     admin  = "grunt11B!",
     newuser = "their_password"
   )
   ```

2. Run `deploy_dashboard()` to sync and redeploy:
   ```r
   source("deploy.R")
   deploy_dashboard()
   ```

### Posts tab

- Filterable data table with inline status and publication dropdowns (color-coded)
- 📄 icon shows file path on hover
- ⚙️ icon scaffolds the post directory on click (becomes ✅ when done) — **local only**
- Post titles are clickable links that load the Edit tab
- Green/red dot indicators for chart, image, and tag completeness
- ✖ delete icon removes the registry entry; also archives the post directory to `archive/` — **local only**

### Edit Selected Post tab

- Full metadata editing form with Load / Save / Clear / Back to Posts controls
- Summary panels: total posts, published, unpublished, missing fields

### Sidebar

| Control | Local | Cloud |
|---------|-------|-------|
| Refresh data | ✅ | ✅ |
| Create new post | ✅ | — |
| Download registry CSV | — | ✅ |
| Sign out | — | ✅ |
| Filters (status, publication, search) | ✅ | ✅ |

## Creating posts

Two workflows (local only):

1. **Sidebar "Create new post"** — enter a title, click create. Runs `new_post.sh` to scaffold the directory and auto-registers the post with status `idea`.
2. **Setup icon (⚙️) in Posts tab** — for registry entries that don't yet have a directory. Uses `draft_started` date (or today) for the directory name.

## Post directory structure

`new_post.sh` creates:

```
posts/YYYY/YYYY-MM-DD-slug/
├── index.qmd    # Pre-filled with title and date from _template/index.qmd
└── images/      # Empty subfolder for post assets
```

## Deploying to Connect Cloud

Use `deploy.R` to sync the local registry and redeploy the dashboard in one step:

```r
source("deploy.R")
deploy_dashboard()
```

This copies `docs/blog_registry.csv` → `shiny/blog_registry.csv` before deploying, so the cloud app always starts with the latest local registry.

**Syncing edits made in the cloud app back to local:**

1. Click **"Download registry CSV"** in the app sidebar
2. Save the file over `docs/blog_registry.csv`
3. Run `deploy_dashboard()` when ready to redeploy

## Quarto site

The site listing in `index.qmd` uses `contents: "posts/**/*.qmd"` to recursively discover all posts across year directories. Output renders to `_site/`.
