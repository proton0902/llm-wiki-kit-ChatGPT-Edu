---
name: wiki-examples
description: 예시 자료(MIT OpenCourseWare 6.034 인공지능 강의자료 3개)를 원 출처에서 raw/lectures/로 내려받는다. "예시 자료 받아줘", "연습용 강의자료 넣어줘"라고 할 때 사용.
---

# 예시 자료 내려받기 (학습용)

사용자가 직접 요청했을 때만 인터넷에 접속한다. 받는 곳은 `examples/*.tsv`에 적힌 원 출처(MIT OpenCourseWare)뿐이다.

## 세트
| 세트 | 내용 | 양 |
| --- | --- | --- |
| `basic` | MIT 6.034 인공지능(2005) 강의자료 3개 (Ch.1, 4, 5), CC BY-NC-SA 4.0 | 약 10MB |

## 절차
1. 받을 파일 수, 대략 용량, 출처를 한 줄로 알리고 진행한다.
2. 위키 폴더에서 실행한다. Python 이름은 `python3`, `python`, `py` 중 되는 것을 쓴다.
   ```
   python3 scripts/get_examples.py basic
   ```
   네트워크 접근 승인을 요청받으면 사용자에게 무엇을 받는지 말하고 승인을 받는다.
3. Python이 없으면 `examples/basic.tsv`의 각 행(저장폴더, 파일명, 원본URL)을 읽어 같은 일을 한다. Windows는 `Invoke-WebRequest -UseBasicParsing <URL> -OutFile <경로>`, macOS·Linux는 `curl -fsSL -o <경로> <URL>`. 받은 파일의 저자·원본·라이선스를 `예시 자료 출처.md`에 덧붙인다.
4. 결과를 알리고 다음 단계를 안내한다: `$wiki-setup`에서 과목을 "MIT 6.034 인공지능"으로 등록 → `$wiki-ingest raw/lectures/MIT-6.034-인공지능` (한 장씩 권장) → `$wiki-quiz`.
5. `wiki/log.md`에 `- 날짜 | examples | basic | N개 받음` 추가.

## 지키는 것
- `examples/*.tsv`에 없는 주소에서는 받지 않는다.
- 받은 자료는 `raw/`에만 두고, 다시 배포할 때는 CC BY-NC-SA 4.0(출처 표시, 비영리, 같은 조건)을 따른다.
