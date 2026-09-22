---
name: network-reachability-diagnostics
description: "Use when asked to ping a host or check if an IP is up."
version: 0.1.0
metadata:
  hermes:
    tags: [Networking, Ping, Troubleshooting, LAN, Diagnostics]
    editorial_name: Network Reachability Diagnostics
    editorial_description: Decide whether a host is down, unreachable, or merely not answering pings — using ARP evidence and control targets, not just ICMP loss.
    requires_tools: [terminal]
---

# Network Reachability Diagnostics

Answers "is this host up?" with evidence, and separates three causes a bare `ping` cannot tell apart: the host is absent, the host is up but drops ICMP, or the probe never left this machine. Class of task: "faça um ping no IP X", checking a server / device / NVR / printer on the LAN, confirming a machine came back after a power event, "por que não responde?".

Run the bundled probe instead of hand-typing the sequence: `bash scripts/reachability-probe.sh <ip>` from this skill's directory (it needs `iproute2` + `iputils`; `nmap` enriches the output when present and is skipped when not).

## Procedure

### 1. Read the target literally; never silently repair it

A malformed address (octets split by commas, dashes, spaces, or a stray digit) is not yours to normalise. Test each plausible reading, label the results by reading, and lead the report with the interpretation you used. The user often follows up mid-task with the real value — take that follow-up as the target, say so, and drop the earlier readings to one line of context rather than re-litigating them.

### 2. Establish controls before judging the target

```bash
GW=$(ip route show default | awk '/via/{print $3; exit}')
ping -n -c 3 -W 2 "$GW"; ping -n -c 3 -W 2 8.8.8.8
```

Both controls up means this host's stack, ICMP egress and the local segment are fine, so any loss on the target is a property of the target. Both controls down means the fault is local (link, DHCP, VPN) and the target was never reached — say that instead of reporting the target as dead. Also print `ip -4 route get <target>`: it names the egress interface and source address, which is what makes a "not on this segment" call defensible.

### 3. Probe the target, then read layer 2

```bash
ping -n -c 4 -W 2 <target>
ip neigh show <target>          # the decisive evidence
```

- `REACHABLE` / `STALE` with an `lladdr` → the device is present and answered ARP; packet loss is then an ICMP policy or firewall question, not an absence.
- `FAILED` / `INCOMPLETE` → nothing on the segment owns that IP. A firewall that drops ICMP still answers ARP, so a failed ARP is positive evidence the host is down, unplugged, or on another VLAN.

`ip neigh` needs no privileges; `arping` opens a raw socket and is unavailable to an unprivileged shell, so prefer `ip neigh` as the routine L2 probe.

### 4. Name the host

Reverse DNS resolves even for dead hosts, so it identifies *what* is down:

```bash
getent hosts <target>            # e.g. MOV-ERP-001.MOVPLAN.LOCAL
```

The resolved name is what makes the report useful ("o servidor de ERP está fora do ar"), since the user knows their services by name, not by address.

### 5. Add a port check last, and only as corroboration

```bash
nmap -sn <target>                                # discovery — the liveness test
nmap -Pn -p 22,80,443,3389,5900 <target>         # -Pn assumes up; corroboration only
```

`filtered` on every port alongside a failed ARP corroborates absence. `filtered` alongside a resolved ARP means a host firewall. Validate the tooling once against a known-live neighbour in the same subnet so a silent `nmap` misconfiguration cannot masquerade as "host down".

## Pitfalls

- **`-Pn` output is not a liveness result.** `nmap -Pn` skips host discovery and prints "Host is up" unconditionally, so it proves nothing; only `-sn` (or ARP state) decides up/down. Quoting the `-Pn` line as evidence contradicts the `-sn` line printed next to it.
- **A resolved name is not reachability.** Internal DNS keeps a record for a powered-off machine; name resolution and ARP state must be read independently before concluding.
- **Reporting "ping blocked" without ARP evidence** is a guess. Without a resolved `lladdr`, ICMP filtering cannot be distinguished from absence, and the guess sends the user chasing a firewall rule for a machine that is simply off.
- **Two IPv4 addresses on one NIC** is a real misconfiguration (DHCP conflict or a duplicated static) and can make ARP replies inconsistent for both the target and the probe — flag it as an observation, do not silently pick one source address.
- **A broadcast ping to sweep the subnet** is intrusive on a corporate LAN; get consent before probing addresses the user did not name.

## Reporting

Brazilian Portuguese, verdict first: *não responde / está fora do ar*, then the evidence in the order that supports it — ping loss, ARP state, resolved name, port states — then the control results in their own block so the user can see the probe path was healthy. Close with the plain-language reading (down / unplugged / another VLAN) and any config observation worth acting on. Keep the raw command transcripts out.

## Verification

- [ ] Target read literally; any repair of a malformed address was stated as an interpretation.
- [ ] Control targets (gateway + a public anchor) probed and quoted.
- [ ] Layer-2 state (`ip neigh`) quoted before calling the host absent or filtered.
- [ ] Host name resolved so the report identifies the service, not just the address.
- [ ] No liveness claim rests on `nmap -Pn` output.
