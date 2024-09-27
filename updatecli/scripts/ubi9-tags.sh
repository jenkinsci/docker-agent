#!/bin/bash

# This script fetches all tags from the Red Hat Container Catalog API for UBI9 images.
# It ensures that `jq` and `curl` are installed, fetches the tags, and processes them to find all unique tags.

# Correct URL of the Red Hat Container Catalog API for UBI9
URL="https://catalog.redhat.com/api/containers/v1/repositories/registry/registry.access.redhat.com/repository/ubi9/images?page_size=100&page=0&sort_by=last_update_date%5Bdesc%5D"

# Check if jq and curl are installed
if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    echo "jq and curl are required but not installed. Exiting with status 1." >&2
    exit 1
fi

# Fetch the tags using curl
response=$(curl -s "$URL" -H 'accept: application/json')

# Check if the response is empty or null
if [ -z "$response" ] || [ "$response" == "null" ]; then
  echo "Error: Failed to fetch tags from the Red Hat Container Catalog API."
  exit 1
fi

# Parse the JSON response using jq to find all tags and their published dates
all_tags=$(echo "$response" | jq -c '.data[] | {published_date: .repositories[].published_date, tags: .repositories[].signatures[].tags}')

# Check if the all_tags is empty
if [ -z "$all_tags" ]; then
  echo "Error: No valid tags found."
  exit 1
fi

# Declare an associative array to store tags and their published dates
declare -A tag_dates

# Iterate over the parsed JSON to populate the associative array
while IFS= read -r line; do
  published_date=$(echo "$line" | jq -r '.published_date')
  tags=$(echo "$line" | jq -r '.tags[]')

  for tag in $tags; do
    # Update the published_date if the current date is more recent
    if [[ -z "${tag_dates[$tag]}" || "$published_date" > "${tag_dates[$tag]}" ]]; then
      tag_dates[$tag]=$published_date
    fi
  done
done <<< "$all_tags"

# Print the associative array
for tag in "${!tag_dates[@]}"; do
  echo "Tag: $tag, Published Date: ${tag_dates[$tag]}"
done
