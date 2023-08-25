#!/usr/bin/env bash
set -e

docker_image="$1"
search_term="$2"

docker_tar="/tmp/io.orleans.check-container-image/$(basename "$docker_image").tar"
untar_dir="/tmp/io.orleans.check-container-image/$(basename -s .tar "$docker_tar")"

function l() {
  >&2 echo "$1"
}

function save_tar() {
  if [ -f "$docker_tar" ]; then
    l "Found image tar"
  else
    l "Saving image '$docker_image' to tar"
    docker save --output "$docker_tar" "$docker_image"
  fi
}

function untar() {
  if [ -d "$untar_dir" ]; then
    l "Found untarred $docker_tar"
  else
    l "Fully untarring $docker_tar"

    mkdir -p "$untar_dir"
    tar -xzf "$docker_tar" --directory "$untar_dir"

    for tar in "$untar_dir"/**/*.tar; do
      l "Untarring layer $(basename "$(dirname "$tar")")"
      tar -xzf "$tar" --directory "$(dirname "$tar")"
      rm "$tar"
    done
  fi
}

function search() {
  l "Searching for $search_term"
  grep --recursive --color=always \
    "$search_term" "$untar_dir"
}

function main() {
  save_tar
  untar
  search
}

main
