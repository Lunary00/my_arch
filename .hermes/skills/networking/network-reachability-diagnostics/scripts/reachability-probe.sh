#!/usr/bin/env bash
# Reachability probe: controls first, then target ICMP + layer-2 evidence + name + ports.
# Usage: reachability-probe.sh <ip-or-host> [more...]
# Needs iproute2 (ip) and iputils (ping); nmap is optional and skipped if absent.

set -uo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <ip-or-host> [more...]" >&2
  exit 2
fi

GW=$(ip route show default 2>/dev/null | awk '/via/{print $3; exit}')

echo "== CONTROLES (se falharem, o problema e local) =="
for c in ${GW:-} 8.8.8.8; do
  [ -z "$c" ] && continue
  out=$(ping -n -c 3 -W 2 "$c" 2>/dev/null)
  loss=$(printf '%s' "$out" | sed -n 's/.*, \([0-9]*\)% packet loss.*/\1/p')
  echo "  $c: perda=${loss:-?}%"
done

for t in "$@"; do
  echo
echo "== ALVO: $t =="
  echo "  rota        : $(ip -4 route get "$t" 2>/dev/null | head -1 | tr -s ' ')"

  out=$(ping -n -c 4 -W 2 "$t" 2>/dev/null)
  loss=$(printf '%s' "$out" | sed -n 's/.*, \([0-9]*\)% packet loss.*/\1/p')
  rtt=$(printf '%s' "$out" | sed -n 's/^rtt .* = \(.*\)$/\1/p')
  echo "  ping        : perda=${loss:-?}%${rtt:+ rtt=$rtt}"

  neigh=$(ip neigh show "$t" 2>/dev/null | head -1 | tr -s ' ')
  state=$(printf '%s' "$neigh" | awk '{print $NF}')
  if [ -z "$neigh" ]; then
    echo "  arp (L2)    : sem entrada"
  elif printf '%s' "$state" | grep -qE 'FAILED|INCOMPLETE'; then
    echo "  arp (L2)    : $state -> ninguem responde ARP nesse IP (host ausente do segmento)"
  else
    echo "  arp (L2)    : $state -> dispositivo presente; perda de ICMP = politica/firewall"
  fi

  name=$(getent hosts "$t" 2>/dev/null | awk '{print $2; exit}')
  echo "  nome        : ${name:-<sem DNS reverso>}"

  if command -v nmap >/dev/null 2>&1; then
    sn=$(nmap -sn "$t" 2>/dev/null)
    if printf '%s' "$sn" | grep -q '1 host up'; then
      echo "  nmap -sn    : host up (discovery)"
    else
      echo "  nmap -sn    : host down (discovery)"
    fi
    ports=$(nmap -Pn -p 22,80,443,3389,5900 "$t" 2>/dev/null | awk '/^[0-9]+\/tcp/{printf "%s %s; ", $1, $2}')
    echo "  portas -Pn  : ${ports:-<sem resposta>} (corroboracao; -Pn sempre diz up)"
  else
    echo "  nmap        : nao instalado, etapa ignorada"
  fi
done
