#!/usr/bin/env bash
# Setup script to install git hooks for this repository
# Run this script after cloning the repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/.git/hooks"

echo "Installing git hooks..."

# Create pre-commit hook
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/usr/bin/env bash
# Pre-commit hook to prevent secrets from being committed to dotfiles repo
# This is a repository-specific hook, not managed by chezmoi

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Secret patterns to detect
declare -A SECRET_PATTERNS=(
    ["AWS Access Key"]="AKIA[0-9A-Z]{16}"
    ["AWS Secret Key"]="aws_secret_access_key[[:space:]]*=[[:space:]]*['\"]?[A-Za-z0-9/+=]{40}['\"]?"
    ["GitHub Token"]="gh[pousr]_[0-9a-zA-Z]{36,}"
    ["GitHub Personal Access Token"]="github_pat_[0-9a-zA-Z]{22}_[0-9a-zA-Z]{59}"
    ["Generic API Key"]="api[_-]?key[[:space:]]*[=:][[:space:]]*['\"]?[0-9a-zA-Z]{32,}['\"]?"
    ["Generic Secret"]="secret[[:space:]]*[=:][[:space:]]*['\"]?[0-9a-zA-Z]{32,}['\"]?"
    ["Private Key"]="-----BEGIN (RSA |EC |OPENSSH |DSA |PGP )?PRIVATE KEY"
    ["Password in URL"]="[a-zA-Z]{3,10}://[^/\\s:@]{3,20}:[^/\\s:@]{3,20}@.{1,100}"
    ["Slack Token"]="xox[baprs]-[0-9a-zA-Z]{10,48}"
    ["Slack Webhook"]="https://hooks\.slack\.com/services/T[a-zA-Z0-9_]{8}/B[a-zA-Z0-9_]{8,12}/[a-zA-Z0-9_]{24}"
    ["OpenAI API Key"]="sk-[a-zA-Z0-9]{48}"
    ["Anthropic API Key"]="sk-ant-api03-[a-zA-Z0-9-_]{95}"
    ["JWT Token"]="eyJ[A-Za-z0-9-_=]+\.eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_.+/=]+"
    ["Generic Token"]="token[[:space:]]*[=:][[:space:]]*['\"]?[0-9a-zA-Z]{32,}['\"]?"
    ["Bearer Token"]="Bearer[[:space:]]+[0-9a-zA-Z\-._~+/]+=*"
)

# Files to skip (already encrypted or intentionally containing patterns)
SKIP_PATTERNS=(
    "\.age$"           # age encrypted files
    "\.encrypted$"     # other encrypted files
    "\.sample$"        # sample files
    "CLAUDE\.md$"      # documentation file
    "\.git/"           # git metadata
    "^\.git/hooks/"    # git hooks themselves
    "setup-git-hooks\.sh$"  # this setup script
)

# Function to check if file should be skipped
should_skip_file() {
    local file="$1"
    for pattern in "${SKIP_PATTERNS[@]}"; do
        if [[ "$file" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Get list of staged files
staged_files=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$staged_files" ]; then
    exit 0
fi

# Flag to track if secrets were found
secrets_found=0

echo "🔍 Scanning staged files for secrets..."

# Check each staged file
while IFS= read -r file; do
    # Skip if file doesn't exist (deleted files)
    if [ ! -f "$file" ]; then
        continue
    fi

    # Skip if file matches skip patterns
    if should_skip_file "$file"; then
        continue
    fi

    # Get the staged content
    content=$(git show ":$file" 2>/dev/null || continue)

    # Check against each secret pattern
    for pattern_name in "${!SECRET_PATTERNS[@]}"; do
        pattern="${SECRET_PATTERNS[$pattern_name]}"

        # Use grep with Perl regex for more complex patterns
        if echo "$content" | grep -qP "$pattern" 2>/dev/null; then
            if [ $secrets_found -eq 0 ]; then
                echo -e "${RED}❌ Potential secrets detected!${NC}\n"
            fi
            echo -e "${RED}File: ${file}${NC}"
            echo -e "${YELLOW}Pattern: ${pattern_name}${NC}"

            # Show the matching lines (with line numbers)
            echo "$content" | grep -nP "$pattern" --color=always | head -3
            echo ""

            secrets_found=1
        fi
    done
done <<< "$staged_files"

if [ $secrets_found -eq 1 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Commit blocked due to potential secrets!${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "If this is a false positive, you can:"
    echo "1. Use age encryption: chezmoi edit <file>"
    echo "2. Add the file pattern to SKIP_PATTERNS in .git/hooks/pre-commit"
    echo "3. Bypass this check (NOT RECOMMENDED): git commit --no-verify"
    echo ""
    exit 1
fi

echo -e "${GREEN}✅ No secrets detected. Proceeding with commit.${NC}"
exit 0
EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Git hooks installed successfully!"
echo ""
echo "The following hooks were installed:"
echo "  - pre-commit: Prevents committing secrets to the repository"
echo ""
echo "To bypass the hook (not recommended):"
echo "  git commit --no-verify"
