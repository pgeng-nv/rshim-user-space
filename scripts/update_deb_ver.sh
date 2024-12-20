#!/bin/bash -e

new_version=$1

# Update the topmost version in debian/changelog
# Extract the current version format and replace it with the new version
changelog_file="debian/changelog"
sed -i "1s/\((.*)\)/($new_version)/" "$changelog_file"

echo "Updated $changelog_file with version: $new_version"
