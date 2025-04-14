FROM alpine:latest

RUN apk add --no-cache curl jq tar gzip tzdata bash

ENV TZ=UTC

RUN mkdir -p /shared-logs /tmp/logs

COPY archive-logs.sh /usr/local/bin/archive-logs.sh
RUN chmod +x /usr/local/bin/archive-logs.sh

WORKDIR /tmp