#!/bin/bash

# dysk Installation Script
# Downloads and installs the dysk disk usage utility
# Usage: ./install-dysk.sh [--help] [--target-dir=/custom/path]

set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script configuration
readonly SCRIPT_NAME="$(basename "$0")"
readonly URL="https://dystroy.org/dysk/download/x86_64-linux/dysk"
readonly DEFAULT_TARGET="/usr/local/bin"
readonly TEMP_FILE="/tmp/dysk.$$"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Show usage information
show_help() {
    cat << EOF
$SCRIPT_NAME - Install dysk disk usage utility

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    --target-dir=PATH    Install to custom directory (default: $DEFAULT_TARGET)
    --help, -h          Show this help message

EXAMPLES:
    $SCRIPT_NAME                           # Install to $DEFAULT_TARGET
    $SCRIPT_NAME --target-dir=~/bin        # Install to ~/bin

REQUIREMENTS:
    - curl (for downloading)
    - sudo access (if installing to system directories)

EOF
}

# Clean up temporary files
cleanup() {
    if [[ -f "$TEMP_FILE" ]]; then
        rm -f "$TEMP_FILE"
        log_info "Cleaned up temporary files"
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Parse command line arguments
parse_args() {
    TARGET_DIR="$DEFAULT_TARGET"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --target-dir=*)
                TARGET_DIR="${1#*=}"
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    readonly TARGET_DIR
    readonly TARGET_PATH="$TARGET_DIR/dysk"
}

# Validate system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check if curl is available
    if ! command -v curl >/dev/null 2>&1; then
        log_error "curl is required but not installed"
        log_error "Please install curl: sudo apt-get install curl"
        exit 1
    fi
    
    # Check if target directory exists or can be created
    if [[ ! -d "$TARGET_DIR" ]]; then
        log_warning "Target directory $TARGET_DIR does not exist"
        if [[ "$TARGET_DIR" == "$DEFAULT_TARGET" ]]; then
            log_info "Will attempt to create it (requires sudo)"
        else
            log_error "Please create the directory first: mkdir -p $TARGET_DIR"
            exit 1
        fi
    fi
    
    # Check if we need sudo for the target directory
    if [[ ! -w "$TARGET_DIR" ]] && [[ "$TARGET_DIR" == "$DEFAULT_TARGET" ]]; then
        log_info "Installation to $TARGET_DIR requires sudo privileges"
        if ! sudo -n true 2>/dev/null; then
            log_warning "You may be prompted for your password"
        fi
    fi
}

# Download the binary
download_dysk() {
    log_info "Downloading dysk from $URL..."
    
    if curl -fL --progress-bar "$URL" -o "$TEMP_FILE"; then
        log_success "Download completed"
    else
        log_error "Failed to download dysk"
        exit 1
    fi
    
    # Verify the file was downloaded and is not empty
    if [[ ! -s "$TEMP_FILE" ]]; then
        log_error "Downloaded file is empty or corrupted"
        exit 1
    fi
}

# Install the binary
install_dysk() {
    log_info "Installing dysk to $TARGET_PATH..."
    
    # Make the binary executable
    chmod +x "$TEMP_FILE"
    
    # Check if we already have dysk installed
    if [[ -f "$TARGET_PATH" ]]; then
        log_warning "dysk is already installed at $TARGET_PATH"
        read -p "Do you want to overwrite it? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi
    
    # Install the binary
    if [[ -w "$TARGET_DIR" ]]; then
        # We can write directly
        mv "$TEMP_FILE" "$TARGET_PATH"
    else
        # Need sudo
        sudo mkdir -p "$TARGET_DIR"
        sudo mv "$TEMP_FILE" "$TARGET_PATH"
        sudo chown root:root "$TARGET_PATH"
    fi
    
    log_success "dysk installed successfully to $TARGET_PATH"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    if [[ -x "$TARGET_PATH" ]]; then
        local version
        if version=$("$TARGET_PATH" --version 2>/dev/null); then
            log_success "Installation verified: $version"
        else
            log_success "dysk is installed and executable"
        fi
        
        # Check if it's in PATH
        if command -v dysk >/dev/null 2>&1; then
            log_info "dysk is available in your PATH"
        else
            log_warning "dysk is not in your PATH"
            log_info "You may need to add $TARGET_DIR to your PATH or use the full path: $TARGET_PATH"
        fi
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

# Main function
main() {
    log_info "Starting dysk installation..."
    
    parse_args "$@"
    check_requirements
    download_dysk
    install_dysk
    verify_installation
    
    log_success "Installation completed successfully!"
    log_info "You can now use: dysk --help"
}

# Run main function with all arguments
main "$@"
