#!/usr/bin/env python
"""Slice a dota2-rts-pathfinding-lab export log for bug-fix analysis.

Reads the JSON written by export_debug_log() in
examples/dota2-rts-pathfinding-lab/frontend/dota2_pathfinding_lab.gd
(the path printed as `DOTA2_RTS_LAB_EXPORT_LOG: <path>`). Schema:
"dota2_rts_pathfinding_lab_debug_log_v1". The schema id and the main
top-level keys are pinned by the addon-side smoke
smoke_dota2_lab_ui_ops.gd::_assert_export_shape; finer fields are not --
if a section prints all None after an export-side change, re-check
_build_export_snapshot() before trusting the slice.

Default usage:
    python probe_log.py <log.json>

Filter to a unit / event kind / tick range:
    python probe_log.py <log.json> --unit fast_0
    python probe_log.py <log.json> --kind order_failed
    python probe_log.py <log.json> --tick-range 200:600

Output:
    - meta (scene / tick / mode / last action)
    - units table (state, stall, repath, last order), hard failures flagged
    - order events from world.recent_motion_updates: (kind, reason) counts + tail
    - slow frames (step spikes) summary
    - UI event stream (recent_events): kind counts + tail
    - metrics summary (orders, state counts, separation / planning stats)

--unit applies to the order-events tail; --kind applies to both the
order-events tail and the UI-events tail; --tick-range applies to order
events, slow frames, and UI events.
"""
import argparse
import collections
import json
import sys

# The export JSON carries Chinese UI strings (last_action / mode). On Windows
# a piped stdout defaults to the locale codepage (cp936), which the calling
# agent then mis-decodes as UTF-8 mojibake — force UTF-8 on both streams.
for _stream in (sys.stdout, sys.stderr):
    _reconfigure = getattr(_stream, "reconfigure", None)
    if _reconfigure is not None:
        _reconfigure(encoding="utf-8", errors="replace")

EXPECTED_SCHEMA = "dota2_rts_pathfinding_lab_debug_log_v1"


def vec(value):
    if isinstance(value, dict) and "x" in value and "y" in value:
        return "(%.1f,%.1f)" % (value["x"], value["y"])
    return str(value)


def in_range(tick, lo, hi):
    return lo is None or lo <= tick <= hi


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--unit", help="filter order-events tail to one unit id")
    ap.add_argument("--kind", help="filter event tails to one kind (order_completed / order_failed / UI kinds like move, select)")
    ap.add_argument("--tick-range", help="START:END inclusive; applies to order events, slow frames, UI events")
    ap.add_argument("--tail", type=int, default=30, help="entries per tail section (default 30)")
    args = ap.parse_args()

    with open(args.log, encoding="utf-8") as fp:
        d = json.load(fp)

    schema = d.get("schema")
    if schema != EXPECTED_SCHEMA:
        sys.exit(
            "schema mismatch: got %r, want %r - this slicer only understands "
            "dota2-rts-pathfinding-lab export logs" % (schema, EXPECTED_SCHEMA)
        )

    tick_lo = tick_hi = None
    if args.tick_range:
        try:
            lo_s, hi_s = args.tick_range.split(":", 1)
            tick_lo, tick_hi = int(lo_s), int(hi_s)
        except ValueError:
            sys.exit("--tick-range must be START:END, got %r" % args.tick_range)

    # `or {}` / `or []` (not .get defaults): a hand-edited or truncated log can
    # carry explicit nulls, which .get defaults do not paper over.
    world = d.get("world") or {}
    metrics = world.get("metrics") or {}

    print("=== meta ===")
    print("scene %s" % d.get("scene"))
    print("exported_at %s  tick %s  mode %s  paused %s" % (
        d.get("exported_at"), world.get("tick_count"), d.get("mode"), d.get("paused")))
    print("last_action %s  current_target %s" % (d.get("last_action"), vec(d.get("current_target"))))
    print()

    units = d.get("units") or []
    print("=== units (%d) ===" % len(units))
    hard_failures = []
    for u in units:
        last = u.get("last_order") or {}
        last_text = "%s:%s" % (last.get("status", "-"), last.get("reason", "-")) if last else "-"
        flags = []
        if u.get("flying"):
            flags.append("flying")
        if not u.get("mobile", True):
            flags.append("immobile")
        if last.get("status") == "failed" and last.get("reason") != "cancelled":
            flags.append("FAILED_HARD")
            hard_failures.append(str(u.get("id")))
        print("  %-12s %-7s pos=%s stall=%.2fs repath=%s path=%s last=%s%s" % (
            u.get("id"), u.get("state"), vec(u.get("position")),
            float(u.get("stall_seconds") or 0.0), u.get("repath_count", 0),
            u.get("path_size", 0), last_text,
            "  [%s]" % ",".join(flags) if flags else ""))
    if hard_failures:
        print("  -> hard failures (failed & not cancelled): %s" % ", ".join(hard_failures))
    print()

    events = world.get("recent_motion_updates") or []
    print("=== order events (world.recent_motion_updates, %d kept) ===" % len(events))
    counts = collections.Counter((e.get("kind"), e.get("reason")) for e in events)
    for (kind, reason), n in counts.most_common():
        print("  %4d %s:%s" % (n, kind, reason))
    if not counts:
        print("  (none)")
    filtered = [
        e for e in events
        if (not args.unit or e.get("unit_id") == args.unit)
        and (not args.kind or e.get("kind") == args.kind)
        and in_range(int(e.get("tick") or 0), tick_lo, tick_hi)
    ]
    print("  --- filtered tail (%d matches, showing last %d) ---" % (len(filtered), args.tail))
    for e in filtered[-args.tail:]:
        print("  tick %s %-12s %s reason=%s order=%s target=%s" % (
            e.get("tick"), e.get("unit_id"), e.get("kind"),
            e.get("reason"), e.get("order_id"), vec(e.get("target"))))
    if not filtered:
        print("  (none)")
    print()

    slow = [s for s in (d.get("slow_frames") or []) if in_range(int(s.get("tick") or 0), tick_lo, tick_hi)]
    print("=== slow frames (%d in range) ===" % len(slow))
    if slow:
        worst = max(slow, key=lambda s: s.get("step_usec") or 0)
        print("  worst %sus @ tick %s (last_action %r)" % (
            worst.get("step_usec"), worst.get("tick"), worst.get("last_action")))
        for s in slow[-8:]:
            print("  tick %s %sus last_action=%r" % (s.get("tick"), s.get("step_usec"), s.get("last_action")))
    else:
        print("  (none)")
    print()

    ui_events = d.get("recent_events") or []
    print("=== ui events (recent_events, %d kept) ===" % len(ui_events))
    ui_counts = collections.Counter(e.get("kind") for e in ui_events)
    for kind, n in ui_counts.most_common():
        print("  %4d %s" % (n, kind))
    if not ui_counts:
        print("  (none)")
    ui_filtered = [
        e for e in ui_events
        if (not args.kind or e.get("kind") == args.kind)
        and in_range(int(e.get("tick") or 0), tick_lo, tick_hi)
    ]
    print("  --- filtered tail (%d matches, showing last %d) ---" % (len(ui_filtered), args.tail))
    for e in ui_filtered[-args.tail:]:
        print("  tick %s %-16s last_action=%r" % (e.get("tick"), e.get("kind"), e.get("last_action")))
    if not ui_filtered:
        print("  (none)")
    print()

    stats = metrics.get("last_step_stats") or {}
    pf = d.get("pathfinder") or {}
    perf = d.get("perf") or {}
    print("=== metrics ===")
    print("  orders completed %s  failed %s" % (metrics.get("orders_completed"), metrics.get("orders_failed")))
    print("  state_counts %s" % metrics.get("state_counts"))
    print("  last_step_stats: max_residual_overlap=%s separation_rounds=%s plans_applied=%s plans_waiting=%s" % (
        stats.get("max_residual_overlap"), stats.get("separation_rounds"),
        stats.get("plans_applied"), stats.get("plans_waiting")))
    print("  pathfinder: plan_count=%s line_check_count=%s last_plan_usec=%s" % (
        pf.get("plan_count"), pf.get("line_check_count"), pf.get("last_plan_usec")))
    print("  perf: last=%sus avg=%.0fus max=%sus @ tick %s (measured %s)" % (
        perf.get("last_step_usec"), float(perf.get("avg_step_usec") or 0.0),
        perf.get("max_step_usec"), perf.get("max_step_tick"), perf.get("measured_step_count")))


if __name__ == "__main__":
    main()
