cat myloader.sh
#!/bin/bash
# Super-fast WordPress DB restore using myloader (timed version)

SCRIPT_DIR=$(dirname "$(realpath "$0")")

# =====================================
# -- Default Settings
# =====================================
INPUT_DIR=""
DB_NAME=""
DB_USER=""
DB_PASS=""
WIPE_DB="0"

# -- Check if myloader.conf exists and source it
if [[ -f "$SCRIPT_DIR/myloader.conf" ]]; then
    source "$SCRIPT_DIR/myloader.conf"
fi

# =====================================
# -- Parse command line arguments
# =====================================
show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
    -i, --input DIR        Input directory containing the dump files
    -d, --database NAME    Database name
    -u, --user USER        Database user
    --wipe                 Drop and recreate database before restore (default: preserve existing tables)
    -h, --help             Show this help message

Examples:
    $(basename "$0") -i /path/to/dump -d mydb -u dbuser
    $(basename "$0") --input ./backup --database wordpress --user root --wipe

Note: If database password is not set in myloader.conf, you will be prompted to enter it.
      By default, only tables in the dump are imported/overwritten. Use --wipe for a clean slate.
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--input)
            INPUT_DIR="$2"
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
        --wipe)
            WIPE_DB="1"
            shift
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
if [[ -z "$INPUT_DIR" ]]; then
    echo "❌ Error: Input directory is required."
    echo "   Set it via -i/--input flag or in myloader.conf"
    exit 1
fi

if [[ ! -d "$INPUT_DIR" ]]; then
    echo "❌ Error: Input directory does not exist: $INPUT_DIR"
    exit 1
fi

if [[ -z "$DB_NAME" ]]; then
    echo "❌ Error: Database name is required."
    echo "   Set it via -d/--database flag or in myloader.conf"
    exit 1
fi

if [[ -z "$DB_USER" ]]; then
    echo "❌ Error: Database user is required."
    echo "   Set it via -u/--user flag or in myloader.conf"
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

echo "🚀 Starting MyLoader restore at $(date)"
echo "Restoring database '$DB_NAME' from: $INPUT_DIR"
if [[ "$WIPE_DB" == "1" ]]; then
    echo "⚠️  WIPE MODE: Database will be dropped and recreated (all existing tables will be removed)"
else
    echo "⚠️  Note: Only importing tables from dump. Existing tables not in dump will be preserved."
fi
echo ""

start_all=$(date +%s)

# --- Drop and recreate database if wipe flag is set ---
if [[ "$WIPE_DB" == "1" ]]; then
    start_drop=$(date +%s)
    mysql -u"$DB_USER" -p"$DB_PASS" -e "DROP DATABASE IF EXISTS \`$DB_NAME\`; CREATE DATABASE \`$DB_NAME\`;"
    end_drop=$(date +%s)
    drop_runtime=$((end_drop - start_drop))
    echo "💾 Database wiped and recreated in ${drop_runtime}s ($(date -u -d @${drop_runtime} +%H:%M:%S))"
    echo ""
fi

# --- Run myloader restore ---
start_restore=$(date +%s)
myloader \
  --database="$DB_NAME" \
  --directory="$INPUT_DIR" \
  --user="$DB_USER" \
  --password="$DB_PASS" \
  --threads=12 \
  --overwrite-tables \
  --verbose=3
status=$?
end_restore=$(date +%s)
restore_runtime=$((end_restore - start_restore))

if [ $status -eq 0 ]; then
    echo "✅ Restore completed successfully from $INPUT_DIR"
else
    echo "❌ Restore failed (exit code $status)"
fi

echo "⏱️  Restore process took ${restore_runtime}s ($(date -u -d @${restore_runtime} +%H:%M:%S))"
echo ""

# --- Total runtime ---
end_all=$(date +%s)
total_runtime=$((end_all - start_all))
echo "🏁 Total runtime: ${total_runtime}s ($(date -u -d @${total_runtime} +%H:%M:%S))"
echo ""

echo "Table Count"
mysql -u"$DB_USER" -p"$DB_PASS" -e "SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = '$DB_NAME';"