#!/bin/bash

if [ "RUN_DOCKERD" = "true" ]; then
  sudo /usr/bin/dockerd &
fi

exec "$@"
