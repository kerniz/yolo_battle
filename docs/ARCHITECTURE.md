# Architecture — yolo_battle

## Overview

`yolo_battle`은 여러 AI CLI(Claude, Gemini, Codex)를 tmux 기반으로 동시/순차/협동 실행하는 zsh 스크립트 프로젝트입니다.

## File Structure

```
yolo_battle/
├── yolo.zsh              # Entry point — yolo() 함수 정의, tool 선택 UI
├── battle.zsh            # Orchestrator — 배틀 모드 메인 흐름 (211줄)
├── lib/
│   ├── ui.zsh            # View — TUI 선택 UI (mode/agent/role/order/layout)
│   ├── scriptgen.zsh     # Controller — AI 실행 스크립트, help panel, cmd center, monitor 생성
│   ├── cmd_center.zsh    # View+Controller — Command Center 런타임 (입력/출력/명령 처리)
│   └── tmux.zsh          # Infrastructure — tmux 세션 생성, 옵션, 정리
├── modes/
│   ├── collaborative.zsh # Mode Skill — 협동 모드 (역할분리, worktree, 공유보드)
│   ├── parallel.zsh      # Mode Skill — 동시 모드 (독립 실행, /pick 채택)
│   └── sequential.zsh    # Mode Skill — 순차 모드 (릴레이, /next 순환)
├── install.sh            # Installer
├── Makefile              # lint/test
├── tests/                # bats 테스트
└── docs/                 # 문서
```

## Module Responsibilities

### battle.zsh — Orchestrator (211줄)
메인 `_yolo_battle()` 함수. 전체 흐름을 제어합니다:
1. 모드 선택 → 에이전트 선택 → workspace 준비
2. 모드 스킬 로드 → 역할/순서 선택
3. 스크립트 생성 → tmux 세션 생성 → 모니터 시작
4. tmux attach → 종료 후 정리 → 재시작 처리

### lib/ui.zsh — Interactive TUI (440줄)
사용자 입력을 받는 선택 UI 컴포넌트:
- `_battle_select_mode()` — 배틀 모드 선택 (순차/동시/협동)
- `_battle_select_agents()` — 참가 AI 선택 (토글)
- `_battle_select_roles()` — 역할 배정 (협동 모드)
- `_battle_select_order()` — 실행 순서 선택 (순차 모드)
- `_battle_select_layout()` — tmux 레이아웃 선택
- `_battle_show_banner()` — 시작 배너 출력

### lib/scriptgen.zsh — Script Generation (389줄)
tmux pane에서 실행될 스크립트 파일들을 생성:
- `_battle_gen_tool_scripts()` — AI별 실행 스크립트 (`run_*.sh`)
- `_battle_gen_help_panel()` — 가이드 패널 스크립트
- `_battle_gen_cmd_center()` — 커맨드 센터 부트스트랩 스크립트
- `_battle_gen_monitor()` — 상태바 모니터 스크립트

### lib/cmd_center.zsh — Command Center Runtime (1288줄)
커맨드 센터 pane에서 런타임으로 source되는 코드:
- 사용자 입력 루프 (슬래시 명령어 디스패치)
- 상태 표시, diff 확인, 저장, 컨텍스트 확인
- 순차 모드: `/next`, `/skip`, `/auto` 턴 관리
- 동시 모드: `/pick`, `/compare`, `/merge` 결과 관리
- 협동 모드: `/board`, `/swap`, `/role` 역할 관리
- 백그라운드 워처: auto-next, priority cascade, parallel completion

### lib/tmux.zsh — Tmux Management (128줄)
tmux 세션 생성과 환경 설정:
- `_battle_setup_tmux()` — 세션 생성, pane 분할, 레이아웃
- `_battle_setup_tmux_options()` — 마우스, 스타일, 키바인딩
- `_battle_cleanup_worktrees()` — worktree 정리

### modes/*.zsh — Mode Skills
각 모드의 동작을 정의하는 플러그인 인터페이스:
- `_mode_setup_context()` — 컨텍스트 파일 초기화
- `_mode_gen_wait_logic()` — AI 실행 전 대기 로직
- `_mode_gen_done_logic()` — AI 완료 후 처리 로직
- `_mode_help_commands()` — 가이드 패널 모드별 명령어
- `_mode_help_info()` — 가이드 패널 모드별 정보
- `_mode_cmd_header()` — 커맨드 센터 모드 헤더
- `_mode_do_ctx()` — 컨텍스트 확인 로직

## Data Flow

```
User → yolo.zsh → battle.zsh (orchestrator)
                      │
                      ├→ lib/ui.zsh (interactive selection)
                      ├→ modes/*.zsh (mode skill loaded)
                      ├→ lib/scriptgen.zsh (generate scripts → /tmp/)
                      ├→ lib/tmux.zsh (create session)
                      │
                      └→ tmux session
                           ├─ AI panes: run_*.sh (각 AI 독립 실행)
                           ├─ CMD pane: cmd_center.sh → sources lib/cmd_center.zsh
                           ├─ GUIDE pane: help_panel.sh (정적 도움말)
                           └─ monitor.sh (상태바 업데이트, 백그라운드)
```

## Key Design Decisions

1. **런타임 source vs 인라인 heredoc**: `cmd_center.zsh`는 생성된 `cmd_center.sh`에서 런타임에 source됩니다. 이전 방식(1288줄 heredoc 인라인)에서 변경.

2. **모드 스킬 플러그인**: `modes/*.zsh`는 일관된 인터페이스(`_mode_*` 함수들)를 제공하여 새 모드 추가가 용이합니다.

3. **/tmp/ 사용**: 모든 임시 파일은 `/tmp/yolo-battle-XXXXXX`에 생성. OS가 자동 정리하므로 별도 cleanup 불필요.

4. **프로세스 간 통신**: tmux pane들은 독립 프로세스이므로, tmpdir의 파일을 통해 상태를 공유합니다 (status files, context files, shared board).
