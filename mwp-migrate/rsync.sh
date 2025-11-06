#!/bin/bash
# Rsync website + migration directories with timing (1:1 mirror for migration)

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# =====================================
# -- Default Settings
# =====================================
SSH_PORT="22"
SSH_KEY="$HOME/.ssh/id_rsa"
SRC_PATH=""
DEST_PATH=""

# -- Check if rsync.conf exists and source it
if [[ -f "$SCRIPT_DIR/rsync.conf" ]]; then
    source "$SCRIPT_DIR/rsync.conf"
fi

# =====================================
# -- Parse command line arguments
# =====================================
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -s, --source PATH      Source path (local dir or user@host:/path)
    -d, --dest PATH        Destination path (local dir or user@host:/path)
    -p, --port PORT        SSH port (default: 22)
    -k, --key PATH         SSH key path (default: ~/.ssh/id_rsa)
    -h, --help             Show this help message

Examples:
    # Remote to local
    $(basename "$0") -s user@host.com:/var/www/site -d /local/backup
    
    # Local to remote
    $(basename "$0") -s /var/www/site -d user@host.com:/home/user/site
    
    # Remote to remote
    $(basename "$0") -s user1@host1.com:/src/dir -d user2@host2.com:/dst/dir
    
    # Local to local
    $(basename "$0") -s /source/path -d /dest/path
    
    # With custom SSH settings
    $(basename "$0") -s user@host:/path -d /local -p 2222 -k ~/.ssh/custom_key

Note: All settings can be defined in rsync.conf in the same directory.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--source)
            SRC_PATH="$2"
            shift 2
            ;;
        -d|--dest)
            DEST_PATH="$2"
            shift 2
            ;;
        -p|--port)
            SSH_PORT="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            ;;
    esac
done

# =====================================
# -- Validate required parameters
# =====================================
if [[ -z "$SRC_PATH" ]]; then
    echo "❌ Error: Source path is required."
    echo "   Set it via -s/--source flag or in rsync.conf"
    exit 1
fi

if [[ -z "$DEST_PATH" ]]; then
    echo "❌ Error: Destination path is required."
    echo "   Set it via -d/--dest flag or in rsync.conf"
    exit 1
fi

# Check if source is local and validate it exists
if [[ ! "$SRC_PATH" =~ .*@.*:.* ]]; then
    if [[ ! -d "$SRC_PATH" ]]; then
        echo "❌ Error: Local source directory does not exist: $SRC_PATH"
        exit 1
    fi
fi

# Determine if we need SSH (either source or dest is remote)
USE_SSH="0"
if [[ "$SRC_PATH" =~ .*@.*:.* ]] || [[ "$DEST_PATH" =~ .*@.*:.* ]]; then
    USE_SSH="1"
    if [[ ! -f "$SSH_KEY" ]]; then
        echo "❌ Error: SSH key not found: $SSH_KEY"
        echo "   Remote transfers require a valid SSH key."
        exit 1
    fi
fi

SSH_OPTS="-p $SSH_PORT -i $SSH_KEY"

start_all=$(date +%s)

echo "🚀 Starting rsync migration at $(date)"
echo "📂 Source: $SRC_PATH"
echo "📁 Destination: $DEST_PATH"
if [[ "$USE_SSH" == "1" ]]; then
    echo "🔐 Using SSH (port: $SSH_PORT, key: $SSH_KEY)"
else
    echo "💻 Local-to-local sync (no SSH)"
fi
echo ""

# Function for timing
run_timed() {
    local desc=$1
    shift
    local start
    local end
    start=$(date +%s)
    echo "▶️  $desc..."
    "$@"
    local status=$?
    end=$(date +%s)
    local runtime=$((end - start))
    echo "⏱️  $desc completed in ${runtime}s ($(date -u -d @${runtime} +%H:%M:%S))"
    echo ""
    return $status
}

# Build and execute rsync command
if [[ "$USE_SSH" == "1" ]]; then
    run_timed "Syncing $SRC_PATH to $DEST_PATH" \
        sh -c "rsync -avzP -e 'ssh $SSH_OPTS' '${SRC_PATH}/' '${DEST_PATH}/'"
else
    run_timed "Syncing $SRC_PATH to $DEST_PATH" \
        rsync -avzP "${SRC_PATH}/" "${DEST_PATH}/"
fi

# --- Total runtime ---
end_all=$(date +%s)
total_runtime=$((end_all - start_all))
echo "✅ All rsync tasks completed in ${total_runtime}s ($(date -u -d @${total_runtime} +%H:%M:%S))"