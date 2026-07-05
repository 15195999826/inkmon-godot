# -*- coding: utf-8 -*-
"""Noto Sans SC 子集化 (adr/0011 决定 9): 字表 = translations.csv 全部用字
+ data/inkmon_content.json 全部字符串值用字 (lab 中文名落地后重跑本脚本即覆盖)
+ ASCII 可见区 + 常用 CJK 标点。

用法: python tools/build_font_subset.py <全量字体路径>
产物: inkmon/presentation/text/font/noto_sans_sc_subset.otf
"""
import json
import sys
from pathlib import Path

from fontTools import subset

REPO = Path(__file__).resolve().parent.parent
CSV_PATH = REPO / "inkmon" / "presentation" / "text" / "translations.csv"
CONTENT_PATH = REPO / "data" / "inkmon_content.json"
OUT_PATH = REPO / "inkmon" / "presentation" / "text" / "font" / "noto_sans_sc_subset.otf"

ASCII_VISIBLE = "".join(chr(c) for c in range(0x20, 0x7F))
CJK_PUNCT = "，。；：？！（）《》【】、“”‘’·—…±×→↵★•◎●✗▶◀"


def collect_json_strings(node, sink):
    if isinstance(node, str):
        sink.append(node)
    elif isinstance(node, dict):
        for value in node.values():
            collect_json_strings(value, sink)
    elif isinstance(node, list):
        for value in node:
            collect_json_strings(value, sink)


def main():
    if len(sys.argv) != 2:
        sys.exit("usage: python tools/build_font_subset.py <source-font.otf>")
    source_font = Path(sys.argv[1])
    if not source_font.exists():
        sys.exit(f"source font not found: {source_font}")

    chars = set(ASCII_VISIBLE) | set(CJK_PUNCT)
    chars |= set(CSV_PATH.read_text(encoding="utf-8"))
    if CONTENT_PATH.exists():
        strings = []
        collect_json_strings(json.loads(CONTENT_PATH.read_text(encoding="utf-8")), strings)
        chars |= set("".join(strings))
    chars = {c for c in chars if not c.isspace() or c == " "}

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    text_file = OUT_PATH.parent / "_subset_chars.txt"
    text_file.write_text("".join(sorted(chars)), encoding="utf-8")

    subset.main([
        str(source_font),
        f"--text-file={text_file}",
        f"--output-file={OUT_PATH}",
        "--layout-features=*",
        "--name-IDs=1,2",
    ])
    text_file.unlink()
    size_kb = OUT_PATH.stat().st_size / 1024
    print(f"OK: {OUT_PATH} ({size_kb:.0f} KB, {len(chars)} chars)")


if __name__ == "__main__":
    main()
