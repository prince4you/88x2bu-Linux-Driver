
#!/bin/bash
# =================================================================
# 88x2bu Driver Installation Framework
# 
# Enterprise-grade driver deployment system with:
# - Atomic transaction support
# - Rollback capabilities
# - Comprehensive logging
# - Health validation checks
# - Dependency resolution
# - Failure recovery
#
# Author: Sunil [prince4you]
# Maintainer: Infrastructure Engineering Team
# Repo: https://github.com/morrownr/88x2bu-20210702
# License: MIT
# =================================================================

set -eo pipefail
shopt -s inherit_errexit

# ------- CONFIGURATION MANAGEMENT -------
declare -r SCRIPT_NAME="${0##*/}"
declare -r SCRIPT_VERSION="2.4.1"
declare -r DRIVER_VERSION="20210702"
declare -r REPO_URL="https://github.com/morrownr/88x2bu-20210702.git"
declare -r LOG_FILE="/var/log/88x2bu-installer.log"
declare -r LOCK_FILE="/var/run/88x2bu-installer.lock"
declare -r BACKUP_DIR="/var/lib/88x2bu/backup"
declare -r MODULE_NAME="88x2bu"

# ------- ENTERPRISE LOGGING SYSTEM -------
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' EXIT
exec > >(tee -a "${LOG_FILE}" | logger -t "${SCRIPT_NAME}[$$]" -s 2>/dev/console) 2>&1

# ------- ANSI ESCAPE SEQUENCES -------
declare -A ANSI=(
    [reset]=$'\e[0m'
    [bold]=$'\e[1m'
    [dim]=$'\e[2m'
    [italic]=$'\e[3m'
    [underline]=$'\e[4m'
    [blink]=$'\e[5m'
    [invert]=$'\e[7m'
    [hidden]=$'\e[8m'
    
    [fg_black]=$'\e[30m'
    [fg_red]=$'\e[31m'
    [fg_green]=$'\e[32m'
    [fg_yellow]=$'\e[33m'
    [fg_blue]=$'\e[34m'
    [fg_magenta]=$'\e[35m'
    [fg_cyan]=$'\e[36m'
    [fg_white]=$'\e[37m'
    
    [bg_black]=$'\e[40m'
    [bg_red]=$'\e[41m'
    [bg_green]=$'\e[42m'
    [bg_yellow]=$'\e[43m'
    [bg_blue]=$'\e[44m'
    [bg_magenta]=$'\e[45m'
    [bg_cyan]=$'\e[46m'
    [bg_white]=$'\e[47m'
)

# ------- UNICODE ICONS -------
declare -A ICONS=(
    [success]="✅"
    [error]="❌"
    [warning]="⚠️"
    [info]="ℹ️"
    [progress]="🔄"
    [download]="📥"
    [install]="🔧"
    [cleanup]="🧹"
    [clock]="⏰"
    [disk]="💾"
    [network]="🌐"
    [lock]="🔒"
    [unlock]="🔓"
    [rocket]="🚀"
    [check]="✓"
    [cross]="✗"
)

# ------- LOGGING FUNCTIONS -------
log() {
    local level="$1" message="$2" timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    printf "%s %-8s %s\n" "${timestamp}" "[${level}]" "${message}" | tee -a "${LOG_FILE}" >&3
}

log_info() { log "INFO" "${ANSI[fg_cyan]}${*}${ANSI[reset]}"; }
log_success() { log "SUCCESS" "${ANSI[fg_green]}${*}${ANSI[reset]}"; }
log_warning() { log "WARNING" "${ANSI[fg_yellow]}${*}${ANSI[reset]}"; }
log_error() { log "ERROR" "${ANSI[fg_red]}${*}${ANSI[reset]}"; }
log_debug() { [[ "${DEBUG}" == "true" ]] && log "DEBUG" "${ANSI[fg_magenta]}${*}${ANSI[reset]}"; }

# ------- CONCURRENCY CONTROL -------
acquire_lock() {
    exec 200>"${LOCK_FILE}"
    if flock -n 200; then
        echo "$$" >&200
        log_info "${ICONS[lock]} Acquired exclusive lock"
        return 0
    else
        local pid=$(cat "${LOCK_FILE}")
        log_error "${ICONS[lock]} Installer already running (PID: ${pid})"
        return 1
    fi
}

release_lock() {
    flock -u 200
    rm -f "${LOCK_FILE}"
    log_info "${ICONS[unlock]} Released exclusive lock"
}

# ------- ERROR HANDLING FRAMEWORK -------
declare -a CLEANUP_ACTIONS=()
declare -a ROLLBACK_ACTIONS=()

add_cleanup_action() { CLEANUP_ACTIONS+=("$1"); }
add_rollback_action() { ROLLBACK_ACTIONS+=("$1"); }

execute_cleanup() {
    log_info "${ICONS[cleanup]} Executing cleanup operations"
    for action in "${CLEANUP_ACTIONS[@]}"; do
        eval "${action}" || true
    done
}

execute_rollback() {
    log_info "${ICONS[error]} Initiating rollback procedure"
    for action in "${ROLLBACK_ACTIONS[@]}"; do
        eval "${action}" || true
    done
}

trap_handler() {
    local exit_code=$? line_no=$1
    log_error "Script terminated unexpectedly at line ${line_no} with exit code ${exit_code}"
    execute_rollback
    execute_cleanup
    release_lock
    exit ${exit_code}
}

trap 'trap_handler ${LINENO}' ERR INT TERM
trap 'execute_cleanup; release_lock; exit' EXIT

# ------- VALIDATION FRAMEWORK -------
validate_platform() {
    log_info "Validating platform compatibility"
    
    # Kernel version validation
    local kernel_release=$(uname -r)
    if [[ ! "${kernel_release}" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        log_error "Unsupported kernel version: ${kernel_release}"
        return 1
    fi

    # Architecture validation
    local arch=$(uname -m)
    if [[ ! "${arch}" =~ ^(x86_64|i686|aarch64|armv7l)$ ]]; then
        log_error "Unsupported architecture: ${arch}"
        return 1
    fi

    # Distribution detection
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        log_info "Detected distribution: ${NAME} ${VERSION_ID}"
    fi

    # Secure boot check
    if [[ -d /sys/firmware/efi ]] && command -v mokutil >/dev/null 2>&1; then
        if mokutil --sb-state | grep -q "enabled"; then
            log_warning "Secure Boot is enabled - driver signing may be required"
        fi
    fi

    log_success "Platform validation passed"
}

check_dependencies() {
    log_info "Validating system dependencies"
    
    local -a dependencies=(
        "dkms"
        "git"
        "make"
        "gcc"
        "curl"
        "wget"
        "tar"
        "perl"
        "linux-headers-$(uname -r)"
        "build-essential"
        "libelf-dev"
    )
    
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! dpkg -s "${dep}" >/dev/null 2>&1; then
            missing_deps+=("${dep}")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_info "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y --no-install-recommends "${missing_deps[@]}"
    fi
    
    log_success "All dependencies satisfied"
}

# ------- TRANSACTIONAL OPERATIONS -------
backup_existing_driver() {
    log_info "${ICONS[disk]} Backing up existing driver configuration"
    
    mkdir -p "${BACKUP_DIR}"
    local backup_timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_path="${BACKUP_DIR}/backup-${backup_timestamp}"
    
    mkdir -p "${backup_path}"
    
    # Backup module if exists
    if modinfo "${MODULE_NAME}" >/dev/null 2>&1; then
        local module_path=$(modinfo -n "${MODULE_NAME}" 2>/dev/null || true)
        if [[ -n "${module_path}" && -f "${module_path}" ]]; then
            cp -f "${module_path}" "${backup_path}/"
        fi
    fi
    
    # Backup DKMS configuration if exists
    if dkms status | grep -q "${MODULE_NAME}"; then
        dkms status | grep "${MODULE_NAME}" > "${backup_path}/dkms-status.txt" || true
    fi
    
    # Add rollback action
    add_rollback_action "restore_backup '${backup_path}'"
    
    log_success "Backup completed: ${backup_path}"
}

restore_backup() {
    local backup_path="$1"
    log_info "Restoring from backup: ${backup_path}"
    
    if [[ -f "${backup_path}/${MODULE_NAME}.ko" ]]; then
        sudo cp -f "${backup_path}/${MODULE_NAME}.ko" \
            "/lib/modules/$(uname -r)/updates/dkms/${MODULE_NAME}.ko"
        sudo depmod -a
    fi
    
    log_success "Backup restored successfully"
}

# ------- REPOSITORY MANAGEMENT -------
clone_repository() {
    local repo_dir="$1"
    local max_retries=3
    local retry_count=0
    
    while [[ ${retry_count} -lt ${max_retries} ]]; do
        if git clone --depth 1 --branch master "${REPO_URL}" "${repo_dir}" 2>&1; then
            log_success "${ICONS[download]} Repository cloned successfully"
            return 0
        fi
        
        ((retry_count++))
        log_warning "Clone attempt ${retry_count}/${max_retries} failed"
        sleep $((retry_count * 2))
    done
    
    log_error "Failed to clone repository after ${max_retries} attempts"
    return 1
}

# ------- DRIVER COMPILATION & INSTALLATION -------
compile_driver() {
    local source_dir="$1"
    
    log_info "${ICONS[progress]} Compiling driver module"
    
    pushd "${source_dir}" >/dev/null
    add_cleanup_action "popd >/dev/null 2>&1 || true"
    
    # Validate source structure
    if [[ ! -f "Makefile" ]]; then
        log_error "Source validation failed: Makefile not found"
        return 1
    fi
    
    # Execute compilation
    if make -j"$(nproc)" 2>&1; then
        log_success "Driver compilation completed"
    else
        log_error "Driver compilation failed"
        return 1
    fi
    
    popd >/dev/null
}

install_driver() {
    local source_dir="$1"
    
    log_info "${ICONS[install]} Installing driver module"
    
    pushd "${source_dir}" >/dev/null
    add_cleanup_action "popd >/dev/null 2>&1 || true"
    
    # DKMS installation path
    if [[ -f "dkms.conf" ]]; then
        if sudo make dkmsinstall 2>&1; then
            log_success "DKMS installation completed"
        else
            log_error "DKMS installation failed"
            return 1
        fi
    else
        # Manual installation
        if sudo make install 2>&1; then
            log_success "Manual installation completed"
        else
            log_error "Manual installation failed"
            return 1
        fi
    fi
    
    # Update initramfs
    if command -v update-initramfs >/dev/null 2>&1; then
        sudo update-initramfs -u -k all
    fi
    
    popd >/dev/null
}

# ------- SYSTEM INTEGRATION -------
load_driver_module() {
    log_info "Loading driver module into kernel"
    
    # Unload existing module if loaded
    if grep -q "${MODULE_NAME}" /proc/modules; then
        sudo modprobe -r "${MODULE_NAME}" || true
    fi
    
    # Load new module
    if sudo modprobe "${MODULE_NAME}" 2>&1; then
        log_success "Driver module loaded successfully"
    else
        log_error "Failed to load driver module"
        return 1
    fi
}

validate_driver_operation() {
    log_info "Validating driver operation"
    
    local validation_passed=true
    
    # Module existence check
    if ! modinfo "${MODULE_NAME}" >/dev/null 2>&1; then
        log_error "Module not found in system"
        validation_passed=false
    fi
    
    # Module loading check
    if ! grep -q "${MODULE_NAME}" /proc/modules; then
        log_error "Module not loaded into kernel"
        validation_passed=false
    fi
    
    # Interface detection
    local interface_count=$(ls /sys/class/net/ | wc -l)
    if [[ ${interface_count} -eq 0 ]]; then
        log_warning "No network interfaces detected"
    fi
    
    if [[ "${validation_passed}" == "true" ]]; then
        log_success "Driver validation completed successfully"
    else
        log_error "Driver validation failed"
        return 1
    fi
}

# ------- MAIN EXECUTION FLOW -------
main() {
    local temp_dir=$(mktemp -d "/tmp/88x2bu-installer.XXXXXX")
    add_cleanup_action "rm -rf '${temp_dir}'"
    
    # Display banner
    echo -e "${ANSI[bg_blue]}${ANSI[bold]}${ANSI[fg_white]}"
    echo "=================================================================="
    echo "          88x2bu ENTERPRISE DRIVER DEPLOYMENT SYSTEM"
    echo "=================================================================="
    echo -e "Version: ${SCRIPT_VERSION} | Driver: ${DRIVER_VERSION} | Kernel: $(uname -r)${ANSI[reset]}"
    echo -e "${ANSI[dim]}Start Time: $(date '+%Y-%m-%d %H:%M:%S %Z')${ANSI[reset]}"
    echo -e "${ANSI[dim]}Log File: ${LOG_FILE}${ANSI[reset]}"
    echo -e "${ANSI[bg_blue]}${ANSI[fg_white]}==================================================================${ANSI[reset]}\n"
    
    # Acquire exclusive lock
    acquire_lock
    
    # Validation phase
    validate_platform
    check_dependencies
    backup_existing_driver
    
    # Deployment phase
    clone_repository "${temp_dir}/88x2bu-${DRIVER_VERSION}"
    compile_driver "${temp_dir}/88x2bu-${DRIVER_VERSION}"
    install_driver "${temp_dir}/88x2bu-${DRIVER_VERSION}"
    load_driver_module
    validate_driver_operation
    
    # Success notification
    echo -e "\n${ANSI[bg_green]}${ANSI[bold]}${ANSI[fg_white]}"
    echo "=================================================================="
    echo "  DRIVER DEPLOYMENT COMPLETED SUCCESSFULLY"
    echo "=================================================================="
    echo -e "${ANSI[reset]}"
    echo -e "${ICONS[success]} ${ANSI[bold]}${ANSI[fg_green]}Installation completed without errors${ANSI[reset]}"
    echo -e "${ICONS[rocket]} ${ANSI[dim]}System restart recommended for full integration${ANSI[reset]}"
    
    log_success "Deployment completed successfully"
}

# ------- EXECUTION GUARD -------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Argument parsing
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--debug)
                DEBUG="true"
                set -x
                shift
                ;;
            -v|--version)
                echo "${SCRIPT_NAME} v${SCRIPT_VERSION}"
                exit 0
                ;;
            -h|--help)
                echo "Usage: ${SCRIPT_NAME} [OPTIONS]"
                echo "Options:"
                echo "  -d, --debug    Enable debug mode"
                echo "  -v, --version  Show version information"
                echo "  -h, --help     Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Execution entry point
    main "$@"
fi
