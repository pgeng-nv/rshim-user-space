current_branch=$(git rev-parse --abbrev-ref HEAD)
latest_tag=$(git tag --list "rshim-[0-9]*.[0-9]*.[0-9]*" --merged "$current_branch" | sort -V | tail -n 1)
version=$(git describe --always --tags --match "$latest_tag" --long)
version=${version#rshim-}   # remove prefix "rshim-"
echo $version
