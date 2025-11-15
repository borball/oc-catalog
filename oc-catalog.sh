#!/bin/bash
# script to list all operators in a catalog and their channels, versions, etc.
# use opm to implement it

# Default values
version="4.18"
catalog="redhat-operator"
index_image=""
show_help=0
limit=""

# Parse options using getopts
while getopts "v:c:i:l:h" opt; do
    case $opt in
        v)
            version="$OPTARG"
            ;;
        c)
            catalog="$OPTARG"
            ;;
        i)
            index_image="$OPTARG"
            ;;
        l)
            limit="$OPTARG"
            ;;
        h)
            show_help=1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            show_help=1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            show_help=1
            ;;
    esac
done

# Shift past the options
shift $((OPTIND-1))

# Get command and packages from remaining arguments
cmd="$1"
shift 2>/dev/null

packages=()
while [ $# -gt 0 ]; do
    packages+=("$1")
    shift
done

# Color and formatting variables
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Formatting functions
print_header() {
    local title="$1"
    local emoji="$2"
    echo -e "\n${emoji} ${CYAN}${BOLD}${title}${NC}"
    printf "${BOLD}%s${NC}\n" "$(printf '=%.0s' {1..50})"
}

print_table_header() {
    local col1="$1"
    local col2="$2"
    local width1="${3:-25}"
    local width2="${4:-20}"
    
    echo -e "${BOLD}┌$(printf '─%.0s' $(seq 1 $((width1+2))))┬$(printf '─%.0s' $(seq 1 $((width2+2))))┐${NC}"
    printf "${BOLD}│ %-${width1}s │ %-${width2}s │${NC}\n" "$col1" "$col2"
    echo -e "${BOLD}├$(printf '─%.0s' $(seq 1 $((width1+2))))┼$(printf '─%.0s' $(seq 1 $((width2+2))))┤${NC}"
}

print_table_row() {
    local col1="$1"
    local col2="$2"
    local width1="${3:-25}"
    local width2="${4:-20}"
    
    printf "│ ${GREEN}%-${width1}s${NC} │ ${YELLOW}%-${width2}s${NC} │\n" "$col1" "$col2"
}

print_table_footer() {
    local width1="${1:-25}"
    local width2="${2:-20}"
    echo -e "${BOLD}└$(printf '─%.0s' $(seq 1 $((width1+2))))┴$(printf '─%.0s' $(seq 1 $((width2+2))))┘${NC}"
}

print_summary() {
    local count="$1"
    local type="$2"
    echo -e "${BLUE}📊 Summary: ${BOLD}${count}${NC} ${BLUE}${type} found${NC}"
}

_init() {
    # If custom index image is provided, use it directly
    if [ -n "$index_image" ]; then
        _index="$index_image"
        # Create a safe filename from the index image (replace special chars with -)
        local safe_name=$(echo "$index_image" | sed 's/[:/]/-/g' | sed 's/@/-/g')
        local json_file="/tmp/custom-index-${safe_name}.json"
    else
        # Defensive check for required variables when not using custom index
        if [ -z "$version" ]; then
            echo -e "${RED}Error: Version parameter is required when not using -i${NC}" >&2
            exit 1
        fi
        if [ -z "$catalog" ]; then
            echo -e "${RED}Error: Catalog parameter is required when not using -i${NC}" >&2
            exit 1
        fi
        
        # Validate catalog name
        local valid_catalogs=("redhat-operator" "certified-operator" "community-operator" "redhat-marketplace")
        local catalog_valid=0
        for valid_catalog in "${valid_catalogs[@]}"; do
            if [ "$catalog" = "$valid_catalog" ]; then
                catalog_valid=1
                break
            fi
        done
        
        if [ $catalog_valid -eq 0 ]; then
            echo -e "${RED}Error: Invalid catalog '$catalog'${NC}" >&2
            echo -e "${RED}Valid catalogs are: ${valid_catalogs[*]}${NC}" >&2
            exit 1
        fi
        
        # Check if version is a SHA256 digest
        if [[ "$version" == sha256:* ]]; then
            _index="registry.redhat.io/redhat/${catalog}-index@${version}"
            # Use SHA256 for cache filename (replace : and / with -)
            local cache_suffix=$(echo "$version" | sed 's/[:/]/-/g')
            local json_file="/tmp/${catalog}-${cache_suffix}.json"
        else
            _index="registry.redhat.io/redhat/${catalog}-index:v${version}"
            local json_file="/tmp/${catalog}-${version}.json"
        fi
    fi
    
    if [ -f "$json_file" ]; then
        #if modified more than 120 minutes ago, re-render
        if [ $(stat -c %Y "$json_file") -lt $(date -d "1200 minutes ago" +%s) ]; then
            echo -e "${BLUE}Refreshing catalog data...${NC}" >&2
            if ! opm render $_index > "$json_file" 2>/dev/null; then
                echo -e "${RED}Error: Failed to refresh catalog data from $_index${NC}" >&2
                echo -e "${RED}Please check if the catalog and version/digest are valid${NC}" >&2
                rm -f "$json_file"  # Remove potentially corrupted file
                exit 1
            fi
        fi
    else
        echo -e "${BLUE}Downloading catalog data...${NC}" >&2
        if ! opm render $_index > "$json_file" 2>/dev/null; then
            echo -e "${RED}Error: Failed to download catalog data from $_index${NC}" >&2
            echo -e "${RED}Please check if the catalog and version/digest are valid${NC}" >&2
            rm -f "$json_file"  # Remove potentially corrupted file
            exit 1
        fi
    fi
    
    # Verify the downloaded file is valid JSON and not empty
    if [ ! -s "$json_file" ] || ! jq empty "$json_file" >/dev/null 2>&1; then
        echo -e "${RED}Error: Downloaded catalog data is invalid or empty${NC}" >&2
        rm -f "$json_file"
        exit 1
    fi
}

packages() {
    # Determine display name and json file path
    if [ -n "$index_image" ]; then
        local display_name="custom-index: $(echo "$index_image" | sed 's/.*\///' | cut -c1-40)..."
        local safe_name=$(echo "$index_image" | sed 's/[:/]/-/g' | sed 's/@/-/g')
        local json_file="/tmp/custom-index-${safe_name}.json"
    elif [[ "$version" == sha256:* ]]; then
        local display_name="${catalog}@${version:0:19}..."
        local cache_suffix=$(echo "$version" | sed 's/[:/]/-/g')
        local json_file="/tmp/${catalog}-${cache_suffix}.json"
    else
        local display_name="${catalog}-${version}"
        local json_file="/tmp/${catalog}-${version}.json"
    fi
    
    print_header "OpenShift Operator Packages (${display_name})" "📦"
    print_table_header "Package Name" "Default Channel" 55 30
    
    local count=0
    
    if [ ${#packages[@]} -eq 0 ]; then
        if [ -n "$limit" ]; then
            while IFS=$'\t' read -r name channel; do
                print_table_row "$name" "$channel" 55 30
                ((count++))
            done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.package")|[.name,.defaultChannel])|@tsv' | head -n "$limit")
        else
            while IFS=$'\t' read -r name channel; do
                print_table_row "$name" "$channel" 55 30
                ((count++))
            done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.package")|[.name,.defaultChannel])|@tsv')
        fi
    else
        for package in ${packages[@]}; do
            if [ -n "$limit" ]; then
                while IFS=$'\t' read -r name channel; do
                    print_table_row "$name" "$channel" 55 30
                    ((count++))
                done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.package" and .name=="'$package'")|[.name,.defaultChannel])|@tsv' | head -n "$limit")
            else
                while IFS=$'\t' read -r name channel; do
                    print_table_row "$name" "$channel" 55 30
                    ((count++))
                done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.package" and .name=="'$package'")|[.name,.defaultChannel])|@tsv')
            fi
        done
    fi
    
    print_table_footer 55 30
    print_summary "$count" "packages"
    echo
}

channels() {
    # Determine display name and json file path
    if [ -n "$index_image" ]; then
        local display_name="custom-index: $(echo "$index_image" | sed 's/.*\///' | cut -c1-40)..."
        local safe_name=$(echo "$index_image" | sed 's/[:/]/-/g' | sed 's/@/-/g')
        local json_file="/tmp/custom-index-${safe_name}.json"
    elif [[ "$version" == sha256:* ]]; then
        local display_name="${catalog}@${version:0:19}..."
        local cache_suffix=$(echo "$version" | sed 's/[:/]/-/g')
        local json_file="/tmp/${catalog}-${cache_suffix}.json"
    else
        local display_name="${catalog}-${version}"
        local json_file="/tmp/${catalog}-${version}.json"
    fi
    
    print_header "OpenShift Operator Channels (${display_name})" "📺"
    print_table_header "Package Name" "Channel" 55 35
    
    local count=0
    
    if [ ${#packages[@]} -eq 0 ]; then
        if [ -n "$limit" ]; then
            while IFS=$'\t' read -r package channel; do
                print_table_row "$package" "$channel" 55 35
                ((count++))
            done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.channel")|[.package,.name])|@tsv' | head -n "$limit")
        else
            while IFS=$'\t' read -r package channel; do
                print_table_row "$package" "$channel" 55 35
                ((count++))
            done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.channel")|[.package,.name])|@tsv')
        fi
    else
        for package in ${packages[@]}; do
            if [ -n "$limit" ]; then
                while IFS=$'\t' read -r pkg channel; do
                    print_table_row "$pkg" "$channel" 55 35
                    ((count++))
                done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.channel" and .package=="'$package'")|[.package,.name])|@tsv' | head -n "$limit")
            else
                while IFS=$'\t' read -r pkg channel; do
                    print_table_row "$pkg" "$channel" 55 35
                    ((count++))
                done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.channel" and .package=="'$package'")|[.package,.name])|@tsv')
            fi
        done
    fi
    
    print_table_footer 55 35
    print_summary "$count" "channels"
    echo
}

versions() {
    # Determine display name and json file path
    if [ -n "$index_image" ]; then
        local display_name="custom-index: $(echo "$index_image" | sed 's/.*\///' | cut -c1-40)..."
        local safe_name=$(echo "$index_image" | sed 's/[:/]/-/g' | sed 's/@/-/g')
        local json_file="/tmp/custom-index-${safe_name}.json"
    elif [[ "$version" == sha256:* ]]; then
        local display_name="${catalog}@${version:0:19}..."
        local cache_suffix=$(echo "$version" | sed 's/[:/]/-/g')
        local json_file="/tmp/${catalog}-${cache_suffix}.json"
    else
        local display_name="${catalog}-${version}"
        local json_file="/tmp/${catalog}-${version}.json"
    fi
    
    print_header "OpenShift Operator Versions (${display_name})" "🔢"
    print_table_header "Package Name" "Version/Bundle" 55 45
    
    local count=0
    
    if [ ${#packages[@]} -eq 0 ]; then
        if [ -n "$limit" ]; then
            # Get all unique packages first, then limit last N versions per package (most recent)
            local all_packages=($(cat "$json_file" | jq -cr '.|select(.schema=="olm.bundle")|.package' | sort -u))
            for pkg in "${all_packages[@]}"; do
                while IFS=$'\t' read -r package version name; do
                    print_table_row "$package" "$name" 55 45
                    ((count++))
                done < <(cat "$json_file" | jq -cr 'select(.schema=="olm.bundle" and .package=="'$pkg'") | [ .package, ((.properties // [] | map(select(.type=="olm.package") | .value.version) | .[0]) // (.name | sub("^.*\\.v"; "") | sub("-.*$"; ""))), .name ] | @tsv' | sort -t $'\t' -k2,2Vr | head -n "$limit")
            done
        else
            while IFS=$'\t' read -r package ver; do
                print_table_row "$package" "$ver" 55 45
                ((count++))
            done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.bundle")|[.package,.name])|@tsv')
        fi
    else
        for package in ${packages[@]}; do
            if [ -n "$limit" ]; then
                while IFS=$'\t' read -r pkg version name; do
                    print_table_row "$pkg" "$name" 55 45
                    ((count++))
                done < <(cat "$json_file" | jq -cr 'select(.schema=="olm.bundle" and .package=="'$package'") | [ .package, ((.properties // [] | map(select(.type=="olm.package") | .value.version) | .[0]) // (.name | sub("^.*\\.v"; "") | sub("-.*$"; ""))), .name ] | @tsv' | sort -t $'\t' -k2,2Vr | head -n "$limit")
            else
                while IFS=$'\t' read -r pkg ver; do
                    print_table_row "$pkg" "$ver" 55 45
                    ((count++))
                done < <(cat "$json_file" | jq -cr '(.|select(.schema=="olm.bundle" and .package=="'$package'")|[.package,.name])|@tsv')
            fi
        done
    fi
    
    print_table_footer 55 45
    print_summary "$count" "versions"
    echo
}

hub() {
    # Set packages array with hub packages and call versions function
    packages=("odf-operator" "openshift-gitops-operator" "topology-aware-lifecycle-manager" "local-storage-operator" "cluster-logging" "amq-streams" "amq-streams-console" "advanced-cluster-management")
    versions
}

cloudran() {
    # Set packages array with cloudran packages and call versions function
    packages=("ptp-operator" "sriov-network-operator" "local-storage-operator" "lvms-operator" "cluster-logging" "lifecycle-agent" "redhat-oadp-operator")
    versions
}

if [ -z "$cmd" ] || [ $show_help -eq 1 ]; then
    print_header "OpenShift Operator Catalog Tool" "🚀"
    echo -e "${BOLD}Usage:${NC} $0 [options] <command> [packages...]"
    echo
    echo -e "${BOLD}Options:${NC}"
    echo -e "  ${GREEN}-v${NC} <version>   OpenShift version or SHA256 digest (default: 4.18)"
    echo -e "                   Examples: 4.18, sha256:78c4590eaa7a8c75a08ece..."
    echo -e "  ${GREEN}-c${NC} <catalog>   Catalog name (default: redhat-operator)"
    echo -e "  ${GREEN}-i${NC} <image>     Custom catalog index image (overrides -v and -c)"
    echo -e "                   Example: registry.example.com/my-catalog:latest"
    echo -e "  ${GREEN}-l${NC} <limit>     Limit number of results (default: no limit)"
    echo -e "                   For packages/channels: limits total results"
    echo -e "                   For versions/hub/cloudran: limits versions per package"
    echo -e "                   Example: -l 5 versions shows 5 versions per package"
    echo -e "  ${GREEN}-h${NC}             Show this help message"
    echo
    echo -e "${BOLD}Commands:${NC}"
    echo -e "  📦 ${YELLOW}packages${NC}  - List operator packages and their default channels"
    echo -e "  📺 ${YELLOW}channels${NC}  - List all available channels for packages"
    echo -e "  🔢 ${YELLOW}versions${NC}  - List all available versions/bundles for packages"
    echo -e "  🏢 ${YELLOW}hub${NC}       - List available versions for hub packages"
    echo -e "  📡 ${YELLOW}cloudran${NC}  - List available versions for cloudran packages"
    echo
    echo -e "${BOLD}Package Arguments:${NC}"
    echo -e "  • Specify one or more package names to filter results"
    echo -e "  • If no packages provided, all packages will be listed"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo -e "  ${CYAN}$0 packages${NC}                                  # Use defaults (4.18, redhat-operator)"
    echo -e "  ${CYAN}$0 -v 4.17 packages${NC}                         # Different version"
    echo -e "  ${CYAN}$0 -v sha256:78c4590eaa7a... packages${NC}       # Use SHA256 digest"
    echo -e "  ${CYAN}$0 -c certified-operator packages${NC}           # Different catalog"
    echo -e "  ${CYAN}$0 -i registry.example.com/my-catalog:v1.0 packages${NC} # Custom index"
    echo -e "  ${CYAN}$0 -l 5 versions ptp-operator${NC}               # Show 5 versions for ptp-operator"
    echo -e "  ${CYAN}$0 -v 4.18 -c redhat-operator packages ptp-operator cluster-logging${NC}"
    echo -e "  ${CYAN}$0 -c certified-operator packages sriov-fec${NC} # Certified operator"
    echo -e "  ${CYAN}$0 hub${NC}                                       # List all hub operator versions"
    echo -e "  ${CYAN}$0 cloudran${NC}                                  # List all cloudran operator versions"
    echo
    exit 1
fi

_init

$cmd "$@"