FROM debian:stable

COPY packages.txt /tmp/packages.txt

RUN apt-get update && \
    xargs -a /tmp/packages.txt apt-get install -y && \
    apt-get clean

WORKDIR /testbench

