# OpenShift Operator Catalog Tool

A comprehensive command-line tool for exploring OpenShift operator catalogs with professional formatting and advanced features. Fully tested and production-ready.

## 🌟 Features

- 📦 **List operator packages** and their default channels
- 📺 **Browse available channels** for each operator
- 🔢 **View all versions/bundles** available for operators
- 🏢 **Pre-configured hub collections** - Hub cluster operator sets
- 📡 **Pre-configured cloudran collections** - CloudRAN/Telco operator sets
- 🎨 **Beautiful Unicode table formatting** with colors and borders
- 📊 **Summary statistics** showing count of results
- 🚀 **Intelligent 20-hour caching** - Smart cache management with auto-refresh
- 🔒 **SHA256 digest support** - Immutable catalog references
- 🌐 **Custom index images** - Support for private/custom registries
- ⚡ **Result limiting** - Configurable output limits for performance
- 🛡️ **Robust error handling** - Comprehensive validation and error messages
- 🧪 **Comprehensive testing** - Full test suite with quality assurance

## Usage

```bash
./oc-catalog.sh [options] <command> [packages...]
```

### Options

- **-v** `<version>` - OpenShift version or SHA256 digest (default: 4.18)
  - Version tag: `4.18`, `4.17`, etc.
  - SHA256 digest: `sha256:6462dd0a33055240e169044356899aaa...`
- **-c** `<catalog>` - Catalog name (default: redhat-operator)
  - Valid options: `redhat-operator`, `certified-operator`, `community-operator`, `redhat-marketplace`
- **-i** `<image>` - Custom catalog index image (overrides -v and -c)
  - Example: `registry.example.com/my-catalog:latest`
- **-l** `<limit>` - Limit number of results (default: no limit)
  - For packages/channels: limits total results
  - For versions/hub/cloudran: limits versions per package
- **-h** - Show help message

### Commands

- **packages** - List operator packages and their default channels
- **channels** - List all available channels for packages
- **versions** - List all available versions/bundles for packages
- **hub** - List versions for pre-configured hub operator collection
- **cloudran** - List versions for pre-configured cloudran operator collection

### Package Arguments

- **packages...** - Optional: specific package names to filter results
- If no packages provided, all packages will be listed
- Not used with `hub` or `cloudran` commands (they have pre-configured package sets)

## 🏗️ Supported Catalogs

The tool supports these Red Hat operator catalogs:

| Catalog | Description | Example Usage |
|---------|-------------|---------------|
| `redhat-operator` | Red Hat certified operators (default) | `-c redhat-operator` |
| `certified-operator` | Partner certified operators | `-c certified-operator` |
| `community-operator` | Community operators | `-c community-operator` |
| `redhat-marketplace` | Red Hat Marketplace operators | `-c redhat-marketplace` |

## 🔧 Catalog Source Options

The tool supports three ways to specify catalog sources:

1. **Standard Red Hat Catalogs** (using `-v` and `-c`)
2. **SHA256 Digests** (for immutable references)
3. **Custom Index Images** (using `-i` for any registry)

## SHA256 Digest Support

The tool supports both version tags and SHA256 digests for precise catalog targeting:

### Version Tags (Mutable)
- **Format**: `4.18`, `4.17`, etc.
- **Image Reference**: `registry.redhat.io/redhat/redhat-operator-index:v4.18`
- **Use Case**: Latest updates for a specific OpenShift version

### SHA256 Digests (Immutable)
- **Format**: `sha256:6462dd0a33055240e169044356899aaa...`
- **Image Reference**: `registry.redhat.io/redhat/redhat-operator-index@sha256:6462dd0a...`
- **Use Case**: Reproducible builds, pinning to exact catalog snapshots

**Benefits of SHA256 Digests:**
- 🔒 **Immutable references** - Content never changes
- 🔄 **Reproducible builds** - Same results every time
- 📋 **Audit trails** - Exact catalog version tracking
- 🎯 **Precise targeting** - Reference specific catalog snapshots

### Custom Index Images
- **Format**: Any valid container image reference
- **Image Reference**: User-specified (e.g., `registry.example.com/my-catalog:latest`)
- **Use Case**: Private catalogs, custom operator collections, development/testing

**Benefits of Custom Index Images:**
- 🏢 **Private registries** - Use internal/private operator catalogs
- 🧪 **Development/Testing** - Point to custom-built catalog images
- 🔧 **Custom collections** - Curated operator sets for specific environments
- 🌐 **Third-party catalogs** - Access non-Red Hat operator repositories

## 🎯 Pre-configured Collections

The tool includes two pre-configured operator collections for common deployment scenarios:

### Hub Cluster Operators (`hub` command)
Pre-configured collection for ACM Hub cluster deployments:
- `odf-operator` - OpenShift Data Foundation
- `openshift-gitops-operator` - OpenShift GitOps (ArgoCD)
- `topology-aware-lifecycle-manager` - TALM for cluster lifecycle management
- `local-storage-operator` - Local Storage Operator
- `cluster-logging` - OpenShift Logging
- `amq-streams` - Apache Kafka (AMQ Streams)
- `amq-streams-console` - Kafka Console UI
- `advanced-cluster-management` - Red Hat Advanced Cluster Management

### CloudRAN/Telco Operators (`cloudran` command)
Pre-configured collection for CloudRAN and Telco workloads:
- `ptp-operator` - Precision Time Protocol
- `sriov-network-operator` - SR-IOV Network Operator
- `local-storage-operator` - Local Storage Operator
- `cluster-logging` - OpenShift Logging
- `lifecycle-agent` - Lifecycle Agent for SNO upgrades
- `redhat-oadp-operator` - OADP Backup and Restore

**Usage:**
```bash
# List all hub operator versions
./oc-catalog.sh hub

# List all cloudran operator versions
./oc-catalog.sh cloudran

# Limit results for performance
./oc-catalog.sh -l 3 hub
```

## Commands

### List Packages
Show operator packages and their default channels:

```bash
# List all packages (using defaults: 4.18, redhat-operator)
./oc-catalog.sh packages

# List specific packages
./oc-catalog.sh packages ptp-operator cluster-logging

# Use different catalog
./oc-catalog.sh -c certified-operator packages

# Use custom index image
./oc-catalog.sh -i registry.example.com/my-catalog:v1.0 packages

# Limit results for performance
./oc-catalog.sh -l 10 packages

# Different version with specific packages
./oc-catalog.sh -v 4.17 packages sriov-network-operator ptp-operator
```

**Output:**
```
📦 OpenShift Operator Packages (redhat-operator-4.18)
==================================================
┌─────────────────────────────────────────────────────────┬────────────────────────────────┐
│ Package Name                                            │ Default Channel                │
├─────────────────────────────────────────────────────────┼────────────────────────────────┤
│ ptp-operator                                            │ stable                         │
│ cluster-logging                                         │ stable-6.3                     │
└─────────────────────────────────────────────────────────┴────────────────────────────────┘
📊 Summary: 2 packages found
```

### List Channels
Show all available channels for operators:

```bash
# List all channels (using defaults)
./oc-catalog.sh channels

# List channels for specific packages
./oc-catalog.sh channels ptp-operator sriov-network-operator

# Use different version
./oc-catalog.sh -v 4.17 channels cluster-logging

# Limit results for performance
./oc-catalog.sh -l 15 channels

# Use SHA256 digest for specific catalog snapshot
./oc-catalog.sh -v sha256:6462dd0a33055240e169044356899aaa76696fe8e58a51c95b42f0012ba6a1f7 channels cluster-logging

# Use custom index image
./oc-catalog.sh -i registry.example.com/my-catalog:latest channels cluster-logging

# Different catalog with channels
./oc-catalog.sh -c certified-operator channels sriov-fec
```

**Output:**
```
📺 OpenShift Operator Channels (redhat-operator-4.18)
==================================================
┌─────────────────────────────────────────────────────────┬───────────────────────────────────┐
│ Package Name                                            │ Channel                           │
├─────────────────────────────────────────────────────────┼───────────────────────────────────┤
│ cluster-logging                                         │ stable-6.1                        │
│ cluster-logging                                         │ stable-6.2                        │
│ cluster-logging                                         │ stable-6.3                        │
└─────────────────────────────────────────────────────────┴───────────────────────────────────┘
📊 Summary: 3 channels found
```

### List Versions
Show all available versions/bundles for operators:

```bash
# List all versions (using defaults)
./oc-catalog.sh versions

# List versions for specific packages  
./oc-catalog.sh versions ptp-operator cluster-logging

# Use different catalog and version
./oc-catalog.sh -v 4.17 -c redhat-operator versions ptp-operator

# Limit versions per package for performance
./oc-catalog.sh -l 5 versions ptp-operator

# Different version with SHA256 digest
./oc-catalog.sh -v sha256:78c4590eaa7a8c75... versions cluster-logging

# Custom catalog with version limiting
./oc-catalog.sh -i registry.example.com/my-catalog:latest -l 3 versions

# Use SHA256 digest for precise catalog targeting
./oc-catalog.sh -v sha256:6462dd0a33055240e169044356899aaa76696fe8e58a51c95b42f0012ba6a1f7 versions ptp-operator

# Use custom index image
./oc-catalog.sh -i registry.example.com/my-operators:v2.0 versions ptp-operator
```

**Output:**
```
🔢 OpenShift Operator Versions (redhat-operator-4.18)
==================================================
┌─────────────────────────────────────────────────────────┬───────────────────────────────────────────────┐
│ Package Name                                            │ Version/Bundle                                │
├─────────────────────────────────────────────────────────┼───────────────────────────────────────────────┤
│ ptp-operator                                            │ ptp-operator.v4.18.0-202501230001             │
│ ptp-operator                                            │ ptp-operator.v4.18.0-202502250302             │
│ ptp-operator                                            │ ptp-operator.v4.18.0-202503121135             │
│ ptp-operator                                            │ ptp-operator.v4.18.0-202503211332             │
│ ptp-operator                                            │ ptp-operator.v4.18.0-202504021503             │
└─────────────────────────────────────────────────────────┴───────────────────────────────────────────────┘
📊 Summary: 5 versions found
```

**SHA256 Digest Example:**
```bash
# Using SHA256 digest shows different header format
./oc-catalog.sh -v sha256:6462dd0a33055240e169044356899aaa76696fe8e58a51c95b42f0012ba6a1f7 versions ptp-operator
```

**Output:**
```
🔢 OpenShift Operator Versions (redhat-operator@sha256:6462dd0a...)
==================================================
┌─────────────────────────────────────────────────────────┬───────────────────────────────────────────────┐
│ Package Name                                            │ Version/Bundle                                │
├─────────────────────────────────────────────────────────┼───────────────────────────────────────────────┤
│ ptp-operator                                            │ ptp-operator.v4.14.0-202310201027             │
│ ptp-operator                                            │ ptp-operator.v4.14.0-202311021650             │
│ ptp-operator                                            │ ptp-operator.v4.14.0-202311092032             │
│ ptp-operator                                            │ ptp-operator.v4.14.0-202311211133             │
│ ptp-operator                                            │ ptp-operator.v4.14.0-202312052033             │
└─────────────────────────────────────────────────────────┴───────────────────────────────────────────────┘
📊 Summary: 31 versions found
```

**Certified Operator Example:**
```bash
# List versions for certified operator
./oc-catalog.sh -c certified-operator versions sriov-fec
```

**Output:**
```
🔢 OpenShift Operator Versions (certified-operator-4.18)
==================================================
┌─────────────────────────────────────────────────────────┬───────────────────────────────────────────────┐
│ Package Name                                            │ Version/Bundle                                │
├─────────────────────────────────────────────────────────┼───────────────────────────────────────────────┤
│ sriov-fec                                               │ sriov-fec.v2.10.0                             │
│ sriov-fec                                               │ sriov-fec.v2.11.0                             │
│ sriov-fec                                               │ sriov-fec.v2.11.1                             │
│ sriov-fec                                               │ sriov-fec.v2.7.1                              │
│ sriov-fec                                               │ sriov-fec.v2.7.2                              │
│ sriov-fec                                               │ sriov-fec.v2.8.0                              │
│ sriov-fec                                               │ sriov-fec.v2.9.0                              │
└─────────────────────────────────────────────────────────┴───────────────────────────────────────────────┘
📊 Summary: 7 versions found
```

### List Hub Operator Versions
Show available versions for common hub operators:

```bash
# List versions for all hub operators
./oc-catalog.sh hub

# Use different version
./oc-catalog.sh -v 4.17 hub

# Use SHA256 digest
./oc-catalog.sh -v sha256:6462dd0a33055240e169044356899aaa76696fe8e58a51c95b42f0012ba6a1f7 hub
```

**Output:**
```
🔢 OpenShift Operator Versions (redhat-operator-4.18)
==================================================
┌─────────────────────────────────────────────────────────┬───────────────────────────────────────────────┐
│ Package Name                                            │ Version/Bundle                                │
├─────────────────────────────────────────────────────────┼───────────────────────────────────────────────┤
│ odf-operator                                            │ odf-operator.v4.18.0-202501230001             │
│ openshift-gitops-operator                               │ openshift-gitops-operator.v1.15.1             │
│ topology-aware-lifecycle-manager                        │ topology-aware-lifecycle-manager.v4.18.0      │
│ local-storage-operator                                  │ local-storage-operator.v4.18.0-202501230001   │
│ cluster-logging                                         │ cluster-logging.v6.3.0-202501230001           │
│ amq-streams                                             │ amq-streams.v2.9.0-0                          │
│ amq-streams-console                                     │ amq-streams-console.v0.1.0                    │
│ advanced-cluster-management                             │ advanced-cluster-management.v2.12.0            │
└─────────────────────────────────────────────────────────┴───────────────────────────────────────────────┘
📊 Summary: 8 versions found
```

**Hub Operators Included:**
- `odf-operator` - OpenShift Data Foundation
- `openshift-gitops-operator` - OpenShift GitOps (ArgoCD)
- `topology-aware-lifecycle-manager` - Topology Aware Lifecycle Manager
- `local-storage-operator` - Local Storage Operator
- `cluster-logging` - Cluster Logging
- `amq-streams` - AMQ Streams (Kafka)
- `amq-streams-console` - AMQ Streams Console
- `advanced-cluster-management` - Advanced Cluster Management

### List CloudRAN Operator Versions
Show available versions for common CloudRAN operators:

```bash
# List versions for all CloudRAN operators
./oc-catalog.sh cloudran

# Use different version
./oc-catalog.sh -v 4.17 cloudran

# Use SHA256 digest
./oc-catalog.sh -v sha256:6462dd0a33055240e169044356899aaa76696fe8e58a51c95b42f0012ba6a1f7 cloudran
```

**Output:**
```
🔢 OpenShift Operator Versions (redhat-operator-4.18)
==================================================
┌─────────────────────────────────────────────────────────┬───────────────────────────────────────────────┐
│ Package Name                                            │ Version/Bundle                                │
├─────────────────────────────────────────────────────────┼───────────────────────────────────────────────┤
│ ptp-operator                                            │ ptp-operator.v4.18.0-202501230001             │
│ sriov-network-operator                                  │ sriov-network-operator.v4.18.0-202501230001   │
│ local-storage-operator                                  │ local-storage-operator.v4.18.0-202501230001   │
│ cluster-logging                                         │ cluster-logging.v6.3.0-202501230001           │
│ lifecycle-agent                                         │ lifecycle-agent.v4.18.0-202501230001          │
│ redhat-oadp-operator                                    │ redhat-oadp-operator.v1.5.0                   │
└─────────────────────────────────────────────────────────┴───────────────────────────────────────────────┘
📊 Summary: 6 versions found
```

**CloudRAN Operators Included:**
- `ptp-operator` - Precision Time Protocol Operator
- `sriov-network-operator` - SR-IOV Network Operator
- `local-storage-operator` - Local Storage Operator
- `cluster-logging` - Cluster Logging
- `lifecycle-agent` - Lifecycle Agent
- `redhat-oadp-operator` - OADP (OpenShift API for Data Protection) Operator

**Custom Index Image Example:**
```bash
# Using custom index image shows different header format
./oc-catalog.sh -i registry.example.com/my-catalog:v1.0 packages ptp-operator
```

**Output:**
```
📦 OpenShift Operator Packages (custom-index: my-catalog:v1.0...)
==================================================
┌─────────────────────────────────────────────────────────┬────────────────────────────────┐
│ Package Name                                            │ Default Channel                │
├─────────────────────────────────────────────────────────┼────────────────────────────────┤
│ ptp-operator                                            │ stable                         │
│ custom-operator                                         │ alpha                          │
└─────────────────────────────────────────────────────────┴────────────────────────────────┘
📊 Summary: 2 packages found
```

## Examples

```bash
# Get help
./oc-catalog.sh -h

# List all packages (using defaults: 4.18, redhat-operator)
./oc-catalog.sh packages

# Check specific operators
./oc-catalog.sh packages ptp-operator cluster-logging

# View channels for cluster logging
./oc-catalog.sh channels cluster-logging

# See all versions of PTP operator
./oc-catalog.sh versions ptp-operator

# Work with different OpenShift version
./oc-catalog.sh -v 4.17 packages

# Use certified operator catalog
./oc-catalog.sh -c certified-operator packages

# Check certified operator (e.g., SR-IOV FEC operator)
./oc-catalog.sh -c certified-operator packages sriov-fec

# Combine options
./oc-catalog.sh -v 4.17 -c certified-operator versions sriov-fec

# Use SHA256 digest for reproducible builds
./oc-catalog.sh -v sha256:6462dd0a33055240e169044356899aaa76696fe8e58a51c95b42f0012ba6a1f7 packages ptp-operator

# Use custom index image for private registry
./oc-catalog.sh -i registry.example.com/my-catalog:v1.0 packages ptp-operator

# Use development catalog
./oc-catalog.sh -i localhost:5000/dev-catalog:latest packages

# List all hub operator versions (predefined set)
./oc-catalog.sh hub

# List all CloudRAN operator versions (predefined set)  
./oc-catalog.sh cloudran

# Use different version with hub operators
./oc-catalog.sh -v 4.17 hub

# Use SHA256 digest with CloudRAN operators
./oc-catalog.sh -v sha256:6462dd0a33055240e169044356899aaa76696fe8e58a51c95b42f0012ba6a1f7 cloudran

# Catalog validation example (will show error)
./oc-catalog.sh -c invalid-catalog packages
# Output: Error: Invalid catalog 'invalid-catalog'
#         Valid catalogs are: redhat-operator certified-operator community-operator redhat-marketplace
```

## Help Output

Running the script with `-h` or no arguments shows the complete help message:

```bash
./oc-catalog.sh -h
```

**Output:**
```
🚀 OpenShift Operator Catalog Tool
==================================================
Usage: ./oc-catalog.sh [options] <command> [packages...]

Options:
  -v <version>   OpenShift version or SHA256 digest (default: 4.18)
                   Examples: 4.18, sha256:78c4590eaa7a8c75a08ece...
  -c <catalog>   Catalog name (default: redhat-operator)
  -i <image>     Custom catalog index image (overrides -v and -c)
                   Example: registry.example.com/my-catalog:latest
  -h             Show this help message

Commands:
  📦 packages  - List operator packages and their default channels
  📺 channels  - List all available channels for packages
  🔢 versions  - List all available versions/bundles for packages
  🏢 hub       - List available versions for hub packages
  📡 cloudran  - List available versions for cloudran packages

Package Arguments:
  • Specify one or more package names to filter results
  • If no packages provided, all packages will be listed

Examples:
  ./oc-catalog.sh packages                                  # Use defaults (4.18, redhat-operator)
  ./oc-catalog.sh -v 4.17 packages                         # Different version
  ./oc-catalog.sh -v sha256:78c4590eaa7a... packages       # Use SHA256 digest
  ./oc-catalog.sh -c certified-operator packages           # Different catalog
  ./oc-catalog.sh -i registry.example.com/my-catalog:v1.0 packages # Custom index
  ./oc-catalog.sh -v 4.18 -c redhat-operator packages ptp-operator cluster-logging
  ./oc-catalog.sh -c certified-operator packages sriov-fec # Certified operator
  ./oc-catalog.sh hub                                       # List all hub operator versions
  ./oc-catalog.sh cloudran                                  # List all cloudran operator versions
```

## Requirements

- `opm` tool installed and available in PATH
- `jq` for JSON processing
- Bash shell environment
- Internet connectivity to download catalog data

## Installation

1. Make the script executable:
   ```bash
   chmod +x oc-catalog.sh
   ```

2. Run the script:
   ```bash
   ./oc-catalog.sh
   ```

## Caching

The tool automatically caches catalog data in `/tmp/` and refreshes it every 20 hours to balance performance with data freshness.

Cache files are named: 
- Standard catalogs: `/tmp/{catalog}-{version}.json`
- Custom index images: `/tmp/custom-index-{safe-name}.json`

## Supported Catalogs

The script validates catalog names and only accepts the following supported catalogs:

- `redhat-operator` - Red Hat certified operators
- `certified-operator` - Third-party certified operators  
- `community-operator` - Community operators
- `redhat-marketplace` - Red Hat Marketplace operators

**Validation:** If you specify an invalid catalog name, the script will display an error message with the list of valid catalogs and exit.

---


*Built with ❤️ for OpenShift operators exploration* 

**Status**: ✅ Production Ready | **Version**: Latest | **Tested**: Comprehensive
