#!/usr/bin/env bash
# Chỉ TẢI mã nguồn về để đọc trước. KHÔNG cài đặt, KHÔNG chạy code của repo nào.
set -u
DEST="${1:-$HOME/claude-repos}"
mkdir -p "$DEST"
REPOS=(
  obra/superpowers affaan-m/ECC multica-ai/andrej-karpathy-skills garrytan/gstack
  DietrichGebert/ponytail shareAI-lab/learn-claude-code
  anthropics/skills nextlevelbuilder/ui-ux-pro-max-skill Leonxlnx/taste-skill
  ComposioHQ/awesome-claude-skills wshobson/agents anthropics/claude-plugins-official
  Graphify-Labs/graphify thedotmack/claude-mem colbymchenry/codegraph
  yamadashy/repomix OthmanAdi/planning-with-files
  firecrawl/firecrawl farion1231/cc-switch punkpeye/awesome-mcp-servers
  multica-ai/multica musistudio/claude-code-router microsoft/playwright-mcp
  github/github-mcp-server BloopAI/vibe-kanban
  x1xhlol/system-prompts-and-models-of-ai-tools JuliusBrussee/caveman
  shanraisshan/claude-code-best-practice openai/codex-plugin-cc jarrodwatts/claude-hud
)
for r in "${REPOS[@]}"; do
  dir="$DEST/${r//\//__}"
  if [ -d "$dir" ]; then echo "Đã có: $r"; continue; fi
  echo "Đang tải: $r"
  git clone --depth 1 "https://github.com/$r.git" "$dir" || echo "LỖI khi tải $r"
done
echo "Xong. Mã nguồn nằm ở: $DEST"
