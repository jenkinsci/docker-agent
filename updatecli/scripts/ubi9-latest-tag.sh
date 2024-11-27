#!/bin/bash

# This script fetches the latest tag from the Red Hat Container Catalog API for UBI9 images.
# It ensures that `jq` and `curl` are installed, fetches the tags, and processes them to find the unique tag.

# The Swagger API endpoints for the Red Hat Container Catalog API are documented at:
# https://catalog.redhat.com/api/containers/v1/ui/#/Repositories/graphql.images.get_images_by_repo

# Correct URL of the Red Hat Container Catalog API for UBI9
URL="https://catalog.redhat.com/api/containers/v1/repositories/registry/registry.access.redhat.com/repository/ubi9/images?page_size=10&page=0&sort_by=last_update_date%5Bdesc%5D"

# Check if jq and curl are installed
# If they are not installed, exit the script with an error message
if ! command -v jq >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
    >&2 echo "jq and curl are required but not installed. Exiting with status 1." >&2
    exit 1
fi

# Fetch the tags using curl
# curl --silent --fail --location --header 'accept: application/json' "$URL"
response=$(curl --silent --fail --location --verbose --header 'accept: application/json' "$URL")

# Check if the response is empty or null
if [ -z "$response" ] || [ "$response" == "null" ]; then
  >&2 echo "Error: Failed to fetch tags from the Red Hat Container Catalog API."
  exit 1
fi

# Parse the JSON response using jq to find the "latest" tag and its associated tags
latest_tag="$(echo "$response" | jq --sort-keys 'first(.data[].repositories[].signatures[].tags)[]'"

# Check if the latest_tag is empty
if [ -z "$latest_tag" ]; then
  >&2 echo "Error: No valid tags found."
  exit 1
fi

# Sort and remove duplicates
unique_tag=$(echo "$latest_tag" | sort | uniq | grep -v latest | grep "-")

# Trim spaces
unique_tag=$(echo "$unique_tag" | xargs)
echo "$unique_tag"
exit 0
