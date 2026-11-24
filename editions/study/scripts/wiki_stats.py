#!/usr/bin/env python3
"""위키 통계와 기계적 점검 결과를 출력한다. 위키 폴더 최상위에서 실행: python3 scripts/wiki_stats.py [--json]

- 페이지 수(종류별), 내부 링크 수, 페이지당 평균 링크
- 깨진 링크, 고아 페이지(들어오는 링크 없음)
- 위치 출처(p.쪽 / s.슬라이드) 표기가 없는 논문·강의·교재 페이지, source 파일이 없는 페이지
- 아직 어떤 논문 페이지에도 연결되지 않은 raw 파일
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WIKI = ROOT / "wiki"
RAW = ROOT / "raw"
LINK = re.compile(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]")
PAGE_REF = re.compile(r"(?:p\.|s\.|slide\s?)\s?\d+", re.I)  # 쪽(p.) 또는 슬라이드(s.) 번호
CITED_TYPES = {"paper", "lecture", "chapter"}  # 위치 출처가 꼭 있어야 하는 페이지 종류
SOURCE = re.compile(r"^source:\s*(.+)$", re.M)
TYPE = re.compile(r"^type:\s*([\w-]+)", re.M)
IGNORE = re.compile(r"<!--.*?-->|```.*?```|`[^`\n]*`", re.S)  # 주석·코드 안의 예시 링크는 세지 않음


def main():
    pages = {p.relative_to(WIKI).with_suffix("").as_posix(): p for p in WIKI.rglob("*.md")}
    names = set(pages)
    # Obsidian은 파일명만으로도 링크를 찾으므로 basename도 허용
    by_base = {}
    for n in names:
        by_base.setdefault(n.split("/")[-1], []).append(n)

    types, links, broken, incoming = {}, 0, [], {n: 0 for n in names}
    no_cite, missing_src, used_src = [], [], set()
    for name, path in pages.items():
        text = path.read_text(encoding="utf-8", errors="replace")
        t = TYPE.search(text)
        kind = t.group(1) if t else "other"
        types[kind] = types.get(kind, 0) + 1
        for target in LINK.findall(IGNORE.sub("", text)):
            target = target.strip().removesuffix(".md")
            links += 1
            if target in names:
                incoming[target] += 1
            elif target in by_base:
                for n in by_base[target]:
                    incoming[n] += 1
            else:
                broken.append((name, target))
        if kind in CITED_TYPES:
            if not PAGE_REF.search(text):
                no_cite.append(name)
            m = SOURCE.search(text)
            if m:
                src = m.group(1).strip().strip('"')
                used_src.add(src)
                if not (ROOT / src).exists():
                    missing_src.append((name, src))
            else:
                missing_src.append((name, "(source 없음)"))

    skip = {"index", "log"}
    orphans = sorted(n for n, c in incoming.items() if c == 0 and n not in skip)
    raw_files = sorted(p.relative_to(ROOT).as_posix() for p in RAW.rglob("*")
                       if p.is_file() and p.name != ".gitkeep")
    not_ingested = [f for f in raw_files if f not in used_src]

    report = {
        "pages": len(pages), "pages_by_type": types, "internal_links": links,
        "avg_links_per_page": round(links / len(pages), 1) if pages else 0,
        "raw_files": len(raw_files), "not_ingested": not_ingested,
        "broken_links": broken, "orphans": orphans,
        "papers_without_page_citations": no_cite, "missing_sources": missing_src,
    }
    if "--json" in sys.argv:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return
    print(f"페이지 {report['pages']}개 {types} | 내부 링크 {links}개 | 페이지당 평균 {report['avg_links_per_page']}개")
    print(f"raw 파일 {len(raw_files)}개, 미소화 {len(not_ingested)}개")
    for title, items in [("깨진 링크", [f"{a} → [[{b}]]" for a, b in broken]),
                         ("고아 페이지", orphans),
                         ("위치 출처(p./s.) 없는 논문·강의·교재 페이지", no_cite),
                         ("원문 파일 없음", [f"{a}: {b}" for a, b in missing_src]),
                         ("미소화 raw 파일", not_ingested)]:
        print(f"\n[{title}] {len(items)}건")
        for i in items[:50]:
            print(f"  - {i}")


if __name__ == "__main__":
    main()
