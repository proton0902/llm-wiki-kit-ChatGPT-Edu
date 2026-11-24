#!/usr/bin/env python3
"""eval/results.csv를 조건별로 채점 요약한다. 사용법: python3 eval/score.py"""
import csv
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent


def main():
    qs = {r["id"]: r for r in csv.DictReader(open(HERE / "questions.csv", encoding="utf-8"))}
    rows = list(csv.DictReader(open(HERE / "results.csv", encoding="utf-8")))
    if not rows:
        print("results.csv가 비어 있습니다. eval/README.md의 절차대로 먼저 답을 기록하세요.")
        return
    groups = defaultdict(list)
    for r in rows:
        groups[r["condition"]].append(r)

    def pct(a, b):
        return f"{a / b * 100:.0f}% ({a}/{b})" if b else "-"

    print("| 조건 | 정답률 | 부분정답 포함 | 출처 정확 | 지어낸 답 | 답 없는 질문에 '모른다' | 평균 시간(초) | 사람 검수 |")
    print("| --- | --- | --- | --- | --- | --- | --- | --- |")
    for cond, rs in sorted(groups.items()):
        n = len(rs)
        ok = sum(r["correct"] == "yes" for r in rs)
        part = sum(r["correct"] in ("yes", "partial") for r in rs)
        src = sum(r["source_ok"] == "yes" for r in rs)
        fab = sum(r["fabricated"] == "yes" for r in rs)
        un = [r for r in rs if qs.get(r["id"], {}).get("type") == "unanswerable"]
        un_ok = sum(r["said_unknown"] == "yes" for r in un)
        secs = [float(r["seconds"]) for r in rs if r["seconds"].strip()]
        human = sum(r["grader"] == "human" for r in rs)
        avg = f"{sum(secs) / len(secs):.0f}" if secs else "-"
        print(f"| {cond} | {pct(ok, n)} | {pct(part, n)} | {pct(src, n)} | {fab}건 | {pct(un_ok, len(un))} | {avg} | {human}/{n} |")

    # 같은 질문 2회 실행 일관성
    by_q = defaultdict(dict)
    for r in rows:
        by_q[(r["condition"], r["id"])][r["run"]] = r["correct"]
    for cond in sorted(groups):
        pairs = [v for (c, _), v in by_q.items() if c == cond and len(v) >= 2]
        if pairs:
            same = sum(len(set(v.values())) == 1 for v in pairs)
            print(f"\n{cond}: 2회 실행 결과 일치 {pct(same, len(pairs))}")


if __name__ == "__main__":
    main()
