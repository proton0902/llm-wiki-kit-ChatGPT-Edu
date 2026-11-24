#!/usr/bin/env python3
"""PowerPoint(.pptx)를 슬라이드 번호가 붙은 텍스트로 출력한다. 추가 설치 없이 동작한다.
사용법: python3 scripts/pptx_slides.py 파일.pptx [--no-notes]

각 슬라이드는 '=== s.N ===' 으로 시작하고, 발표자 노트가 있으면 '[노트]' 아래에 붙는다.
그림 속 글자(이미지)는 읽지 못하므로, 그림이 많은 슬라이드는 PDF로 내보내 함께 넣는 것을 권한다.
"""
import re
import sys
import zipfile
from html import unescape

PARA = re.compile(r"<a:p[ >].*?</a:p>", re.S)
TEXT = re.compile(r"<a:t>(.*?)</a:t>", re.S)


def paragraphs(xml):
    out = []
    for p in PARA.findall(xml):
        line = "".join(unescape(t) for t in TEXT.findall(p)).strip()
        if line:
            out.append(line)
    return out


def number(name):
    m = re.search(r"(\d+)\.xml$", name)
    return int(m.group(1)) if m else 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    path, with_notes = sys.argv[1], "--no-notes" not in sys.argv
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        # 실제 발표 순서는 presentation.xml의 sldIdLst와 관계 파일을 따른다
        order = []
        try:
            pres = z.read("ppt/presentation.xml").decode("utf-8")
            rels = z.read("ppt/_rels/presentation.xml.rels").decode("utf-8")
            rid_to_target = dict(re.findall(r'Id="(rId\d+)"[^>]*Target="(slides/slide\d+\.xml)"', rels))
            rid_to_target.update({k: v for v, k in re.findall(r'Target="(slides/slide\d+\.xml)"[^>]*Id="(rId\d+)"', rels)})
            for rid in re.findall(r'<p:sldId [^>]*r:id="(rId\d+)"', pres):
                if rid in rid_to_target:
                    order.append("ppt/" + rid_to_target[rid])
        except KeyError:
            pass
        if not order:
            order = sorted((n for n in names if re.match(r"ppt/slides/slide\d+\.xml$", n)), key=number)
        for i, slide in enumerate(order, 1):
            print(f"=== s.{i} ===")
            for line in paragraphs(z.read(slide).decode("utf-8")):
                print(line)
            if with_notes:
                rel = slide.replace("slides/", "slides/_rels/") + ".rels"
                if rel in names:
                    m = re.search(r'Target="\.\./notesSlides/(notesSlide\d+\.xml)"', z.read(rel).decode("utf-8"))
                    if m and f"ppt/notesSlides/{m.group(1)}" in names:
                        notes = [l for l in paragraphs(z.read(f"ppt/notesSlides/{m.group(1)}").decode("utf-8"))
                                 if not l.isdigit()]
                        if notes:
                            print("[노트]")
                            print("\n".join(notes))
            print()


if __name__ == "__main__":
    main()
