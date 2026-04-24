#
ls s*-eth*.pcap | \
  xargs -I{} sh -c 'tcpdump -qnr "{}" 2>/dev/null | \
  sed "s/^/{} /"' | \
  sort -k2 | \
  awk '{printf "%-8s %s\n", substr($1,4,length($1)-8), substr($0,length($1)+3)}'
