#!/usr/bin/env bash
# Verifies the tools and Azure login required for the Terraform on Azure course.
set -u
failed=0

status() { printf '%-7s%s\n' "[$1]" "$2"; }

check_tool() { # name, version command, required(1/0)
  if command -v "$1" >/dev/null 2>&1; then
    status OK "$(printf '%-11s %s' "$1" "$(eval "$2" 2>/dev/null | head -1)")"
  elif [ "$3" = 1 ]; then
    status FAIL "$1 not found"; failed=1
  else
    status WARN "$1 not found (optional, used on Days 4-5)"
  fi
}

check_tool terraform  "terraform version | head -1 | sed 's/Terraform v//'" 1
check_tool az         "az version --query '\"azure-cli\"' -o tsv" 1
check_tool git        "git --version | sed 's/git version //'" 1
check_tool tflint     "tflint --version" 0
check_tool checkov    "checkov --version" 0
check_tool aztfexport "aztfexport --version" 0

if acct=$(az account show --query '[name,id]' -o tsv 2>/dev/null); then
  status OK "Azure login: $(echo "$acct" | head -1) ($(echo "$acct" | tail -1))"
else
  status FAIL "Not logged in to Azure. Run: az login"; failed=1
fi

if [ -n "${ARM_SUBSCRIPTION_ID:-}" ]; then
  status OK "ARM_SUBSCRIPTION_ID is set"
else
  status WARN 'ARM_SUBSCRIPTION_ID not set. Run: export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)'
fi

if [ "$failed" = 1 ]; then echo; echo "Setup incomplete - fix the FAIL items above."; exit 1; fi
echo; echo "You are ready for the course!"
