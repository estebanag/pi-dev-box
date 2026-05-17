#!/bin/sh
set -e

cp -r /home/ubuntu/.pi-defaults/. /home/ubuntu/.pi/

if curl --max-time 2 -sf http://litellm:4000/health/liveliness > /dev/null 2>&1; then
  jq -s '.[0] * .[1]' \
    /home/ubuntu/.pi/agent/models.json \
    /home/ubuntu/.pi-defaults/agent/models.proxy.json \
    > /tmp/models-merged.json
  mv /tmp/models-merged.json /home/ubuntu/.pi/agent/models.json
fi

exec pi
