#!/bin/zsh
# Mode Skill: Collaborative (협동)
# 역할분리 + 3개 작업컨텍스트 + 1개 공유보드, worktree 격리

# ── metadata ──
_mode_label="CO-OP (협동)"
_mode_icon="🤝"
_mode_color_name="green"
_mode_needs_order=false
_mode_input_routing="broadcast"  # send to all AIs

# ── context setup ──
_mode_setup_context() {
  local tmpdir="$1" cnt="$2"
  shift 2
  local -a tools=("$@")
  for ((j=1; j<=$cnt; j++)); do
    echo "# ${tools[$j]} Work Context" > "$tmpdir/context_${tools[$j]}.md"
    echo "" >> "$tmpdir/context_${tools[$j]}.md"
  done
  echo "# Shared Board (공유 보드)" > "$tmpdir/shared.md"
  echo "" >> "$tmpdir/shared.md"
  echo "각 AI가 현재 작업 내용을 여기에 기록합니다." >> "$tmpdir/shared.md"
  echo "" >> "$tmpdir/shared.md"
}

# ── available roles ──
_mode_available_roles=("Lead Dev" "Reviewer" "Test/Ops" "Core" "Tests" "Config" "Review" "Docs" "Frontend" "Backend" "DB" "Security" "Refactor" "API" "Perf" "A11y" "i18n" "Migration" "Debug" "Architect")
_mode_available_role_descs=(
  "아키텍처+핵심 로직 구현"
  "품질/보안/성능 통합 리뷰"
  "테스트+빌드/배포 통합"
  "핵심 구현/소스코드 개발"
  "테스트 작성 및 검증"
  "빌드/CI·CD/인프라 설정"
  "코드 리뷰 및 품질 검증"
  "문서화 (README, API docs)"
  "프론트엔드 UI/UX 개발"
  "백엔드 API/서버 개발"
  "데이터베이스 설계/마이그레이션"
  "보안 점검 및 취약점 분석"
  "코드 리팩토링 및 최적화"
  "API 설계/엔드포인트 정의"
  "성능 프로파일링/최적화"
  "접근성(a11y) 검증"
  "국제화/번역(i18n)"
  "데이터/스키마 마이그레이션"
  "버그 원인 분석/디버깅"
  "아키텍처 설계/구조 결정"
)
_mode_available_role_icons=("👑" "🔍" "🛠️" "⚙️" "🧪" "🔧" "👀" "📝" "🎨" "🖥️" "🗄️" "🔒" "♻️" "🔌" "⚡" "♿" "🌐" "📦" "🐛" "🏛️")

# default roles (overridden by interactive selection)
_mode_roles=("Lead Dev" "Reviewer" "Test/Ops")

_mode_role_prompt_for() {
  local role="$1" tmpdir="$2" prompt="$3"
  local board_msg="Check the shared board (${tmpdir}/shared.md) regularly to understand the project's direction and align your work with others. After each significant implementation or update, append a clear summary of your changes to the shared board."
  case "$role" in
    "Lead Dev") echo "You are the Lead Developer. Your goal is to design the overall architecture and implement the CORE logic of the project. Focus on modularity, readability, and clean code. ${board_msg} Task: ${prompt}" ;;
    "Reviewer") echo "You are the Quality & Security Reviewer. Your goal is to ensure high code quality, security, and performance. Analyze the existing codebase and other AIs' work to identify bugs, security vulnerabilities, and performance bottlenecks. Propose and implement refactoring and optimizations. ${board_msg} Task: ${prompt}" ;;
    "Test/Ops") echo "You are the Test & Ops Engineer. Your goal is to ensure 100% test coverage and a smooth deployment process. Write comprehensive unit/integration tests and handle build configurations, CI/CD pipelines, and documentation (README, API docs). ${board_msg} Task: ${prompt}" ;;
    Core)      echo "You are the core developer. Focus ONLY on main implementation/source code. Do NOT create or modify test files, config files, or documentation. ${board_msg} Task: ${prompt}" ;;
    Tests)     echo "You are the test engineer. Write tests and test utilities ONLY. Do NOT modify any implementation/source code. Only create/edit files in test directories or files with test/spec in their name. ${board_msg} Task: ${prompt}" ;;
    Config)    echo "You are the DevOps/config engineer. Handle ONLY build config, CI/CD, and infrastructure files. Do NOT modify implementation code or test files. ${board_msg} Task: ${prompt}" ;;
    Review)    echo "You are the code reviewer. Review the codebase for bugs, code quality issues, and improvements. Do NOT modify code directly - write review comments and suggestions to the shared board. ${board_msg} Task: ${prompt}" ;;
    Docs)      echo "You are the documentation writer. Write and update documentation ONLY (README, API docs, comments, guides). Do NOT modify implementation code or test files. ${board_msg} Task: ${prompt}" ;;
    Frontend)  echo "You are the frontend developer. Focus ONLY on frontend UI/UX code (HTML, CSS, JS, React, Vue, etc). Do NOT modify backend or infrastructure code. ${board_msg} Task: ${prompt}" ;;
    Backend)   echo "You are the backend developer. Focus ONLY on backend API/server code. Do NOT modify frontend UI code or infrastructure files. ${board_msg} Task: ${prompt}" ;;
    DB)        echo "You are the database engineer. Focus ONLY on database schema, migrations, queries, and data models. Do NOT modify application logic or UI code. ${board_msg} Task: ${prompt}" ;;
    Security)  echo "You are the security engineer. Analyze and fix security vulnerabilities ONLY. Focus on input validation, auth, XSS, SQL injection, and OWASP top 10. ${board_msg} Task: ${prompt}" ;;
    Refactor)  echo "You are the refactoring specialist. Improve code structure, reduce duplication, and optimize performance WITHOUT changing external behavior. ${board_msg} Task: ${prompt}" ;;
    API)       echo "You are the API designer. Focus ONLY on API endpoint design, request/response schemas, and API documentation (OpenAPI/Swagger). Do NOT implement business logic or UI code. ${board_msg} Task: ${prompt}" ;;
    Perf)      echo "You are the performance engineer. Profile and optimize performance bottlenecks. Write benchmarks, identify slow paths, and suggest/implement optimizations. Do NOT change functionality. ${board_msg} Task: ${prompt}" ;;
    A11y)      echo "You are the accessibility specialist. Audit and fix accessibility issues (WCAG compliance, ARIA attributes, keyboard navigation, screen reader support). Focus ONLY on a11y improvements. ${board_msg} Task: ${prompt}" ;;
    i18n)      echo "You are the internationalization engineer. Handle translations, locale support, date/number formatting, and i18n infrastructure. Do NOT modify core business logic. ${board_msg} Task: ${prompt}" ;;
    Migration) echo "You are the migration specialist. Focus ONLY on data migrations, schema migrations, and version upgrade scripts. Ensure backward compatibility and rollback safety. ${board_msg} Task: ${prompt}" ;;
    Debug)     echo "You are the debugger. Analyze bugs, trace root causes, add diagnostic logging, and fix issues. Focus on understanding WHY bugs occur before fixing them. Report findings to the shared board. ${board_msg} Task: ${prompt}" ;;
    Architect) echo "You are the software architect. Design system architecture, define component boundaries, and make structural decisions. Write architecture docs and diagrams (mermaid). Do NOT implement code directly - guide other developers via the shared board. ${board_msg} Task: ${prompt}" ;;
    *)         echo "You are a developer with role: ${role}. ${board_msg} Task: ${prompt}" ;;
  esac
}

_mode_setup_roles() {
  local tmpdir="$1" prompt="$2"
  _mode_role_prompts=()
  for ((ri=1; ri<=${#_mode_roles[@]}; ri++)); do
    _mode_role_prompts+=("$(_mode_role_prompt_for "${_mode_roles[$ri]}" "$tmpdir" "$prompt")")
  done
}

# ── wait logic (heredoc injected into run script) ──
_mode_gen_wait_logic() {
  cat << 'EOF'
# ── collaborative mode: all roles run simultaneously ──
printf '  \033[2m📋 협동 모드 - 내 컨텍스트: %s/context_%s.md\033[0m\n' "$tmpdir" "$toolname"
printf '  \033[2m   공유 보드: %s/shared.md (작업 내용 기록 + 확인)\033[0m\n' "$tmpdir"
EOF
}

# ── prompt injection ──
_mode_prompt_inject() {
  local tmpdir="$1"
  echo 'prompt="[내 작업 컨텍스트: '"$tmpdir"'/context_${toolname}.md | 공유 보드: '"$tmpdir"'/shared.md - 작업 내용을 기록하고 다른 AI 작업을 확인하세요] ${prompt}"'
}

# ── done logic additions ──
_mode_gen_done_logic() {
  cat << 'EOF'
# save final output to own context file
{
  echo ""
  echo "## Final Output (process exited)"
  echo "### Changes"
  echo '```'
  [ -n "$_diff_stat" ] && echo "$_diff_stat" || echo "(none)"
  echo '```'
} >> "$tmpdir/context_${toolname}.md"
EOF
}

# ── help panel commands ──
_mode_help_commands() {
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}${bld}/merge${rst}   브랜치 머지 ${cyn}★${rst}  ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/board${rst}    공유보드 확인    ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/swap N M${rst} 역할 교체       ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/role N X${rst} 역할 변경       ${prp}${bld}║${rst}\n"'
  echo 'printf "  ${prp}${bld}║${rst}  ${ylw}/roles${rst}    역할 확인        ${prp}${bld}║${rst}\n"'
}

# ── help panel info section ──
_mode_help_info() {
  local cnt="$1"
  shift
  local -a tools=("$@")
  shift $cnt
  local -a icons=("$@")
  shift $cnt
  local -a roles=("$@")
  echo 'printf "\n  ${grn}${bld}📋 역할 배정:${rst}\n"'
  for ((j=1; j<=$cnt; j++)); do
    echo "printf '   ${icons[$j]} ${tools[$j]}: ${roles[$j]:-Dev}\n'"
  done
}

# ── cmd center mode header ──
_mode_cmd_header() {
  printf '  ${prp}${bld}║${rst}  ${grn}${bld}🤝 CO-OP${rst} ${dm}협동 모드${rst}                ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}  ${dm}역할분리 + 공유보드 + worktree${rst}     ${prp}${bld}║${rst}\n'
}

# ── cmd center mode commands ──
_mode_cmd_commands() {
  printf '  ${prp}${bld}╠══════════════════════════════════════╣${rst}\n'
  printf '  ${prp}${bld}║${rst}  ${cyn}협동 모드:${rst}                          ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}${bld}/merge${rst}    브랜치 머지 ${cyn}★${rst}        ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/board${rst}     공유보드 확인          ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/swap N M${rst}  N↔M 역할 교체        ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/role N X${rst}  N번 AI 역할 변경     ${prp}${bld}║${rst}\n'
  printf '  ${prp}${bld}║${rst}   ${ylw}/roles${rst}     현재 역할 확인        ${prp}${bld}║${rst}\n'
}

# ── cmd center mode info ──
_mode_cmd_info() {
  printf "\n  ${grn}${bld}📋 역할 배정:${rst}\n"
  for ((r=1; r<=${#_cmd_tools[@]}; r++)); do
    printf "   ${_cmd_icons[$r]} ${_cmd_tools[$r]}: ${ylw}${_cmd_roles[$r]}${rst}\n"
  done
}

# ── banner extra info ──
_mode_banner_extra() {
  local j="$1"
  echo " (${_mode_roles[$j]:-Dev})"
}

# ── cmd center context view ──
_mode_do_ctx() {
  local tmpdir="$1" cnt="$2"
  shift 2
  local -a tools=("${(@)@[1,cnt]}")
  shift $cnt
  local -a icons=("${(@)@[1,cnt]}")

  printf "  ${grn}${bld}📋 공유 보드 (shared.md):${rst}\n"
  local sfile="$tmpdir/shared.md"
  if [ -f "$sfile" ] && [ -s "$sfile" ]; then
    tail -20 "$sfile" | while IFS= read -r sl; do
      printf "    ${dm}%s${rst}\n" "$sl"
    done
  else
    printf "    ${dm}(비어 있음)${rst}\n"
  fi
  printf "\n"
  for ((ci=1; ci<=cnt; ci++)); do
    local cname="${tools[$ci]}"
    local cicon="${icons[$ci]}"
    local cfile="$tmpdir/context_${cname}.md"
    printf "  ${cyn}${bld}${cicon} ${cname} 작업 컨텍스트:${rst}\n"
    if [ -f "$cfile" ] && [ -s "$cfile" ]; then
      local cl=$(wc -l < "$cfile" | tr -d ' ')
      tail -10 "$cfile" | while IFS= read -r line; do
        printf "    ${dm}%s${rst}\n" "$line"
      done
      [ "$cl" -gt 10 ] && printf "    ${dm}... (총 ${cl}줄)${rst}\n"
    else
      printf "    ${dm}(비어 있음)${rst}\n"
    fi
    printf "\n"
  done
}

# ── help command text ──
_mode_help_text() {
  printf "\n  ${cyn}${bld}협동 모드:${rst}\n"
  printf "  ${ylw}/merge${rst}  브랜치 머지  ${ylw}/board${rst}  공유보드 확인\n"
  printf "  ${ylw}/swap N M${rst} 역할교체  ${ylw}/role N X${rst} 역할변경  ${ylw}/roles${rst} 확인\n"
  printf "  ${dm}  역할분리 + 공유보드 + worktree 격리${rst}\n"
}
