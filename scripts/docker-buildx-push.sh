#!/bin/env bash

if [ -z "$RUNNER_IMAGE" ]; then
  echo "RUNNER_IMAGE is not set. Please set it to the name of the image to be built and pushed."
  echo "Do also make sure that you have logged in to the registry. Head to https://hub.docker.com/settings/security?generateToken=true to generate a token for docker-login."
  exit 1
fi

set -evx

# We explicitly say `buildx build` because
# docker buildx --platform or docker build --platform doesn't work as we might have expected

docker buildx build --platform linux/arm64,linux/amd64 -t ${RUNNER_IMAGE} \
  --push -f Dockerfile .
