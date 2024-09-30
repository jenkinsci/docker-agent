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

# Declare an array to maintain the original order of tags
ordered_tags=()

# Iterate over the parsed JSON to populate the associative array and ordered array
while IFS= read -r line; do
  published_date=$(echo "$line" | jq -r '.published_date')
  tags=$(echo "$line" | jq -r '.tags[]')

  for tag in $tags; do
    # Filter tags that contain a hyphen
    if [[ $tag == *-* ]]; then
      # Check if a more complete tag exists
      base_tag=${tag%%.*}
      if [[ -n "${tag_dates[$base_tag]}" && "$tag" != "$base_tag" ]]; then
        # If a more complete tag exists, skip the incomplete tag
        echo "a more complete tag exists for $tag, skip the incomplete tag for base tag $base_tag"
        continue
      fi
      # Update the published_date if the current date is more recent or the same
      if [[ -z "${tag_dates[$tag]}" || ! "$published_date" < "${tag_dates[$tag]}" ]]; then
        tag_dates[$tag]=$published_date
      fi
      # Add the tag to the ordered array if it's not already present
      if [[ ! " ${ordered_tags[*]} " =~ " ${tag} " ]]; then
        ordered_tags+=("$tag")
      fi
    fi
  done
done <<< "$all_tags"

# Custom sort function with correct order
sort_tags() {
  printf "%s\n" "${ordered_tags[@]}" | sort -t '-' -k1,1n -k2,2n -k2.1,2.3n -k2.5,2.12n
}

# Print the sorted array and their corresponding published dates
for tag in $(sort_tags | tac); do
#  echo "Tag: $tag, Published Date: ${tag_dates[$tag]}"
  echo "$tag"
done
