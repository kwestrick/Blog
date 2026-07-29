# sync_registry.R
#
# Scans all posts/**/index.qmd files, reads YAML front matter, and syncs
# metadata into docs/blog_registry.csv.
#
# Match strategy: post_id (primary) → path (fallback).
# Posts found on disk but absent from the registry are added as new rows.
#
# Fields synced from QMD → registry (QMD is authoritative):
#   title, path, image_path, tags (from categories)
#   draft_started  — filled only if currently blank
#   published_date — filled only if draft: false and currently blank
#   status         — set to "published" only if draft: false and currently unassigned
#
# Fields never overwritten (editorial-only, registry is authoritative):
#   lead_quote, gist, notes, publication, status (except unassigned → published)

library(tidyverse)
library(yaml)

registry_path <- "docs/blog_registry.csv"
posts_root    <- "posts"

# ── Helpers ───────────────────────────────────────────────────────────────────

# Parse YAML front matter block from a .qmd / .rmd file
read_front_matter <- function(path) {
  lines <- readLines(path, warn = FALSE)
  if (length(lines) < 2 || lines[1] != "---") return(list())
  ends <- which(lines == "---")
  if (length(ends) < 2) return(list())
  tryCatch(
    yaml::yaml.load(paste(lines[2:(ends[2] - 1)], collapse = "\n")),
    error = function(e) list()
  )
}

null_to_blank <- function(x) if (is.null(x)) "" else as.character(x)
null_to_na    <- function(x) if (is.null(x)) NA  else x

cats_to_tags <- function(cats) {
  if (is.null(cats) || length(cats) == 0) return("")
  paste(trimws(cats), collapse = "; ")
}

# ── Scan all index.qmd files ──────────────────────────────────────────────────

qmd_files <- list.files(
  posts_root, pattern = "^index\\.qmd$",
  recursive = TRUE, full.names = TRUE
)

cat(sprintf("Scanning %d post files...\n", length(qmd_files)))

scanned <- map(qmd_files, function(f) {
  ym <- read_front_matter(f)
  list(
    file_path  = f,
    path       = dirname(f),           # e.g. posts/2026/2026-07-25-slug
    post_id    = null_to_blank(ym$post_id),
    title      = null_to_blank(ym$title),
    date       = null_to_na(ym$date),
    draft      = isTRUE(ym$draft),
    image      = null_to_blank(ym$image),
    categories = cats_to_tags(ym$categories)
  )
})

# ── Load registry ─────────────────────────────────────────────────────────────

reg <- read_csv(registry_path, show_col_types = FALSE) |>
  mutate(
    post_id        = as.character(post_id),
    draft_started  = as.Date(draft_started),
    published_date = as.Date(published_date),
    across(
      c(title, lead_quote, gist, status, publication, path, tags, notes, chart_path, image_path),
      \(x) replace_na(as.character(x), "")
    )
  )

# ── Sync ──────────────────────────────────────────────────────────────────────

changes <- character(0)

for (s in scanned) {

  # --- Match registry row ---
  idx <- if (s$post_id != "") which(reg$post_id == s$post_id) else integer(0)
  if (length(idx) == 0) idx <- which(reg$path == s$path)

  # --- New post: add to registry ---
  if (length(idx) == 0) {
    new_id <- if (s$post_id != "") {
      s$post_id
    } else {
      as.character(max(as.integer(reg$post_id), na.rm = TRUE) + 1L)
    }
    reg <- bind_rows(reg, tibble(
      post_id        = new_id,
      title          = s$title,
      lead_quote     = "",
      gist           = "",
      notes          = "",
      draft_started  = if (!s$draft && !is.na(s$date)) as.Date(s$date) else as.Date(NA),
      published_date = if (!s$draft && !is.na(s$date)) as.Date(s$date) else as.Date(NA),
      status         = if (s$draft) "drafting" else "published",
      publication    = "unassigned",
      path           = s$path,
      tags           = s$categories,
      chart_path     = "",
      image_path     = s$image
    ))
    changes <- c(changes, sprintf("  [+] Added:   '%s'  (%s)", s$title, s$path))
    next
  }

  idx <- idx[1]

  # --- Update existing row ---

  if (s$title != "" && reg$title[idx] != s$title) {
    changes <- c(changes, sprintf("  [~] title:      '%s'  ->  '%s'", reg$title[idx], s$title))
    reg$title[idx] <- s$title
  }

  if (reg$path[idx] != s$path) {
    changes <- c(changes, sprintf("  [~] path:       '%s'  ->  '%s'", reg$path[idx], s$path))
    reg$path[idx] <- s$path
  }

  if (reg$image_path[idx] != s$image) {
    changes <- c(changes, sprintf("  [~] image_path: '%s'  ->  '%s'", reg$image_path[idx], s$image))
    reg$image_path[idx] <- s$image
  }

  if (reg$tags[idx] != s$categories) {
    changes <- c(changes, sprintf("  [~] tags:       '%s'  ->  '%s'", reg$tags[idx], s$categories))
    reg$tags[idx] <- s$categories
  }

  # Fill draft_started only if blank
  if (is.na(reg$draft_started[idx]) && !is.na(s$date)) {
    reg$draft_started[idx] <- as.Date(s$date)
    changes <- c(changes, sprintf("  [~] draft_started filled: %s", s$date))
  }

  # If post is marked published in QMD, fill published_date and update status
  if (!s$draft) {
    if (is.na(reg$published_date[idx]) && !is.na(s$date)) {
      reg$published_date[idx] <- as.Date(s$date)
      changes <- c(changes, sprintf("  [~] published_date filled: %s", s$date))
    }
    if (reg$status[idx] == "unassigned") {
      reg$status[idx] <- "published"
      changes <- c(changes, sprintf("  [~] status: unassigned -> published"))
    }
  }
}

# ── Write updated registry ────────────────────────────────────────────────────

write_csv(reg, registry_path, na = "")

# ── Report ────────────────────────────────────────────────────────────────────

cat(sprintf("\n=== sync_registry: %d posts scanned, %d registry rows ===\n",
            length(scanned), nrow(reg)))

if (length(changes) > 0) {
  cat(sprintf("\n%d change(s) applied:\n", length(changes)))
  cat(paste(changes, collapse = "\n"), "\n")
} else {
  cat("\nRegistry is already up to date — no changes needed.\n")
}

# Missing-field audit
missing_summary <- reg |>
  rowwise() |>
  mutate(
    missing = {
      m <- c(
        if (lead_quote == "")           "lead_quote",
        if (gist       == "")           "gist",
        if (status     == "unassigned") "status",
        if (publication == "unassigned") "publication",
        if (image_path == "")           "image_path"
      )
      paste(m, collapse = ", ")
    }
  ) |>
  ungroup() |>
  filter(missing != "") |>
  select(post_id, title, missing)

cat(sprintf("\n── Missing-field audit (%d / %d posts incomplete) ──────────\n",
            nrow(missing_summary), nrow(reg)))

if (nrow(missing_summary) > 0) {
  print(missing_summary, n = Inf)
} else {
  cat("All posts have complete metadata.\n")
}
