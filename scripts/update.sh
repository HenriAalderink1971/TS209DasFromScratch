#!/bin/sh
git submodule update --init --recursive
docker-compose build

