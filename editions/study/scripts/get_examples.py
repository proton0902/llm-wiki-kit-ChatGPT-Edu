#!/usr/bin/env python3
"""예시 자료를 원 출처에서 이 위키의 raw/ 폴더로 내려받는다.

사용법 (위키 폴더에서):
    python3 scripts/get_examples.py            # 받을 수 있는 세트 목록 보기
    python3 scripts/get_examples.py basic      # 기본 예시 받기
    python3 scripts/get_examples.py benchmark  # 벤치마크 세트 받기 (연구자용)

목록은 examples/<세트>.tsv 에 있다. 이미 있는 파일은 건너뛰고, 받은 파일의
저자·원본·라이선스는 '예시 자료 출처.md'에 덧붙인다. 표준 라이브러리만 쓴다.
"""
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EX = ROOT / "examples"
CREDITS = ROOT / "예시 자료 출처.md"
UA = "llm-wiki-kit-examples"


def read_set(name):
    path = EX / f"{name}.tsv"
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        f = line.split("\t")
        if len(f) >= 6:
            rows.append(dict(dir=f[0], file=f[1], url=f[2], title=f[3], credit=f[4], license=f[5]))
    return rows


def list_sets():
    sets = sorted(p.stem for p in EX.glob("*.tsv")) if EX.is_dir() else []
    if not sets:
        print("examples/ 폴더에 목록이 없습니다.")
        return
    print("받을 수 있는 예시 세트:")
    for s in sets:
        rows = read_set(s)
        have = sum((ROOT / r["dir"] / r["file"]).exists() for r in rows)
        print(f"  {s:10s} {len(rows)}개 (이미 받음 {have}개)  ->  python3 scripts/get_examples.py {s}")


def fetch(name):
    rows = read_set(name)
    if not CREDITS.exists():
        CREDITS.write_text("# 예시 자료 출처\n\n아래 원 출처에서 이 PC로 직접 내려받은 자료입니다. "
                           "개인 학습·연구 체험용으로만 쓰고, 다시 배포할 때는 각 라이선스를 따르세요.\n\n",
                           encoding="utf-8")
    credits = CREDITS.read_text(encoding="utf-8")
    got = skipped = failed = 0
    for i, r in enumerate(rows, 1):
        out = ROOT / r["dir"] / r["file"]
        tag = f"[{i}/{len(rows)}] {r['dir']}/{r['file']}"
        if out.exists() and out.stat().st_size > 10000:
            print(f"{tag}  이미 있음")
            skipped += 1
        else:
            out.parent.mkdir(parents=True, exist_ok=True)
            try:
                req = urllib.request.Request(r["url"], headers={"User-Agent": UA})
                with urllib.request.urlopen(req, timeout=120) as resp:
                    data = resp.read()
                if len(data) < 10000:
                    raise ValueError("받은 파일이 너무 작습니다")
                out.write_bytes(data)
                print(f"{tag}  OK ({len(data) // 1024} KB)")
                got += 1
            except Exception as e:  # noqa: BLE001
                print(f"{tag}  실패: {e}  ({r['url']})")
                failed += 1
                continue
            finally:
                if "arxiv.org" in r["url"]:
                    time.sleep(3)  # arXiv 요청 간격 지키기
        key = f"**{r['dir']}/{r['file']}**"
        if key not in credits:
            entry = (f"- {key}: {r['title']}\n  - 저자·출처: {r['credit']}\n"
                     f"  - 원본: {r['url']}\n  - 라이선스: {r['license']}\n")
            credits += entry
    CREDITS.write_text(credits, encoding="utf-8")
    print(f"\n완료: 새로 받음 {got}, 이미 있음 {skipped}, 실패 {failed}. 출처는 '{CREDITS.name}'에 적었습니다.")
    if failed:
        print("실패한 파일은 잠시 뒤 같은 명령을 다시 실행하면 이어서 받습니다.")
    return 1 if failed and not got and not skipped else 0


def main():
    if len(sys.argv) < 2:
        list_sets()
        return 0
    name = sys.argv[1]
    if not (EX / f"{name}.tsv").exists():
        print(f"'{name}' 세트가 없습니다.")
        list_sets()
        return 1
    return fetch(name)


if __name__ == "__main__":
    sys.exit(main())
