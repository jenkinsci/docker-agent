#!/bin/bash

# This script fetches the latest Ubuntu LTS release codename and adds a "-jdk-" prefix to it.

# Fetch the LTS release codenames and version numbers
# The curl command fetches the meta-release-lts file from changelogs.ubuntu.com.
# The grep command filters out lines containing 'Dist:'.
# The tail command gets the last line of the filtered output, which corresponds to the latest LTS release.
# The cut command extracts the second field from the line, which is the codename of the release.
codename=$(curl -s https://changelogs.ubuntu.com/meta-release-lts | grep 'Dist:' | tail -1 | cut -d ' ' -f 2)

# Add the prefix "-jdk-" to the codename
# The echo command prints the string "-jdk-" concatenated with the value of `codename`.
# This results in the output "-jdk-latestUbuntuCodeName".
echo "-jdk-$codename"
