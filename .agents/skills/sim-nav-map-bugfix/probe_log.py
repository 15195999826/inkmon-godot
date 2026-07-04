#!/usr/bin/env python
"""Slice a sim-nav-map example-lab export log for bug-fix analysis.

Written against 0ad-rts-pathfinding-lab's export schema (deleted 2026-07-03,
see .agents/skills/sim-nav-map-bugfix/SKILL.md status note). Field names below
(units/path_decisions/motion_updates/recent_pair_contacts) reflect that lab's
JSON shape and have not been verified against dota2-rts-pathfinding-lab's
DOTA2_RTS_LAB_EXPORT_LOG output — check before relying on this against a
dota2-lab log.

Default usage:
    python probe_log.py <log.json>

Filter to a unit / tick range:
    python probe_log.py <log.json> --unit blue_2 --tick-range 9700:9900
    python probe_log.py <log.json> --kind movement_line_blocked

Output:
    - units snapshot
    - kind counts in last 240 path_decisions
    - pair_contacts severe overlap count + tail
    - filtered path_decisions tail (with key fields)
    - motion_updates tail
"""
import argparse
import collections
import json
import sys


KEY_FIELDS = [
    "tick", "kind", "unit_id", "position", "path_target",
    "failed_movements", "short_path_size", "long_path_size",
    "reason", "request_reason", "failure_reason",
    "first_short_waypoint_farther_from_final_goal",
    "current_final_goal_distance", "first_short_waypoint_final_goal_distance",
    "path",
]


def short(p):
    bits = []
    for k in KEY_FIELDS:
        v = p.get(k)
        if v is None:
            continue
        if isinstance(v, dict) and "x" in v and "y" in v:
            bits.append(f"{k}=({v['x']:.1f},{v['y']:.1f})")
        else:
            bits.append(f"{k}={v}")
    line = p.get("line") or {}
    bu = line.get("blocking_unit") or {}
    if bu:
        bits.append(f"blocker={bu.get('id')}@({bu.get('position', {}).get('x'):.1f},{bu.get('position', {}).get('y'):.1f})")
    return " ".join(bits)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--unit", help="filter to one unit_id")
    ap.add_argument("--kind", help="filter to one kind")
    ap.add_argument("--tick-range", help="START:END inclusive")
    ap.add_argument("--tail", type=int, default=30, help="how many decisions to print (default 30)")
    args = ap.parse_args()

    with open(args.log) as fp:
        d = json.load(fp)

    print("=== meta ===")
    print(f"current_target {d.get('current_target')}  last_action {d.get('last_action')}")
    print()

    units = d.get("units", [])
    print("=== units ===")
    for u in units:
        print(f"  {u.get('id'):14s} pos={u.get('position')}  mv={u.get('has_move_order')}  fm={u.get('failed_movements')}")
    print()

    pd = d.get("recent_path_decisions", [])
    kinds = collections.Counter(p.get("kind") for p in pd)
    print("=== path_decisions kind counts (last 240) ===")
    for k, v in kinds.most_common():
        print(f"  {v:4d} {k}")
    print()

    contacts = d.get("recent_pair_contacts", [])
    severe = [c for c in contacts if c.get("final_distance", 99) < 14.0]
    if severe:
        print(f"=== severe overlaps (dist < 14): {len(severe)} of {len(contacts)} ===")
        for c in severe[-5:]:
            print(
                f"  tick {c.get('tick')} {c.get('unit_a')}<->{c.get('unit_b')} "
                f"dist={c.get('final_distance', 0):.2f} "
                f"a_mv={c.get('a_was_moving_this_tick')} b_mv={c.get('b_was_moving_this_tick')}"
            )
        print()

    tick_lo, tick_hi = None, None
    if args.tick_range:
        try:
            lo_s, hi_s = args.tick_range.split(":", 1)
            tick_lo, tick_hi = int(lo_s), int(hi_s)
        except ValueError:
            sys.exit(f"--tick-range must be START:END, got {args.tick_range!r}")

    filtered = []
    for p in pd:
        if args.unit and p.get("unit_id") != args.unit:
            continue
        if args.kind and p.get("kind") != args.kind:
            continue
        if tick_lo is not None:
            t = p.get("tick", 0)
            if t < tick_lo or t > tick_hi:
                continue
        filtered.append(p)

    print(f"=== path_decisions filtered tail ({len(filtered)} matches, showing last {args.tail}) ===")
    for p in filtered[-args.tail:]:
        print(short(p))
    print()

    mu = d.get("recent_motion_updates", [])
    print("=== motion_updates last 8 ===")
    for u in mu[-8:]:
        actor = u.get("actor_id")
        if args.unit and actor != args.unit:
            continue
        print(
            f"  tick {u.get('tick')} {actor:14s} type={u.get('type')} "
            f"pos={u.get('position')} reason={u.get('reason')!r}"
        )


if __name__ == "__main__":
    main()
