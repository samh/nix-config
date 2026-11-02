#!/usr/bin/env python3
"""Low-rate IPv4 diagnostics; logs rotate at 10 MiB, retaining ten files.

Run --help for usage. No root access, listening ports, or packet capture needed.
"""
import argparse
import collections
import concurrent.futures
import datetime
import ipaddress
import json
import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import threading
import time


def timestamp():
    return datetime.datetime.now().astimezone().isoformat(timespec="milliseconds")


def ipv4(value):
    try:
        return str(ipaddress.IPv4Address(value))
    except ipaddress.AddressValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc


def positive(value):
    number = float(value)
    if not 0 < number < float("inf"):
        raise argparse.ArgumentTypeError("must be positive and finite")
    return number


def classify(kind, code, output):
    """DNS exit status alone does not distinguish SERVFAIL from success."""
    if code:
        return "ERROR" if kind == "icmp" and code == 2 else "FAIL"
    if kind == "dns":
        return "OK" if re.search(r"status: NOERROR,", output) and re.search(
            r"ANSWER: [1-9][0-9]*", output
        ) else "FAIL"
    if kind == "https":
        return "OK" if re.search(r"http=2[0-9]{2}\b", output) else "FAIL"
    return "OK"


def probe(kind, command, timeout):
    started = timestamp()
    tick = time.monotonic()
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=timeout)
        output = result.stdout + result.stderr
        status = classify(kind, result.returncode, output)
        code = result.returncode
    except subprocess.TimeoutExpired:
        status, code, output = "FAIL", None, "probe timed out"
    except OSError as exc:
        status, code, output = "ERROR", None, str(exc)
    row = dict(started=started, finished=timestamp(), status=status,
               elapsed_ms=round((time.monotonic() - tick) * 1000, 2), exit_code=code)
    # Preserve result headers, timings and failure messages without large output.
    if kind == "dns":
        output = "\n".join(line for line in output.splitlines()
                           if "status:" in line or "Query time:" in line
                           or "SERVER:" in line or "communications error" in line
                           or "no servers" in line)
    row["detail"] = output.strip()[:1200]
    return row


# Ordered innermost-first: the ladder is read from inside the house outward.
TIER_ORDER = ("lan", "rg", "wan", "dns-lan", "dns-wan", "app", "other")


def tier_of(name):
    """Map a probe name onto its rung of the failure ladder.

    Position is what makes a capture interpretable. The same gap in connectivity
    means entirely different things depending on which rung stopped first.
    """
    kind, _, target = name.partition("-")
    if kind == "icmp":
        if target == "att-rg":
            return "rg"
        if target in {"cloudflare", "quad9"}:
            return "wan"
        return "lan"
    if kind == "dns":
        try:
            return "dns-lan" if ipaddress.ip_address(target).is_private else "dns-wan"
        except ValueError:
            return "dns-lan"
    if kind == "https":
        return "app"
    return "other"


def parse_time(value):
    try:
        return datetime.datetime.fromisoformat(value)
    except (TypeError, ValueError):
        return None


def read_rows(directory):
    """Return probe rows plus the capture interval, if a start event recorded it."""
    rows = []
    interval = None
    files = sorted(directory.glob("probes.jsonl*"), key=lambda path: path.stat().st_mtime)
    for path in files:
        with path.open() as stream:
            for line in stream:
                try:
                    row = json.loads(line)
                except json.JSONDecodeError:
                    continue  # A running writer may have an incomplete final line.
                if row.get("event") == "start":
                    interval = row.get("interval") or interval
                elif row.get("event") == "probe":
                    rows.append(row)
    return rows, interval


def failure_windows(rows, gap_seconds):
    """Group consecutive FAIL samples; success, ERROR, or a sampling gap ends a run.

    Bounds are failed-sample completion times, not measured outage durations.
    """
    samples = collections.defaultdict(list)
    for row in rows:
        moment = parse_time(row.get("finished"))
        if moment:
            samples[row["name"]].append((moment, row.get("status")))
    windows = []
    for name, entries in samples.items():
        start = previous = None
        for moment, status in sorted(entries, key=lambda entry: entry[0]):
            if start is not None and (
                status != "FAIL" or (moment - previous).total_seconds() > gap_seconds
            ):
                windows.append((name, start, previous))
                start = previous = None
            if status == "FAIL":
                if start is None:
                    start = moment
                previous = moment
        if start is not None:
            windows.append((name, start, previous))
    return windows


def cluster(windows, gap_seconds):
    """Merge per-probe windows that overlap in time into single incidents."""
    incidents = []
    for name, start, end in sorted(windows, key=lambda item: item[1]):
        if incidents and (start - incidents[-1]["end"]).total_seconds() <= gap_seconds:
            group = incidents[-1]
            group["end"] = max(group["end"], end)
            group["probes"].add(name)
        else:
            incidents.append({"start": start, "end": end, "probes": {name}})
    return incidents


def verdict(tiers):
    """Describe observations without treating missing failures as proof of health."""
    if len(tiers) > 1:
        return "MULTIPLE PROBE TYPES FAILED", (
            "correlated failures are observed; compare successful samples and "
            "direct-gateway measurements before attributing a cause")
    if tiers == {"lan"}:
        return "LAN TARGET FAILURE OBSERVED", (
            "an internal target failed; this alone does not establish a whole-LAN failure")
    if tiers == {"dns-lan"}:
        return "LOCAL DNS FAILURE OBSERVED", (
            "local DNS failed; verify simultaneous public DNS and HTTPS successes")
    if tiers == {"dns-wan"}:
        return "PUBLIC DNS FAILURE OBSERVED", (
            "a public resolver probe failed; the resolver or network path may be responsible")
    if tiers & {"wan", "app"}:
        return "PUBLIC PROBE FAILURE OBSERVED", (
            "a public probe failed; OPNsense, the gateway, ISP, and target remain possible causes")
    if tiers == {"rg"}:
        return "GATEWAY PING FAILURE OBSERVED", (
            "gateway ICMP failed; compare HTTPS and other probes before inferring an outage")
    return "UNCLASSIFIED FAILURE", "inspect individual samples before attributing a cause"


def summarize(directory):
    rows, interval = read_rows(directory)
    counts = collections.defaultdict(collections.Counter)
    last = {}
    failures = collections.deque(maxlen=30)
    for row in rows:
        name = row["name"]
        counts[name][row["status"]] += 1
        last[name] = row
        if row["status"] != "OK":
            failures.append(row)
    print("Retained samples (missing samples are not evidence of connectivity):")
    for name in sorted(counts, key=lambda value: (TIER_ORDER.index(tier_of(value)) if
                          tier_of(value) in TIER_ORDER else 99, value)):
        row = last[name]
        print(f"{name:25} {tier_of(name):8} OK={counts[name]['OK']:7} "
              f"FAIL={counts[name]['FAIL']:5} ERROR={counts[name]['ERROR']:4} "
              f"last={row['status']} {row['finished']}")

    gap = max(float(interval or 5) * 3, 15.0)
    incidents = cluster(failure_windows(rows, gap), gap)
    if not incidents:
        reason = ("no samples were read" if not rows else
                  "every sample was ERROR" if all(r["status"] == "ERROR" for r in rows) else
                  "no FAIL samples were recorded")
        print(f"\nNo incident windows: {reason}. ERROR means the probe could not run, "
              "and is excluded from windows by design.")
    else:
        print(f"\nFailure clusters ({len(incidents)}; windows merged within {gap:.0f}s; "
              "clusters may include recoveries and spans are not outage durations):")
        for incident in incidents:
            tiers = {tier_of(name) for name in incident["probes"]}
            seconds = (incident["end"] - incident["start"]).total_seconds()
            label, explanation = verdict(tiers)
            print(f"  {incident['start'].isoformat()} .. {incident['end'].isoformat()} "
                  f"failed-sample span={seconds:.0f}s  {label}")
            print(f"      tiers  : {', '.join(sorted(tiers, key=TIER_ORDER.index))}")
            print(f"      probes : {', '.join(sorted(incident['probes']))}")
            print(f"      read   : {explanation}")
    if failures:
        print("\nLast 30 unsuccessful samples:")
        for row in failures:
            print(row["started"], row["name"], row["status"], row["detail"].replace("\n", " "))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=Path("tmp/network-monitor"))
    parser.add_argument("--interval", type=positive, default=5, help="seconds per probe (default: 5)")
    parser.add_argument("--duration", type=positive, help="stop after this many seconds; default runs until stopped")
    parser.add_argument("--router", type=ipv4, default="192.168.5.1")
    parser.add_argument("--rg", type=ipv4, default="192.168.1.254")
    parser.add_argument("--dns", type=ipv4, action="append", help="repeatable; replaces the default local DNS servers")
    parser.add_argument("--direct", action="store_true", help="gateway-connected device: omit internal router/hosts and use public DNS")
    parser.add_argument("--summary", action="store_true", help="summarize retained logs in --out, then exit")
    args = parser.parse_args()
    if args.summary:
        summarize(args.out)
        return
    tools = {name: shutil.which(name) for name in ("ping", "dig", "curl")}
    if not all(tools.values()):
        parser.error("ping, dig and curl must all be installed")
    args.out.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("network-monitor")
    logger.setLevel(logging.INFO)
    handler = RotatingFileHandler(args.out / "probes.jsonl", maxBytes=10*1024*1024,
                                  backupCount=9, encoding="utf-8")
    logger.addHandler(handler)
    host = socket.gethostname()
    def emit(**row):
        logger.info(json.dumps(dict(host=host, **row), separators=(",", ":")))

    specs = []
    local_targets = [] if args.direct else [("router", args.router),
                     ("kirby", "192.168.5.50"), ("lakitu", "192.168.10.10")]
    for name, address in local_targets + [("att-rg", args.rg),
                          ("cloudflare", "1.1.1.1"), ("quad9", "9.9.9.9")]:
        specs.append(("icmp-" + name, "icmp", [tools["ping"], "-n", "-c", "1", "-W", "2", address]))
    local_dns = [] if args.direct else ["192.168.5.50", "192.168.10.10"]
    for address in dict.fromkeys((args.dns or local_dns) + ["1.1.1.1", "9.9.9.9"]):
        specs.append(("dns-" + address, "dns", [tools["dig"], "@" + address, "example.com", "A",
                      "+time=2", "+tries=1", "+noall", "+comments", "+answer", "+stats"]))
    for name, domain, address, url in [
        ("cloudflare", "one.one.one.one", "1.1.1.1", "https://one.one.one.one/cdn-cgi/trace"),
        ("quad9", "dns.quad9.net", "9.9.9.9", "https://dns.quad9.net/dns-query?dns=AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE"),
    ]:
        specs.append(("https-" + name, "https", [tools["curl"], "-4", "--noproxy", "*",
                      "--connect-timeout", "2", "--max-time", "4", "--resolve", f"{domain}:443:{address}",
                      "-H", "Accept: application/dns-message", "-sS", "-o", "/dev/null",
                      "-w", "http=%{http_code} connect=%{time_connect} tls=%{time_appconnect} total=%{time_total}", url]))
    stop = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: stop.set())
    emit(event="start", time=timestamp(), interval=args.interval,
         probes=[dict(name=n, kind=k, command=c) for n, k, c in specs])
    print(f"Monitoring {len(specs)} probes every {args.interval}s; logs: {args.out.resolve()}", flush=True)

    def worker(name, kind, command):
        previous = None
        while not stop.is_set():
            tick = time.monotonic()
            row = probe(kind, command, timeout=5)
            emit(event="probe", name=name, kind=kind, **row)
            if row["status"] != previous:
                print(f"{row['finished']} {name}: {previous or 'START'} -> {row['status']}", flush=True)
            previous = row["status"]
            stop.wait(max(0, args.interval - (time.monotonic() - tick)))

    with concurrent.futures.ThreadPoolExecutor(max_workers=len(specs)) as pool:
        futures = [pool.submit(worker, *spec) for spec in specs]
        deadline = time.monotonic() + args.duration if args.duration else float("inf")
        try:
            while not stop.wait(min(1, max(0, deadline - time.monotonic()))):
                for future in futures:
                    if future.done():
                        future.result()  # Surface worker/logging errors to systemd.
                if time.monotonic() >= deadline:
                    break
        finally:
            stop.set()
        for future in futures:
            future.result()
    emit(event="stop", time=timestamp())


if __name__ == "__main__":
    main()
