#!/bin/bash
# Hook: detect-gaps.sh
# Event: SessionStart
# Purpose: Detect missing documentation when code/prototypes exist
# Cross-platform: Windows Git Bash compatible (uses grep -E, not -P)

# Exit on error for debugging (but don't fail the session)
set +e

echo "=== Checking for Documentation Gaps ==="

# --- Check 0: Fresh project detection (suggests /start) ---
FRESH_PROJECT=true

# Check if engine is configured
if [ -f ".claude/docs/technical-preferences.md" ]; then
  ENGINE_LINE=$(grep -E "^\- \*\*Engine\*\*:" .claude/docs/technical-preferences.md 2>/dev/null)
  if [ -n "$ENGINE_LINE" ] && ! echo "$ENGINE_LINE" | grep -q "TO BE CONFIGURED" 2>/dev/null; then
    FRESH_PROJECT=false
  fi
fi

# Check if game concept exists
if [ -f "design/gdd/game-concept.md" ]; then
  FRESH_PROJECT=false
fi

# Check if source code exists
if [ -d "src" ]; then
  SRC_CHECK=$(find src -type f \( -name "*.gd" -o -name "*.cs" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" -o -name "*.rs" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) 2>/dev/null | head -1)
  if [ -n "$SRC_CHECK" ]; then
    FRESH_PROJECT=false
  fi
fi

if [ "$FRESH_PROJECT" = true ]; then
  echo ""
  echo "🚀 NEW PROJECT: No engine configured, no game concept, no source code."
  echo "   This looks like a fresh start! Run: /start"
  echo ""
  echo "💡 To get a comprehensive project analysis, run: /project-stage-detect"
  echo "==================================="
  exit 0
fi

# --- Check 1: Substantial codebase but sparse design docs ---
if [ -d "src" ]; then
  # Count source files (cross-platform, handles Windows paths)
  SRC_FILES=$(find src -type f \( -name "*.gd" -o -name "*.cs" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.hpp" -o -name "*.rs" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) 2>/dev/null | wc -l)
else
  SRC_FILES=0
fi

if [ -d "design/gdd" ]; then
  DESIGN_FILES=$(find design/gdd -type f -name "*.md" 2>/dev/null | wc -l)
else
  DESIGN_FILES=0
fi

# Normalize whitespace from wc output
SRC_FILES=$(echo "$SRC_FILES" | tr -d ' ')
DESIGN_FILES=$(echo "$DESIGN_FILES" | tr -d ' ')

if [ "$SRC_FILES" -gt 50 ] && [ "$DESIGN_FILES" -lt 5 ]; then
  echo "⚠️  GAP: Substantial codebase ($SRC_FILES source files) but sparse design docs ($DESIGN_FILES files)"
  echo "    Suggested action: /reverse-document design src/[system]"
  echo "    Or run: /project-stage-detect to get full analysis"
fi

# --- Check 2: Prototypes without documentation ---
if [ -d "prototypes" ]; then
  PROTOTYPE_DIRS=$(find prototypes -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  UNDOCUMENTED_PROTOS=()

  if [ -n "$PROTOTYPE_DIRS" ]; then
    while IFS= read -r proto_dir; do
      # Normalize path separators for Windows
      proto_dir=$(echo "$proto_dir" | sed 's|\\|/|g')

      # Check for README.md or CONCEPT.md
      if [ ! -f "${proto_dir}/README.md" ] && [ ! -f "${proto_dir}/CONCEPT.md" ]; then
        proto_name=$(basename "$proto_dir")
        UNDOCUMENTED_PROTOS+=("$proto_name")
      fi
    done <<< "$PROTOTYPE_DIRS"

    if [ ${#UNDOCUMENTED_PROTOS[@]} -gt 0 ]; then
      echo "⚠️  GAP: ${#UNDOCUMENTED_PROTOS[@]} undocumented prototype(s) found:"
      for proto in "${UNDOCUMENTED_PROTOS[@]}"; do
        echo "    - prototypes/$proto/ (no README or CONCEPT doc)"
      done
      echo "    Suggested action: /reverse-document concept prototypes/[name]"
    fi
  fi
fi

# --- Check 3: Core systems without architecture docs ---
if [ -d "src/core" ] || [ -d "src/engine" ]; then
  if [ ! -d "docs/architecture" ]; then
    echo "⚠️  GAP: Core engine/systems exist but no docs/architecture/ directory"
    echo "    Suggested action: Create docs/architecture/ and run /architecture-decision"
  else
    ADR_COUNT=$(find docs/architecture -type f -name "*.md" 2>/dev/null | wc -l)
    ADR_COUNT=$(echo "$ADR_COUNT" | tr -d ' ')

    if [ "$ADR_COUNT" -lt 3 ]; then
      echo "⚠️  GAP: Core systems exist but only $ADR_COUNT ADR(s) documented"
      echo "    Suggested action: /reverse-document architecture src/core/[system]"
    fi
  fi
fi

# --- Check 4: Gameplay systems without design docs ---
#
# A system counts as documented if EITHER:
#   (a) an exact-named file exists (design/gdd/<slug>.md or <slug>-system.md), or
#   (b) any file in design/gdd/ or design/ux/ whose name contains <slug> exists
#       (catches real docs that don't follow the exact naming convention, e.g.
#       "the-gap-mission.md" covering a "the_gap" subdirectory, or a system's
#       own "## UI Requirements" section living inside a differently-named GDD).
#
# Container directories (a system dir whose own file count is spread across
# subdirectories, e.g. src/gameplay/ui/'s 8 per-screen folders, or
# src/gameplay/missions/'s per-mission folders) are checked per-subdirectory
# rather than as one blob — a directory where every subdirectory already has
# its own doc is fully covered even though no single consolidated file exists
# at the parent's exact expected path. Only genuinely uncovered subdirectories
# are flagged, by name.
#
# Slug normalization: underscores -> hyphens, then (for subdirectory slugs
# only) common UI-container suffixes (-screen, -menu, -ui, -hud) are stripped
# before the fuzzy match, so "menagerie_screen" matches an existing
# "menagerie.md" without needing a "menagerie-screen.md" to exist verbatim.

_slugify() {
  echo "$1" | tr '_' '-'
}

_strip_ui_suffix() {
  echo "$1" | sed -E 's/-(screen|menu|ui|hud)$//'
}

# Returns 0 (found) if any doc in design/gdd/ or design/ux/ covers $1.
_doc_covers_slug() {
  local slug="$1"
  [ -f "design/gdd/${slug}.md" ] && return 0
  [ -f "design/gdd/${slug}-system.md" ] && return 0
  [ -f "design/ux/${slug}.md" ] && return 0
  # Fuzzy substring match — skip for very short/generic slugs (<=3 chars,
  # e.g. "ui", "ai") where a substring hit is more likely coincidence than
  # real coverage; those rely on the exact-match checks above instead.
  if [ ${#slug} -gt 3 ]; then
    local hit
    hit=$(find design/gdd design/ux -maxdepth 1 -iname "*${slug}*.md" 2>/dev/null | head -1)
    [ -n "$hit" ] && return 0
  fi
  return 1
}

if [ -d "src/gameplay" ]; then
  # Find major gameplay subdirectories (those with 5+ files)
  GAMEPLAY_SYSTEMS=$(find src/gameplay -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

  if [ -n "$GAMEPLAY_SYSTEMS" ]; then
    while IFS= read -r system_dir; do
      system_dir=$(echo "$system_dir" | sed 's|\\|/|g')
      system_name=$(basename "$system_dir")
      file_count=$(find "$system_dir" -type f 2>/dev/null | wc -l)
      file_count=$(echo "$file_count" | tr -d ' ')

      # If system has 5+ files, check for corresponding design doc
      if [ "$file_count" -ge 5 ]; then
        system_slug=$(_slugify "$system_name")

        if _doc_covers_slug "$system_slug"; then
          continue
        fi

        # No single doc covers the system as a whole — check whether it's a
        # container of independently-documented sub-features before flagging
        # the whole directory.
        SUB_DIRS=$(find "$system_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

        if [ -z "$SUB_DIRS" ]; then
          # Flat file layout, no subdirectories to check individually — same
          # behavior as before.
          echo "⚠️  GAP: Gameplay system 'src/gameplay/$system_name/' ($file_count files) has no design doc"
          echo "    Expected: design/gdd/${system_name}-system.md or design/gdd/${system_name}.md"
          echo "    Suggested action: /reverse-document design src/gameplay/$system_name"
        else
          UNCOVERED_SUBS=()
          while IFS= read -r sub_dir; do
            sub_dir=$(echo "$sub_dir" | sed 's|\\|/|g')
            sub_name=$(basename "$sub_dir")
            sub_slug=$(_slugify "$sub_name")
            stripped_slug=$(_strip_ui_suffix "$sub_slug")

            if _doc_covers_slug "$sub_slug" || _doc_covers_slug "$stripped_slug"; then
              continue
            fi
            UNCOVERED_SUBS+=("$sub_name")
          done <<< "$SUB_DIRS"

          if [ ${#UNCOVERED_SUBS[@]} -gt 0 ]; then
            echo "⚠️  GAP: ${#UNCOVERED_SUBS[@]} sub-feature(s) under 'src/gameplay/$system_name/' have no design doc:"
            for sub in "${UNCOVERED_SUBS[@]}"; do
              echo "    - src/gameplay/$system_name/$sub/"
            done
            echo "    Suggested action: /reverse-document design src/gameplay/$system_name/[sub-feature]"
          fi
        fi
      fi
    done <<< "$GAMEPLAY_SYSTEMS"
  fi
fi

# --- Check 5: Production planning ---
if [ "$SRC_FILES" -gt 100 ]; then
  # For projects with substantial code, check for production planning
  if [ ! -d "production/sprints" ] && [ ! -d "production/milestones" ]; then
    echo "⚠️  GAP: Large codebase ($SRC_FILES files) but no production planning found"
    echo "    Suggested action: /sprint-plan or create production/ directory"
  fi
fi

# --- Summary ---
echo ""
echo "💡 To get a comprehensive project analysis, run: /project-stage-detect"
echo "==================================="

exit 0
