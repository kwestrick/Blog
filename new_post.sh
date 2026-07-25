#!/usr/bin/env bash
# Scaffold a new blog post directory from _template/.
#
# Usage:
#   ./new_post.sh "My New Post Title"
#
# Creates posts/YYYY/YYYY-MM-DD-my-new-post-title/ with an index.qmd
# copied from the template, an images/ subdirectory, and the title
# and date pre-filled in the frontmatter.

set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: $0 \"Post Title\"" >&2
  exit 1
fi

title="$1"
date_prefix=$(date +%Y-%m-%d)
year=$(date +%Y)

# Slugify: lowercase, spaces/underscores -> hyphens, strip non-alphanumerics
slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | tr ' _' '-' | tr -cd 'a-z0-9-')

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
post_dir="${script_dir}/posts/${year}/${date_prefix}-${slug}"

if [[ -d "$post_dir" ]]; then
  echo "Error: $post_dir already exists." >&2
  exit 1
fi

mkdir -p "$post_dir/images"
dest_file="${post_dir}/index.qmd"
cp "${script_dir}/_template/index.qmd" "$dest_file"

# Fill in title and date in the frontmatter
sed -i '' "s/^title: \"Post Title\"/title: \"${title}\"/" "$dest_file"
sed -i '' "s/^date: today/date: ${date_prefix}/" "$dest_file"

echo "Created ${post_dir}/index.qmd"
echo "Reminder: if this post uses any new R packages, run rsconnect::writeManifest()" \
     "and commit the updated manifest.json before pushing."
