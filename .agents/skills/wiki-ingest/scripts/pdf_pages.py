#!/usr/bin/env python3
"""PDF를 쪽 번호가 붙은 텍스트로 출력한다. 사용법: python3 pdf_pages.py 파일.pdf [시작쪽] [끝쪽]

pypdf가 있으면 사용하고, 없으면 pdftotext(poppler)를 쓴다. 둘 다 없으면 설치 방법을 알려 준다.
"""
import shutil
import subprocess
import sys


def with_pypdf(path, start, end):
    from pypdf import PdfReader  # noqa: import inside so fallback works
    reader = PdfReader(path)
    n = len(reader.pages)
    end = min(end or n, n)
    for i in range(start - 1, end):
        text = reader.pages[i].extract_text() or ""
        print(f"=== p.{i + 1} ===")
        print(text.strip())
        print()
    return True


def with_pdftotext(path, start, end):
    exe = shutil.which("pdftotext")
    if not exe:
        return False
    args = [exe, "-layout", "-f", str(start)]
    if end:
        args += ["-l", str(end)]
    out = subprocess.run(args + [path, "-"], capture_output=True, text=True, check=True).stdout
    for i, page in enumerate(out.split("\f")):
        if page.strip():
            print(f"=== p.{start + i} ===")
            print(page.strip())
            print()
    return True


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    path = sys.argv[1]
    start = int(sys.argv[2]) if len(sys.argv) > 2 else 1
    end = int(sys.argv[3]) if len(sys.argv) > 3 else None
    try:
        if with_pypdf(path, start, end):
            return
    except ImportError:
        pass
    if with_pdftotext(path, start, end):
        return
    print("PDF 텍스트 추출 도구가 없습니다. 다음 중 하나를 설치하세요:\n"
          "  pip install pypdf\n"
          "  (macOS) brew install poppler   (Windows) winget install poppler", file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
