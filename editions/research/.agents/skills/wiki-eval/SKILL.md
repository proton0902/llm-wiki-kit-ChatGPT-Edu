---
name: wiki-eval
description: 위키 답변의 정확도를 정답 세트로 검증한다. "정확도 테스트", "평가 돌려줘", "벤치마크"라고 할 때 사용. eval/questions.csv의 질문에 위키로 답하고 eval/results.csv에 기록한다.
---

# 정확도 검증 (Eval)

정답은 사람이 원문을 보고 만든 `eval/questions.csv`에 있습니다. 이 스킬은 **답을 만들고 기록**까지만 합니다. 최종 채점은 사람이 확인합니다.

## 절차
1. `eval/README.md`를 읽고 `eval/questions.csv`를 연다. 정답(`answer`) 열은 **답을 다 쓸 때까지 보지 않는다.** 질문(`question`)과 `id`만 읽는다.
2. 질문마다 `$wiki-query` 절차대로 답한다. 단, 답을 저장하거나 위키를 고치지 않는다.
3. 각 답에 대해 기록한다: `id, condition(=C_wiki), run(1 또는 2), answer, cited_sources, said_unknown(yes/no), seconds(대략)`.
4. 모든 답을 `eval/results.csv`에 추가한 **뒤에** 정답을 열어 1차 채점한다:
   - `correct`: yes / partial / no
   - `source_ok`: 인용한 논문·쪽이 정답 출처와 맞으면 yes
   - `fabricated`: 원문에 없는 수치·사실을 지어냈으면 yes
   1차 채점 열에는 `grader=codex`를 적는다. 사람이 확인하면 `grader=human`으로 바꾼다.
5. `python3 eval/score.py` 를 실행해 요약 표를 보여 준다.
6. 틀린 문항은 원인을 분류해 보고한다: 위키 누락 / 위키 요약 오류 / 검색 실패(페이지를 못 찾음) / 원문 해석 오류. 이 분류가 `AGENTS.md` 개선의 근거가 된다.
