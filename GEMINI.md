# GEMINI.md — Gemini 에이전트 작업 규칙

## 핵심 규칙: 명시적 지시 없이 코드 탐색 금지

- **사용자가 명시적으로 코드 수정/분석을 지시하지 않은 경우, 코드를 읽거나 탐색하지 마세요**
- 파일을 열거나, grep/find/ls 등으로 코드베이스를 탐색하지 마세요
- 지시 없이 코드를 수정하거나 리팩토링하지 마세요
- 대화나 간단한 작업(끝말잇기 등)에는 코드 탐색 없이 바로 응답하세요

## Git 브랜치 규칙 (필수)

- **반드시 자신만의 브랜치에서 작업하세요** (예: `battle-coop-gemini`)
- **절대 다른 AI의 브랜치에 직접 push하지 마세요** (예: `battle-coop-claude` 금지)
- 작업 전: `git checkout -b battle-coop-gemini` 또는 자신의 브랜치로 전환
- 작업 후: `git push origin battle-coop-gemini` 으로 자신의 브랜치에만 push
- 다른 AI의 변경사항이 필요하면 `git merge` 또는 `git cherry-pick`으로 가져오세요
- **이 규칙을 어기면 다른 AI의 작업이 충돌로 유실됩니다**

## 작업 시 주의사항

- 지시받은 작업만 수행할 것. 관련 없는 리팩토링이나 설계 문서 생성 금지
- 코드 변경 시 기존 동작을 깨뜨리지 않도록 주의
- 불필요한 디렉토리나 파일을 프로젝트 루트에 생성하지 말 것
- tmpdir는 반드시 /tmp/ 사용 (`mktemp -d /tmp/yolo-battle-XXXXXX`)
