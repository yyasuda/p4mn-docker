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

# IPv6 on/off option. use -e IPV6=false to disable IPv6.
IPV6="${IPV6:-true}"
if [[ "${IPV6}" == "false" ]]; then
    # ===== IPv6 off in root ns (and defaults for future namespaces) =====
    sysctl -q -w net.ipv6.conf.all.disable_ipv6=1
    sysctl -q -w net.ipv6.conf.default.disable_ipv6=1
    sysctl -q -w net.ipv6.conf.lo.disable_ipv6=1
    # RA/autoconf disabled (just in case) 
    sysctl -q -w net.ipv6.conf.all.accept_ra=0
    sysctl -q -w net.ipv6.conf.default.accept_ra=0
    sysctl -q -w net.ipv6.conf.all.autoconf=0
    sysctl -q -w net.ipv6.conf.default.autoconf=0
fi

# "$@" is additonal argument of docker run, pass it to "mn".
exec mn \
  --custom /root/bmv2.py \
  --switch "${SWITCH_OPTS}" \
  --host onoshost \
  --controller none \
  "$@"
