#!/bin/bash

# This script fetches the latest Debian release codename.

# Fetch the release codenames and version numbers
# The curl command fetches the stable file from debian.org.
# The grep command filters out lines containing 'Codename:'.
# The tail command gets the last line of the filtered output, which corresponds to the latest release.
# The cut command extracts the second field from the line, which is the codename of the release.
codename=$(curl -s https://deb.debian.org/debian/dists/stable/Release | grep 'Codename:' | tail -1 | cut -d ' ' -f 2)

# Print the codename
echo "$codename"