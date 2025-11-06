#!/bin/bash
# Super-fast WordPress DB dump using mydumper (timed version)

TIMESTAMP=$(date +%F_%H-%M)
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# =====================================
# -- Default Settings
# =====================================
OUTDIR="$HOME/migration/wpdb-export"
DB_NAME=""
DB_USER=""
DB_PASS=""
TABLES_LIST=""

# -- Check if mydumper.conf exists and source it
if [[ -f "$SCRIPT_DIR/mydumper.conf" ]]; then
    source "$SCRIPT_DIR/mydumper.conf"
fi

# =====================================
# -- Parse command line arguments
# =====================================
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -o, --output DIR       Output directory for the dump
    -d, --database NAME    Database name
    -u, --user USER        Database user
    -t, --tables TABLES    Comma-separated list of tables to export (optional)
    -h, --help             Show this help message

Examples:
    $(basename "$0") -o /path/to/backup -d mydb -u dbuser
    $(basename "$0") --output ./backup --database wordpress --user root
    $(basename "$0") -d wordpress -u root -t "wp_posts,wp_postmeta,wp_users"

Note: If database password is not set in mydumper.conf, you will be prompted to enter it.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTDIR="$2"
            shift 2
            ;;
        -d|--database)
            DB_NAME="$2"
            shift 2
            ;;
        -u|--user)
            DB_USER="$2"
            shift 2
            ;;
        -t|--tables)
            TABLES_LIST="$2"
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
if [[ -z "$DB_NAME" ]]; then
    echo "❌ Error: Database name is required."
    echo "   Set it via -d/--database flag or in mydumper.conf"
    exit 1
fi

if [[ -z "$DB_USER" ]]; then
    echo "❌ Error: Database user is required."
    echo "   Set it via -u/--user flag or in mydumper.conf"
    exit 1
fi

# Prompt for password if not set
if [[ -z "$DB_PASS" ]]; then
    echo -n "Enter database password for user '$DB_USER': "
    read -s DB_PASS
    echo ""
    if [[ -z "$DB_PASS" ]]; then
        echo "❌ Error: Password cannot be empty."
        exit 1
    fi
fi

start_all=$(date +%s)
echo "🚀 Starting MyDumper backup at $(date)"
echo "Dump destination: $OUTDIR"
if [[ -n "$TABLES_LIST" ]]; then
    echo "📋 Exporting specific tables: $TABLES_LIST"
else
    echo "📋 Exporting all tables"
fi
echo ""

# Check if output directory exists, create if it doesn't
if [[ -d "$OUTDIR" ]]; then
    echo "⚠️  Output directory already exists: $OUTDIR"
    echo "Removing existing files..."
    rm -rf "$OUTDIR"
fi

echo "Creating output directory: $OUTDIR"
mkdir -p "$OUTDIR"

# --- Start timer for the dump ---
start=$(date +%s)

# Build mydumper command arguments array
MYDUMPER_ARGS=(
    --database="$DB_NAME"
    --outputdir="$OUTDIR"
    --user="$DB_USER"
    --password="$DB_PASS"
    --threads=12
    --compress
    --compress-protocol
    --rows=50000
    --long-query-guard=60
    --build-empty-files
    --trx-tables
    --clear
)

# Add tables-list option if specified
# mydumper requires DATABASE.TABLE format
if [[ -n "$TABLES_LIST" ]]; then
    # Convert comma-separated table list to DATABASE.TABLE format
    FORMATTED_TABLES=""
    IFS=',' read -ra TABLES <<< "$TABLES_LIST"
    for TABLE in "${TABLES[@]}"; do
        # Trim whitespace
        TABLE=$(echo "$TABLE" | xargs)
        # Check if already in DATABASE.TABLE format
        if [[ "$TABLE" == *"."* ]]; then
            FORMATTED_TABLES+="$TABLE,"
        else
            FORMATTED_TABLES+="${DB_NAME}.${TABLE},"
        fi
    done
    # Remove trailing comma
    FORMATTED_TABLES="${FORMATTED_TABLES%,}"
    MYDUMPER_ARGS+=(--tables-list="$FORMATTED_TABLES")
fi

# Execute the command
mydumper "${MYDUMPER_ARGS[@]}"
status=$?
end=$(date +%s)

runtime=$((end - start))
if [ $status -eq 0 ]; then
    echo "✅ Dump completed successfully to $OUTDIR"
else
    echo "❌ Dump failed (exit code $status)"
fi

echo "⏱️  Dump process took ${runtime}s ($(date -u -d @${runtime} +%H:%M:%S))"

# --- Total runtime (same here, but included for consistency if you expand script) ---
end_all=$(date +%s)
total_runtime=$((end_all - start_all))
echo "🏁 Total runtime: ${total_runtime}s ($(date -u -d @${total_runtime} +%H:%M:%S))"
echo ""