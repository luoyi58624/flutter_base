"""只读分析 VM Timeline 快照，区分布局中的构建，避免嵌套时段重复相加。"""

import argparse
import bisect
import collections
import json
from pathlib import Path


def union(intervals):
    result = []
    for start, end in sorted(intervals):
        if result and start <= result[-1][1]:
            result[-1][1] = max(end, result[-1][1])
        else:
            result.append([start, end])
    return result


def duration(intervals):
    return sum(end - start for start, end in union(intervals))


def intersection(a, b):
    return duration((max(x, u), min(y, v)) for x, y in union(a) for u, v in union(b) if max(x, u) < min(y, v))


def summary(values):
    values = sorted(values)
    if not values:
        return {"count": 0}
    return {
        "count": len(values),
        "p50_us": values[(len(values) - 1) // 2],
        "p90_us": values[min(len(values) - 1, int(len(values) * .9))],
        "p99_us": values[min(len(values) - 1, int(len(values) * .99))],
        "max_us": values[-1],
        "mean_us": sum(values) / len(values),
        "over_8333us": sum(value > 8333 for value in values),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("timeline", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    data = json.loads(args.timeline.read_text(encoding="utf-8"))["result"]
    events = sorted(data["traceEvents"], key=lambda item: item.get("ts", 0))
    stacks = collections.defaultdict(list)
    asynchronous = {}
    spans, frames = [], []
    unmatched = 0
    for event in events:
        phase, name = event.get("ph"), event.get("name", "")
        thread = (event.get("pid"), event.get("tid"))
        if phase == "B":
            stacks[thread].append(event)
        elif phase == "E":
            if not stacks[thread] or stacks[thread][-1]["name"] != name:
                unmatched += 1
                continue
            start = stacks[thread].pop()
            spans.append((name, start["ts"], event["ts"], event["tid"]))
        elif phase == "X":
            spans.append((name, event["ts"], event["ts"] + event["dur"], event["tid"]))
        elif name == "Frame" and phase == "b":
            asynchronous[(thread, event.get("id"))] = event
        elif name == "Frame" and phase == "e":
            start = asynchronous.pop((thread, event.get("id")), None)
            if start:
                frames.append((start["ts"], event["ts"], event["tid"]))

    records = []
    spans_by_tid = collections.defaultdict(list)
    for span in sorted(spans, key=lambda item: item[1]):
        spans_by_tid[span[3]].append(span)
    starts_by_tid = {tid: [span[1] for span in rows] for tid, rows in spans_by_tid.items()}
    for start, end, tid in sorted(frames):
        all_spans, starts = spans_by_tid[tid], starts_by_tid[tid]
        inside = all_spans[bisect.bisect_left(starts, start):bisect.bisect_right(starts, end)]
        inside = [span for span in inside if span[2] <= end]
        stages = collections.defaultdict(list)
        for name, begin, finish, _ in inside:
            stages[name].append((begin, finish))
        layout, build, paint = stages["LAYOUT"], stages["BUILD"], stages["PAINT"]
        bits = stages["UPDATING COMPOSITING BITS"]
        composite = stages["COMPOSITING"]
        finalize = stages["FINALIZE TREE"]
        post_frame = stages["POST_FRAME"]
        known = layout + build + paint + bits + composite + stages["SEMANTICS"] + finalize + post_frame
        garbage_collection = stages["CollectNewGeneration"] + stages["CollectOldGeneration"]
        records.append({
            "start_us": start, "end_us": end, "tid": tid, "frame_us": end - start,
            "build_us": duration(build), "layout_inclusive_us": duration(layout),
            "layout_without_build_us": duration(layout) - intersection(layout, build),
            "paint_us": duration(paint), "compositing_bits_us": duration(bits),
            "composite_us": duration(composite), "finalize_us": duration(finalize), "post_frame_us": duration(post_frame),
            "semantics_us": duration(stages["SEMANTICS"]),
            "semantics_update_children_us": duration(stages["Semantics.updateChildren"]),
            "semantics_geometry_us": duration(stages["Semantics.ensureGeometry"]),
            "semantics_nodes_us": duration(stages["Semantics.ensureSemanticsNode"]),
            "gc_overlap_us": duration(garbage_collection),
            "outside_named_stages_us": end - start - duration(known),
            "build_scopes": len(build),
        })
    keys = [key for key in records[0] if key.endswith("_us") and key not in ("start_us", "end_us")]
    report = {
        "scope": "existing Profile VM ring-buffer snapshot; Frame async duration, not presentation timing",
        "timeline_origin_us": data["timeOriginMicros"], "timeline_extent_us": data["timeExtentMicros"],
        "unmatched_sync_ends": unmatched,
        "unclosed_sync_starts": sum(len(stack) for stack in stacks.values()),
        "complete_frames": len(records),
        "summaries": {key: summary(row[key] for row in records) for key in keys},
        "slow_frame_summaries": {key: summary(row[key] for row in records if row["frame_us"] > 8333) for key in keys},
        "top_slow_frames": sorted(records, key=lambda row: row["frame_us"], reverse=True)[:15],
        "span_names": collections.Counter(span[0] for span in spans),
        "frames": records,
    }
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({key: value for key, value in report.items() if key != "frames"}, ensure_ascii=False))


if __name__ == "__main__":
    main()
