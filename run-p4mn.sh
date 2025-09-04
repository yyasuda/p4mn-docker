#!/usr/bin/env bash
set -euo pipefail

# default loglevel is warn. (trace, debug, info, warn, error, off)
#  if you need P4 behavior, use -e LOGLEVEL=debug to override this.
LOGLEVEL="${LOGLEVEL:-warn}"

# default packet dump option is off. use -e PKTDUMP=true to enable.
PKTDUMP="${PKTDUMP:-false}"

SWITCH_OPTS="simple_switch_grpc,loglevel=${LOGLEVEL}"
if [[ "${PKTDUMP}" == "true" ]]; then
  SWITCH_OPTS+=",pktdump=true"
fi

# "$@" is additonal argument of docker run, pass it to "mn".
exec mn \
  --custom /root/bmv2.py \
  --switch "${SWITCH_OPTS}" \
  --host onoshost \
  --controller none \
  "$@"
