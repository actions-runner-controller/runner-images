# runner-images

This is an ongoing effort to provide a set of Docker images for GitHub Actions self-hosted runners.

It's maintained and driven by the community so that
we can try to go beyond the bandwidth of GitHub Actions team. The Actions team focus more on the core ARC and Actions. We, the community, focus more on our own use-cases and runner images needed for those.

This project was inspired by and started as a fork of [quipper/actions-runner](https://github.com/quipper/actions-runner). Much appreciation to the folks Quipper for sharing their awesome work!

## Features

- We fork and occasionally rebase onto [actions/runner official Dockerfile](https://github.com/actions/runner/blob/main/images/Dockerfile) for both compatibility and more features.
- We DON'T provide `latest` only because we'd love to NOT break your production environments when we introduce backward-incompatible changes to the images.
- Single `Dockerfile` for multiple use-cases and runner modes.

## Usage

- You can specify "RUN_DOCKERD=true" to start a dind daemon within the runner container.
