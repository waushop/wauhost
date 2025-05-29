#!/bin/bash
# Helm Chart Validation Script
# Validates all Helm charts in the repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CHARTS_DIR="$REPO_ROOT/charts"

echo "🔍 Validating Helm Charts..."
echo "=========================="

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}❌ Helm is not installed. Please install Helm first.${NC}"
    exit 1
fi

# Check if yamllint is installed
if ! command -v yamllint &> /dev/null; then
    echo -e "${YELLOW}⚠️  yamllint is not installed. Skipping YAML linting.${NC}"
    YAMLLINT_AVAILABLE=false
else
    YAMLLINT_AVAILABLE=true
fi

# Track validation results
FAILED_CHARTS=()
WARNINGS=()

# Function to validate a chart
validate_chart() {
    local chart_path="$1"
    local chart_name=$(basename "$chart_path")
    
    echo -e "\n📦 Validating chart: ${YELLOW}$chart_name${NC}"
    
    # Check if Chart.yaml exists
    if [[ ! -f "$chart_path/Chart.yaml" ]]; then
        echo -e "  ${RED}❌ Missing Chart.yaml${NC}"
        FAILED_CHARTS+=("$chart_name: Missing Chart.yaml")
        return 1
    fi
    
    # Validate Chart.yaml structure
    if ! yq eval '.apiVersion' "$chart_path/Chart.yaml" > /dev/null 2>&1; then
        echo -e "  ${RED}❌ Invalid Chart.yaml${NC}"
        FAILED_CHARTS+=("$chart_name: Invalid Chart.yaml")
        return 1
    fi
    
    # Check required fields in Chart.yaml
    local api_version=$(yq eval '.apiVersion' "$chart_path/Chart.yaml")
    local name=$(yq eval '.name' "$chart_path/Chart.yaml")
    local version=$(yq eval '.version' "$chart_path/Chart.yaml")
    
    if [[ "$api_version" == "null" ]] || [[ "$name" == "null" ]] || [[ "$version" == "null" ]]; then
        echo -e "  ${RED}❌ Missing required fields in Chart.yaml${NC}"
        FAILED_CHARTS+=("$chart_name: Missing required fields")
        return 1
    fi
    
    echo -e "  ✓ Chart.yaml valid"
    
    # Check if templates directory exists
    if [[ ! -d "$chart_path/templates" ]]; then
        echo -e "  ${YELLOW}⚠️  No templates directory${NC}"
        WARNINGS+=("$chart_name: No templates directory")
    fi
    
    # Check if values.yaml exists
    if [[ ! -f "$chart_path/values.yaml" ]]; then
        echo -e "  ${YELLOW}⚠️  No values.yaml file${NC}"
        WARNINGS+=("$chart_name: No values.yaml")
    fi
    
    # Run helm lint
    echo -e "  🔧 Running helm lint..."
    if helm lint "$chart_path" > /tmp/helm-lint-output.txt 2>&1; then
        echo -e "  ${GREEN}✓ Helm lint passed${NC}"
    else
        echo -e "  ${RED}❌ Helm lint failed${NC}"
        cat /tmp/helm-lint-output.txt | sed 's/^/    /'
        FAILED_CHARTS+=("$chart_name: Helm lint failed")
        return 1
    fi
    
    # Run helm template to check for rendering errors
    echo -e "  🔧 Testing template rendering..."
    if helm template test "$chart_path" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Template rendering successful${NC}"
    else
        echo -e "  ${RED}❌ Template rendering failed${NC}"
        helm template test "$chart_path" 2>&1 | head -20 | sed 's/^/    /'
        FAILED_CHARTS+=("$chart_name: Template rendering failed")
        return 1
    fi
    
    # YAML lint if available
    if [[ "$YAMLLINT_AVAILABLE" == "true" ]]; then
        echo -e "  🔧 Running yamllint..."
        if find "$chart_path" -name "*.yaml" -o -name "*.yml" | xargs yamllint -c "$REPO_ROOT/.yamllint" > /tmp/yamllint-output.txt 2>&1; then
            echo -e "  ${GREEN}✓ YAML lint passed${NC}"
        else
            echo -e "  ${YELLOW}⚠️  YAML lint warnings${NC}"
            head -10 /tmp/yamllint-output.txt | sed 's/^/    /'
            WARNINGS+=("$chart_name: YAML lint warnings")
        fi
    fi
    
    # Check for NOTES.txt
    if [[ -f "$chart_path/templates/NOTES.txt" ]]; then
        echo -e "  ${GREEN}✓ NOTES.txt present${NC}"
    else
        echo -e "  ${YELLOW}⚠️  No NOTES.txt template${NC}"
        WARNINGS+=("$chart_name: No NOTES.txt")
    fi
    
    # Check for README
    if [[ -f "$chart_path/README.md" ]]; then
        echo -e "  ${GREEN}✓ README.md present${NC}"
    else
        echo -e "  ${YELLOW}⚠️  No README.md${NC}"
        WARNINGS+=("$chart_name: No README.md")
    fi
    
    # Security checks
    echo -e "  🔒 Security checks..."
    
    # Check for hardcoded secrets in values.yaml
    if [[ -f "$chart_path/values.yaml" ]]; then
        if grep -E "(password|secret|key|token):\s*['\"]?[^'\"\s]+" "$chart_path/values.yaml" | grep -v -E "(^#|:\s*\"\")" > /dev/null 2>&1; then
            echo -e "  ${RED}❌ Potential hardcoded secrets in values.yaml${NC}"
            FAILED_CHARTS+=("$chart_name: Hardcoded secrets detected")
            return 1
        else
            echo -e "  ${GREEN}✓ No hardcoded secrets detected${NC}"
        fi
    fi
    
    # Check for external secrets support
    if grep -r "externalSecrets:" "$chart_path" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ External secrets support${NC}"
    else
        echo -e "  ${YELLOW}⚠️  No external secrets support${NC}"
        WARNINGS+=("$chart_name: No external secrets support")
    fi
    
    echo -e "  ${GREEN}✅ Chart validation passed${NC}"
    return 0
}

# Create yamllint config if it doesn't exist
if [[ ! -f "$REPO_ROOT/.yamllint" ]]; then
    cat > "$REPO_ROOT/.yamllint" << EOF
extends: default
rules:
  line-length:
    max: 150
  truthy:
    allowed-values: ['true', 'false', 'on', 'off']
  comments:
    min-spaces-from-content: 1
  braces:
    max-spaces-inside: 1
EOF
fi

# Validate all charts
for chart in "$CHARTS_DIR"/*; do
    if [[ -d "$chart" ]]; then
        validate_chart "$chart" || true
    fi
done

# Summary
echo -e "\n=============================="
echo "📊 Validation Summary"
echo "=============================="

if [[ ${#FAILED_CHARTS[@]} -eq 0 ]]; then
    echo -e "${GREEN}✅ All charts passed validation!${NC}"
else
    echo -e "${RED}❌ Failed charts (${#FAILED_CHARTS[@]}):${NC}"
    for failure in "${FAILED_CHARTS[@]}"; do
        echo -e "  - $failure"
    done
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}⚠️  Warnings (${#WARNINGS[@]}):${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "  - $warning"
    done
fi

# Clean up
rm -f /tmp/helm-lint-output.txt /tmp/yamllint-output.txt

# Exit with error if any charts failed
if [[ ${#FAILED_CHARTS[@]} -gt 0 ]]; then
    exit 1
fi

echo -e "\n${GREEN}✨ Validation complete!${NC}"