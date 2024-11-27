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
curl --silent --fail --location --verbose --header 'accept: application/json' "$URL" \
    | jq --sort-keys 'first(.data[].repositories[].signatures[].tags)[]') \
    | xargs `# Trim eventual whitespaces`

exit 0
