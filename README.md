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
│   └── blog_registry.csv         # Post metadata registry
├── shiny/app.R                   # Workflow dashboard
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

### Posts tab

- Filterable data table with inline status and publication dropdowns (color-coded)
- 📄 icon shows file path on hover; ⚙️ icon scaffolds the post directory on click (becomes ✅ when directory exists)
- Post titles are clickable links that load the Edit tab
- Green/red dot indicators for chart, image, and tag completeness
- ✖ delete icon archives the post directory and removes the registry entry

### Edit Selected Post tab

- Full metadata editing form with Load / Save / Clear / Back to Posts controls
- Summary panels: total posts, published, unpublished, missing fields

### Sidebar

- Refresh data, create new post (runs `new_post.sh`)
- Filter by status, publication, text search
- Toggle to show only posts missing key metadata

## Creating posts

Two workflows:

1. **Sidebar "Create new post"** — enter a title, click create. Runs `new_post.sh` to scaffold the directory and auto-registers the post with status `idea`.
2. **Setup icon (⚙️) in Posts tab** — for registry entries that don't yet have a directory. Uses `draft_started` date (or today) for the directory name.

## Post directory structure

`new_post.sh` creates:

```
posts/YYYY/YYYY-MM-DD-slug/
├── index.qmd    # Pre-filled with title and date from _template/index.qmd
└── images/      # Empty subfolder for post assets
```

## Quarto site

The site listing in `index.qmd` uses `contents: "posts/**/*.qmd"` to recursively discover all posts across year directories. Output renders to `_site/`.
