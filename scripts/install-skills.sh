#!/usr/bin/env bash
#
# Tines Agent Skills installer
# Installs skills for Claude Code, Cursor, Codex, Windsurf, and other AI agents.
#
# Usage:
#   ./scripts/install-skills.sh add -a <agent>           Install all skills
#   ./scripts/install-skills.sh add -a <agent> -s 'pat*'  Install matching skills
#   ./scripts/install-skills.sh add -a <agent> --force    Overwrite existing
#   ./scripts/install-skills.sh list                      List available skills
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

# Agent install directories
declare -A AGENT_DIRS 2>/dev/null || true
get_agent_dir() {
  case "$1" in
    claude-code)     echo ".claude/skills" ;;
    cursor)          echo ".agents/skills" ;;
    codex)           echo ".agents/skills" ;;
    opencode)        echo ".agents/skills" ;;
    windsurf)        echo ".windsurf/skills" ;;
    roo)             echo ".roo/skills" ;;
    cline)           echo ".agents/skills" ;;
    github-copilot)  echo ".agents/skills" ;;
    gemini-cli)      echo ".agents/skills" ;;
    pi)              echo ".pi/agent/skills" ;;
    *)
      echo ""
      return 1
      ;;
  esac
}

SUPPORTED_AGENTS="claude-code, cursor, codex, opencode, windsurf, roo, cline, github-copilot, gemini-cli, pi"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Discover skills by finding SKILL.md files
discover_skills() {
  local skills=()
  while IFS= read -r -d '' skill_file; do
    local skill_dir
    skill_dir="$(dirname "$skill_file")"
    local skill_name
    skill_name="$(basename "$skill_dir")"

    # Validate name is kebab-case
    if [[ "$skill_name" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
      skills+=("$skill_name")
    fi
  done < <(find "$SKILLS_DIR" -name "SKILL.md" -mindepth 3 -maxdepth 3 -print0 2>/dev/null)

  printf '%s\n' "${skills[@]}" | sort
}

# Get skill description from SKILL.md frontmatter
get_skill_description() {
  local skill_name="$1"
  local skill_file
  skill_file="$(find "$SKILLS_DIR" -path "*/$skill_name/SKILL.md" -print -quit 2>/dev/null)"

  if [[ -n "$skill_file" ]]; then
    awk '/^---$/{n++; next} n==1 && /^description:/{sub(/^description: */, ""); print; exit}' "$skill_file"
  fi
}

# Get skill source directory
get_skill_source() {
  local skill_name="$1"
  local skill_file
  skill_file="$(find "$SKILLS_DIR" -path "*/$skill_name/SKILL.md" -print -quit 2>/dev/null)"

  if [[ -n "$skill_file" ]]; then
    dirname "$skill_file"
  fi
}

# List available skills
cmd_list() {
  echo -e "${BLUE}Available Tines Agent Skills:${NC}"
  echo ""
  printf "  %-25s %s\n" "SKILL" "DESCRIPTION"
  printf "  %-25s %s\n" "-----" "-----------"

  while IFS= read -r skill; do
    local desc
    desc="$(get_skill_description "$skill")"
    # Truncate description for display
    if [[ ${#desc} -gt 80 ]]; then
      desc="${desc:0:77}..."
    fi
    printf "  %-25s %s\n" "$skill" "$desc"
  done < <(discover_skills)

  echo ""
  local total
  total=$(discover_skills | wc -l | tr -d ' ')
  echo -e "  ${GREEN}${total} skills available${NC}"
}

# Install skills
cmd_add() {
  local agent=""
  local pattern="*"
  local force=false
  local target_dir=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a|--agent)
        agent="$2"
        shift 2
        ;;
      -s|--skill)
        pattern="$2"
        shift 2
        ;;
      -d|--dir)
        target_dir="$2"
        shift 2
        ;;
      --force)
        force=true
        shift
        ;;
      *)
        echo -e "${RED}Unknown option: $1${NC}" >&2
        exit 1
        ;;
    esac
  done

  # Require agent or custom directory
  if [[ -z "$agent" && -z "$target_dir" ]]; then
    echo -e "${RED}Error: specify an agent with -a or a directory with -d${NC}"
    echo ""
    echo "Supported agents: $SUPPORTED_AGENTS"
    echo ""
    echo "Examples:"
    echo "  $0 add -a claude-code"
    echo "  $0 add -a cursor -s 'tines-cases'"
    echo "  $0 add -d /path/to/project/.claude/skills"
    exit 1
  fi

  # Resolve target directory
  if [[ -z "$target_dir" ]]; then
    target_dir="$(get_agent_dir "$agent")" || {
      echo -e "${RED}Unknown agent: $agent${NC}"
      echo "Supported agents: $SUPPORTED_AGENTS"
      exit 1
    }
  fi

  # Make target_dir relative to PWD (current project)
  local install_root="$PWD/$target_dir"

  echo -e "${BLUE}Installing Tines skills for ${agent:-custom}${NC}"
  echo -e "  Target: ${install_root}"
  echo ""

  local installed=0
  local skipped=0

  while IFS= read -r skill; do
    # Apply pattern filter
    # shellcheck disable=SC2254
    case "$skill" in
      $pattern) ;;
      *) continue ;;
    esac

    local source_dir
    source_dir="$(get_skill_source "$skill")"
    local dest_dir="$install_root/$skill"

    # Check if already exists
    if [[ -d "$dest_dir" && "$force" != true ]]; then
      echo -e "  ${YELLOW}SKIP${NC} $skill (already exists, use --force to overwrite)"
      ((skipped++))
      continue
    fi

    # Install
    mkdir -p "$dest_dir"
    cp -r "$source_dir"/* "$dest_dir"/
    echo -e "  ${GREEN}OK${NC}   $skill"
    ((installed++))
  done < <(discover_skills)

  echo ""
  echo -e "${GREEN}Done!${NC} Installed: $installed, Skipped: $skipped"

  if [[ $installed -gt 0 ]]; then
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Set environment variables:"
    echo "     export TINES_TENANT_URL=\"https://your-tenant.tines.com\""
    echo "     export TINES_API_TOKEN=\"your-api-token\""
    echo "  2. Test the connection by asking your agent: \"Check my Tines connection\""
  fi
}

# Main
case "${1:-help}" in
  add)
    shift
    cmd_add "$@"
    ;;
  list)
    cmd_list
    ;;
  help|--help|-h)
    echo "Tines Agent Skills Installer"
    echo ""
    echo "Usage:"
    echo "  $0 add -a <agent>                Install all skills for an agent"
    echo "  $0 add -a <agent> -s '<pattern>' Install matching skills"
    echo "  $0 add -a <agent> --force        Overwrite existing skills"
    echo "  $0 add -d <directory>            Install to a custom directory"
    echo "  $0 list                          List available skills"
    echo ""
    echo "Supported agents:"
    echo "  $SUPPORTED_AGENTS"
    echo ""
    echo "Examples:"
    echo "  $0 add -a claude-code            Install all skills for Claude Code"
    echo "  $0 add -a cursor -s 'tines-cases' Install only the cases skill for Cursor"
    echo "  $0 list                          Show available skills"
    ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}" >&2
    echo "Run '$0 help' for usage."
    exit 1
    ;;
esac
