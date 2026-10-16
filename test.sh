#!/usr/bin/env bash
# Invariants for the onpoint-ste100 rulebook, ported from OnPoint's test.sh.
# The single truth is personas/*.yaml; surfaces/ is generated. Globs ordered
# by `order` — renaming or reordering an axis is how the rulebook changes.
set -uo pipefail
cd "$(dirname "$0")"
FAIL=0
ok()  { echo "ok   $1"; }
bad() { echo "FAIL $1"; FAIL=1; }

# 1. generated surfaces are fresh and complete
if uv run --script adapters/build.py --check >/dev/null 2>&1; then
  ok "surfaces fresh (build --check: claude-plugin + pi)"
else
  bad "surfaces stale — run: uv run --script adapters/build.py"
fi

# 2. axis order: personas carry orders 0..n strictly increasing
orders=$(ls personas/*.yaml)
n=$(wc -l <<< "$orders" | tr -d ' ')
seq_ok=true
for i in $(seq 0 $((n-1))); do
  f=$(sed -n "$((i+1))p" <<< "$orders")
  grep -q "^order: $i$" "$f" || seq_ok=false
done
$seq_ok && ok "axis order 0..$((n-1)) (glob order = axis order)" \
        || bad "axis order broken in personas/*.yaml"

# 3. claude hook payload: full-bodies stdout must stay under the 10KB cliff
#    (measured upstream: 10000 B inlines, 10050 B silently spills to a file)
PAY=$(CLAUDE_PLUGIN_ROOT="$PWD/surfaces/claude-plugin" ./surfaces/claude-plugin/hooks/inject.sh | wc -c | tr -d ' ')
[ "$PAY" -lt 9800 ] && ok "hook payload ${PAY}B < 9800B" || bad "hook payload ${PAY}B exceeds budget"

# 4. --line reinforcement works and names both axes
LINE=$(CLAUDE_PLUGIN_ROOT="$PWD/surfaces/claude-plugin" ./surfaces/claude-plugin/hooks/inject.sh --line)
grep -q "essence first" <<< "$LINE" && grep -q "say less" <<< "$LINE" \
  && ok "--line reinforcement names both axes" || bad "--line broken"

# 5. body parity: pi bodies == claude personas bodies (same truth, two channels)
B="$PWD/surfaces/pi/bodies/on-point-ste.md"
cat surfaces/claude-plugin/personas/*.md | grep -v '^<!-- generated' > /tmp/claude-bodies.$$ 2>/dev/null
# strip generated-note headers from claude persona surfaces (none injected there, but stay safe)
if diff -q <(grep -v '^<!-- generated' "$B") /tmp/claude-bodies.$$ >/dev/null 2>&1; then
  ok "pi bodies == claude persona bodies"
else
  bad "pi bodies drift from claude persona bodies"
fi
rm -f /tmp/claude-bodies.$$

# 6. output-style ratio (upstream rule): style must be <= 1/2 of the bodies
STYLE=$(wc -c < surfaces/claude-plugin/output-styles/on-point.md | tr -d ' ')
[ "$STYLE" -le $(( PAY / 2 )) ] && ok "style ${STYLE}B <= ½ bodies (${PAY}B)" \
  || bad "style ${STYLE}B > ½ bodies (${PAY}B)"

# 7. the model-agnostic rule: no vendor slug anywhere in the truth
if grep -rqiE "deepseek|glm|kimi|moonshot|anthropic" personas/*.yaml; then
  bad "vendor model name leaked into persona YAML"
else
  ok "personas model-agnostic (no vendor slugs)"
fi

exit $FAIL
