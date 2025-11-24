#!/usr/bin/env bash
docker build -t rpi-rt-builder .
docker run -v $(pwd):/output rpi-rt-builder