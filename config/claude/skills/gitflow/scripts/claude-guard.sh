#!/bin/bash
# PreToolUse(Bash) hook: turns into a permission prompt the commands the
# gitflow skill keeps under human control, whatever their spelling
# (git -C, rtk git, chained commands): writes to Azure Boards, PR creation or
# update, and any push that forces.

cmd=$(jq -r '.tool_input.command // empty')
[[ -z $cmd ]] && exit 0

reason=""
if grep -Eq '\baz +boards +work-item +(create|update|delete)\b|\baz +boards +work-item +relation +(add|remove)\b' <<< "$cmd"; then
    reason="writes to Azure Boards"
elif grep -Eq '\baz +repos +pr +(create|update)\b' <<< "$cmd"; then
    reason="creates or updates an Azure DevOps pull request"
elif grep -Eq '\bgit\b[^;&|]*\bpush\b[^;&|]*( --force\b| --force-with-lease\b| --force-if-includes\b| -[a-zA-Z]*f[a-zA-Z]*\b| \+[^ ])' <<< "$cmd"; then
    reason="force push"
fi
[[ -z $reason ]] && exit 0

jq -cn --arg r "gitflow: $reason, human control required" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
