#!/bin/bash

# This script fetches the Debian release codename.

# Check if an argument is provided. If not, set it to 0.
if [ -z "$1" ]; then
  argument=0
else
  argument=$1
fi

# Fetch the release codenames and version numbers
# The curl command fetches the Release file from the repository.
# The grep command filters out lines containing 'Codename:'.
# The cut command extracts the second field from the line, which is the codename of the release.

if [ $argument -eq 0 ]; then
  # If argument is 0, fetch the latest LTS codename.
  codename=$(curl -s https://deb.debian.org/debian/dists/stable/Release | grep 'Codename:' | cut -d ' ' -f 2)
elif [ $argument -eq 1 ]; then
  # If argument is 1, fetch the oldstable LTS codename.
  codename=$(curl -s https://deb.debian.org/debian/dists/oldstable/Release | grep 'Codename:' | cut -d ' ' -f 2)
else
  # If argument is not 0 or 1, print an error message and exit.
  echo "Fetching LTS releases other than the latest and oldstable is not supported."
  exit 1
fi

# Print the codename
echo "$codename"
