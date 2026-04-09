#!/bin/bash
# script to list all operators in a catalog and their channels, versions, etc.
# use opm to implement it

# Default values
version="4.20"
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

# Renders a dynamic-width table from TSV data on stdin
# Usage: command_producing_tsv | render_table "Header1" "Header2" ...
# Sets global _table_row_count with number of data rows rendered
render_table() {
    local headers=("$@")
    local ncols=${#headers[@]}
    local colors
    colors[0]="$GREEN"
    colors[1]="$YELLOW"
    colors[2]="$CYAN"

    # Buffer all rows
    local rows=()
    local line
    while IFS= read -r line; do
        [ -n "$line" ] && rows+=("$line")
    done

    # Calculate column widths (min = header length, middle columns capped at 45)
    local widths=()
    local i
    local last_col=$((ncols - 1))
    for ((i=0; i<ncols; i++)); do
        widths[$i]=${#headers[$i]}
    done
    local cols
    for line in "${rows[@]}"; do
        IFS=$'\t' read -ra cols <<< "$line"
        for ((i=0; i<ncols; i++)); do
            (( ${#cols[$i]} > widths[$i] )) && widths[$i]=${#cols[$i]}
        done
    done
    # Cap middle columns (Channel(s)) at max width of 45
    for ((i=1; i<last_col; i++)); do
        (( widths[i] > 45 )) && widths[$i]=45
    done

    # Build borders and header
    local top="┌" mid="├" bot="└" hdr="│"
    for ((i=0; i<ncols; i++)); do
        local w=${widths[$i]}
        local bar=$(printf '─%.0s' $(seq 1 $((w+2))))
        top+="$bar"; mid+="$bar"; bot+="$bar"
        hdr+="$(printf " %-${w}s │" "${headers[$i]}")"
        if ((i < ncols-1)); then
            top+="┬"; mid+="┼"; bot+="┴"
        fi
    done
    top+="┐"; mid+="┤"; bot+="┘"

    echo -e "${BOLD}${top}${NC}"
    echo -e "${BOLD}${hdr}${NC}"
    echo -e "${BOLD}${mid}${NC}"

    # Render data rows (truncate middle columns if exceeding max width)
    for line in "${rows[@]}"; do
        IFS=$'\t' read -ra cols <<< "$line"
        local dr="│"
        for ((i=0; i<ncols; i++)); do
            local w=${widths[$i]}
            local val="${cols[$i]}"
            if (( i > 0 && i < last_col && ${#val} > w )); then
                val="${val:0:$((w-3))}..."
            fi
            dr+=" ${colors[$i]}$(printf "%-${w}s" "$val")${NC} │"
        done
        echo -e "$dr"
    done

    echo -e "${BOLD}${bot}${NC}"

    # Write row count to fd 3 if open, otherwise to a temp file
    _table_row_count=${#rows[@]}
}

print_summary() {
    local count="$1"
    local type="$2"
    echo -e "${BLUE}📊 Summary: ${BOLD}${count}${NC} ${BLUE}${type} found${NC}"
}

# Build a jq filter clause for matching multiple package names
# Usage: _build_pkg_filter <field> [pkg1 pkg2 ...]
# Returns: ' and (.name=="pkg1" or .name=="pkg2")' or empty string if no packages
_build_pkg_filter() {
    local field="$1"
    shift
    local pkgs=("$@")
    if [ ${#pkgs[@]} -eq 0 ]; then
        echo ""
        return
    fi
    local filter=""
    for pkg in "${pkgs[@]}"; do
        [ -n "$filter" ] && filter+=" or "
        filter+="${field}==\"${pkg}\""
    done
    echo " and (${filter})"
}

# Resolve display name and json file path based on options
_resolve_paths() {
    if [ -n "$index_image" ]; then
        _display_name="custom-index: $(echo "$index_image" | sed 's/.*\///' | cut -c1-40)..."
        local safe_name=$(echo "$index_image" | sed 's/[:/]/-/g' | sed 's/@/-/g')
        _json_file="/tmp/custom-index-${safe_name}.json"
    elif [[ "$version" == sha256:* ]]; then
        _display_name="${catalog}@${version:0:19}..."
        local cache_suffix=$(echo "$version" | sed 's/[:/]/-/g')
        _json_file="/tmp/${catalog}-${cache_suffix}.json"
    else
        _display_name="${catalog}-${version}"
        _json_file="/tmp/${catalog}-${version}.json"
    fi
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
        #if modified more than 1200 minutes ago, re-render
        if [[ "$(uname)" == "Darwin" ]]; then
            file_mtime=$(stat -f %m "$json_file")
            threshold=$(date -v-1200M +%s)
        else
            file_mtime=$(stat -c %Y "$json_file")
            threshold=$(date -d "1200 minutes ago" +%s)
        fi
        if [ "$file_mtime" -lt "$threshold" ]; then
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
    _resolve_paths
    print_header "OpenShift Operator Packages (${_display_name})" "📦"

    local pkg_filter=$(_build_pkg_filter ".name" "${packages[@]}")
    local data
    data=$(jq -cr 'select(.schema=="olm.package"'"$pkg_filter"')|[.name,.defaultChannel]|@tsv' "$_json_file")

    if [ -n "$limit" ]; then
        render_table "Package Name" "Default Channel" < <(echo "$data" | head -n "$limit")
    else
        render_table "Package Name" "Default Channel" <<< "$data"
    fi
    print_summary "$_table_row_count" "packages"
    echo
}

channels() {
    _resolve_paths
    print_header "OpenShift Operator Channels (${_display_name})" "📺"

    local pkg_filter=$(_build_pkg_filter ".package" "${packages[@]}")
    local data
    data=$(jq -cr 'select(.schema=="olm.channel"'"$pkg_filter"')|[.package,.name]|@tsv' "$_json_file")

    if [ -n "$limit" ]; then
        render_table "Package Name" "Channel" < <(echo "$data" | head -n "$limit")
    else
        render_table "Package Name" "Channel" <<< "$data"
    fi
    print_summary "$_table_row_count" "channels"
    echo
}

# Helper: output TSV "package\tchannels\tbundle" by joining olm.channel + olm.bundle
# Usage: _versions_with_channels <json_file> [packages...]
_versions_with_channels() {
    local _jf="$1"
    shift
    local _filter=$(_build_pkg_filter ".package" "$@")

    {
        jq -cr 'select(.schema=="olm.channel"'"$_filter"') | .package as $p | .name as $c | .entries[] | "C\t" + $p + "/" + .name + "\t" + $c' "$_jf"
        jq -cr 'select(.schema=="olm.bundle"'"$_filter"') | "B\t" + .package + "/" + .name + "\t" + .package + "\t" + .name' "$_jf"
    } | awk -F'\t' '
        $1=="C" { if (ch[$2]) ch[$2]=ch[$2]","$3; else ch[$2]=$3 }
        $1=="B" { print $3 "\t" ch[$2] "\t" $4 }
    '
}

# Helper: output TSV "package\tversion\tchannels\tbundle" for sort+limit use
# Usage: _versions_with_channels_sortable <json_file> [packages...]
_versions_with_channels_sortable() {
    local _jf="$1"
    shift
    local _filter=$(_build_pkg_filter ".package" "$@")

    {
        jq -cr 'select(.schema=="olm.channel"'"$_filter"') | .name as $c | .entries[] | "C\t" + .name + "\t" + $c' "$_jf"
        jq -cr 'select(.schema=="olm.bundle"'"$_filter"') | "B\t" + .name + "\t" + .package + "\t" + ((.properties // [] | map(select(.type=="olm.package") | .value.version) | .[0]) // (.name | sub("^.*\\.v"; "") | sub("-.*$"; ""))) + "\t" + .name' "$_jf"
    } | awk -F'\t' '
        $1=="C" { if (ch[$2]) ch[$2]=ch[$2]","$3; else ch[$2]=$3 }
        $1=="B" { print $3 "\t" $4 "\t" ch[$2] "\t" $5 }
    '
}

versions() {
    _resolve_paths
    print_header "OpenShift Operator Versions (${_display_name})" "🔢"

    local data=""
    if [ -n "$limit" ]; then
        # With limit: get sortable data in single pass, then per-package top-N via awk
        local sort_pkgs=("${packages[@]}")
        if [ ${#sort_pkgs[@]} -eq 0 ]; then
            sort_pkgs=($(jq -cr 'select(.schema=="olm.bundle")|.package' "$_json_file" | sort -u))
        fi
        data=$(_versions_with_channels_sortable "$_json_file" "${sort_pkgs[@]}" \
            | sort -t $'\t' -k1,1 -k2,2Vr \
            | awk -F'\t' -v lim="$limit" '{ if (count[$1]++ < lim) print $1 "\t" $3 "\t" $4 }')
    else
        data=$(_versions_with_channels "$_json_file" "${packages[@]}")
    fi

    render_table "Package Name" "Channel(s)" "Version/Bundle" <<< "$data"
    print_summary "$_table_row_count" "versions"
    echo
}

hub() {
    # Set packages array with hub packages and call versions function
    packages=("odf-operator" "openshift-gitops-operator" "topology-aware-lifecycle-manager" "local-storage-operator" "cluster-logging" "amq-streams" "amq-streams-console" "advanced-cluster-management" "multicluster-engine")
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
    echo -e "  ${GREEN}-v${NC} <version>   OpenShift version or SHA256 digest (default: 4.20)"
    echo -e "                   Examples: 4.20, sha256:78c4590eaa7a8c75a08ece..."
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
    echo -e "  ${CYAN}$0 packages${NC}                                  # Use defaults (4.20, redhat-operator)"
    echo -e "  ${CYAN}$0 -v 4.17 packages${NC}                         # Different version"
    echo -e "  ${CYAN}$0 -v sha256:78c4590eaa7a... packages${NC}       # Use SHA256 digest"
    echo -e "  ${CYAN}$0 -c certified-operator packages${NC}           # Different catalog"
    echo -e "  ${CYAN}$0 -i registry.example.com/my-catalog:v1.0 packages${NC} # Custom index"
    echo -e "  ${CYAN}$0 -l 5 versions ptp-operator${NC}               # Show 5 versions for ptp-operator"
    echo -e "  ${CYAN}$0 -v 4.20 -c redhat-operator packages ptp-operator cluster-logging${NC}"
    echo -e "  ${CYAN}$0 -c certified-operator packages sriov-fec${NC} # Certified operator"
    echo -e "  ${CYAN}$0 hub${NC}                                       # List all hub operator versions"
    echo -e "  ${CYAN}$0 cloudran${NC}                                  # List all cloudran operator versions"
    echo
    exit 1
fi

_init

$cmd "$@"