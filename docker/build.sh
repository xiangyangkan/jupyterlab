#!/bin/bash
WORKING_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ENABLE_PRUNE="false"

function docker_prune() {
    if [ "$ENABLE_PRUNE" = "true" ]; then
      docker system prune -a -f || exit 1
    fi
}

function build_substreams_image() {
    local python_version="$1"
    local nodejs_version="$2"
    local cmake_version="$3"
    local buf_version="$4"
    local substreams_version="$5"
    local base_image="ubuntu:24.04"
    local stage_1_image="substreams:base"
    local stage_2_image="substreams:conda"
    local stage_3_image="substreams:build"
    local final_image="rivia/substreams:${substreams_version}"
    docker build --target base --build-arg BASE_IMAGE="$base_image" \
      -t $stage_1_image -f Dockerfile . || exit 1
    docker build --target conda --build-arg BASE_IMAGE="$stage_1_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_2_image -f Dockerfile . || exit 1
    docker build --target devel --build-arg BASE_IMAGE="$stage_2_image" --build-arg PYTHON_VERSION="$python_version" \
      -t $stage_3_image -f Dockerfile . || exit 1
    docker build --target build --build-arg BASE_IMAGE="$stage_3_image" --build-arg NODEJS_VERSION="$nodejs_version" \
      --build-arg CMAKE_VERSION="$cmake_version" --build-arg BUF_VERSION="$buf_version" \
      -t $final_image -f Dockerfile . || exit 1
    docker push $final_image && docker_prune
}

PYTHON_VERSION="3.12"
NODEJS_VERSION="23.9.0"
CMAKE_VERSION="4.0.0"
BUF_VERSION="1.51.0"
SUBSTREAMS_VERSION="1.15.0"

dos2unix ./*
build_substreams_image "$PYTHON_VERSION" "$NODEJS_VERSION" "$CMAKE_VERSION" "$BUF_VERSION" "$SUBSTREAMS_VERSION"