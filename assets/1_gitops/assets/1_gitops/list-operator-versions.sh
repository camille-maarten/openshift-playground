#!/bin/bash

# ============================================================================
# List All Operator Versions Managed by ArgoCD
# ============================================================================
# This script lists all operators managed through ArgoCD and their versions,
# then appends the information to versions.txt
#
# Prerequisites:
# - oc CLI installed and logged in
# - ArgoCD applications deployed
#
# Usage:
#   ./list-operator-versions.sh
# ============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
    echo ""
}

# ============================================================================
# GET NAMESPACE AND OPERATOR PATTERN FOR APP
# ============================================================================

get_namespace_for_app() {
    case "$1" in
        "kafka-operator") echo "kafka" ;;
        "developer-hub") echo "rhdh" ;;
        "devspaces") echo "openshift-operators" ;;
        "openshift-ai") echo "redhat-ods-applications" ;;
        "serverless") echo "openshift-serverless" ;;
        "service-mesh") echo "openshift-operators" ;;
        "jaeger") echo "openshift-operators" ;;
        "elasticsearch") echo "elastic-system" ;;
        "keycloak") echo "keycloak" ;;
        "amq-broker") echo "openshift-operators" ;;
        *) echo "" ;;
    esac
}

get_operator_pattern_for_app() {
    case "$1" in
        "kafka-operator") echo "Streams for Apache Kafka" ;;
        "developer-hub") echo "Red Hat Developer Hub" ;;
        "devspaces") echo "Red Hat OpenShift Dev Spaces" ;;
        "openshift-ai") echo "Red Hat OpenShift AI" ;;
        "serverless") echo "Red Hat OpenShift Serverless" ;;
        "service-mesh") echo "Red Hat OpenShift Service Mesh 3" ;;
        "jaeger") echo "Community Jaeger Operator" ;;
        "elasticsearch") echo "Elasticsearch (ECK) Operator" ;;
        "keycloak") echo "Red Hat Single Sign-On" ;;
        "amq-broker") echo "Red Hat Integration - AMQ Broker" ;;
        *) echo "" ;;
    esac
}

# ============================================================================
# GET OPERATOR VERSIONS
# ============================================================================

get_operator_versions() {
    print_header "Collecting Operator Versions from ArgoCD Applications"

    # Determine project root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    INFO_DIR="${PROJECT_ROOT}/info"
    VERSIONS_FILE="${INFO_DIR}/versions.txt"

    # Create info directory if it doesn't exist
    mkdir -p "${INFO_DIR}"

    # Create or update versions.txt with timestamp
    echo "" >> "${VERSIONS_FILE}"
    echo "# ArgoCD-Managed Operator Versions - $(date '+%Y-%m-%d %H:%M:%S')" >> "${VERSIONS_FILE}"
    echo "# ============================================================================" >> "${VERSIONS_FILE}"

    # Get all ArgoCD applications
    print_info "Getting ArgoCD applications..."
    APPS=$(oc get applications -n openshift-gitops -o jsonpath='{.items[*].metadata.name}')

    print_info "Collecting operator versions..."

    for app in $APPS; do
        # Get namespace and operator pattern for this app
        namespace=$(get_namespace_for_app "$app")
        operator_pattern=$(get_operator_pattern_for_app "$app")

        # Skip non-operator applications
        if [ -z "$namespace" ] || [ -z "$operator_pattern" ]; then
            continue
        fi

        print_info "Checking $app in namespace $namespace..."

        # Get operator version from CSV
        OPERATOR_INFO=$(oc get csv -n "$namespace" -o jsonpath='{range .items[*]}{.spec.displayName}{"|"}{.spec.version}{"\n"}{end}' 2>/dev/null | grep -i "$operator_pattern" | head -1 || echo "")

        if [ -n "$OPERATOR_INFO" ]; then
            OPERATOR_NAME=$(echo "$OPERATOR_INFO" | cut -d'|' -f1)
            OPERATOR_VERSION=$(echo "$OPERATOR_INFO" | cut -d'|' -f2)

            echo "$app: $OPERATOR_NAME - $OPERATOR_VERSION" >> "${VERSIONS_FILE}"
            print_success "$app: $OPERATOR_VERSION"
        else
            echo "$app: Not found or not yet deployed" >> "${VERSIONS_FILE}"
            print_info "$app: Not found or not yet deployed"
        fi
    done

    echo "" >> "${VERSIONS_FILE}"

    print_success "Operator versions appended to: ${VERSIONS_FILE}"
}

# ============================================================================
# DISPLAY SUMMARY
# ============================================================================

display_summary() {
    print_header "Summary"

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
    INFO_DIR="${PROJECT_ROOT}/info"
    VERSIONS_FILE="${INFO_DIR}/versions.txt"

    echo "Operator versions have been collected and appended to:"
    echo "  ${VERSIONS_FILE}"
    echo ""
    echo "To view the file:"
    echo "  cat ${VERSIONS_FILE}"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "ArgoCD Operator Version Collection"

    # Check for oc
    if ! command -v oc &> /dev/null; then
        print_error "oc CLI is not installed"
        exit 1
    fi

    # Check if logged in
    if ! oc whoami &> /dev/null; then
        print_error "Not logged into OpenShift. Please run 'oc login' first"
        exit 1
    fi

    # Collect versions
    get_operator_versions

    # Display summary
    display_summary
}

# Run main function
main
