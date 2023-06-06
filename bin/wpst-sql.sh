#!/bin/bash
# ------------------
# -- wpst-goacces.sh
# ------------------

# -----------
# -- Includes
# -----------
. $(dirname "$0")/functions.sh

# ------------
# -- Variables
# ------------
DEBUG_ON="0"
CMD_VERSION="0.0.1"
CMD_SCRIPT="wpst-sql"

# ------------
# -- Functions
# ------------

USAGE=\
"Usage: $CMD_SCRIPT [-d] [command]
  Commands
    post-meta <post-id>            - Get wp-postmeta data for <post-id>
    woo-order-meta <post-id>       - Get woocomerce_order_items dat for <post-id>
    wp-autoload-options            - List autoload options.
    
  Options:
    -d|--debug           - Debug

CMD Version $CMD_VERSION
WPST Version $WPST_VERSION

"
    
usage () {
    echo "$USAGE"
}

wpst_init () {
	if ! command -v wp > /dev/null;then
	    echo "wp-cli not installed"
    	exit 1
	else
		_debug "wp-cli is installed"
	fi
}

get_table_prefix () {
	WP_TABLE_PREFIX=$(wp db prefix)
	_debug "WP_TABLE_PREFIX=$WP_TABLE_PREFIX"
}

sql_post_meta () {
	get_table_prefix
	POST_ID=$1
	_debug "SQL: wp sql query \" SELECT * from ${WP_TABLE_PREFIX}postmeta where post_id = '$POST_ID'"
	wp sql query "SELECT * from ${WP_TABLE_PREFIX}postmeta where post_id = '$POST_ID'\""
}

sql_woo_order_meta () {
	get_table_prefix
	POST_ID=$1
	#wp sql query "SELECT * FROM wp_bspr_woocommerce_order_items where order_id = '106818'" | less
	#wp sql query "SELECT * FROM wp_bspr_woocommerce_order_itemmeta where order_item_id = '78807'" | less
	_debug "SQL: wp sql query \"SELECT * from ${WP_TABLE_PREFIX}postmeta where post_id = '$POST_ID'\" | tr '\t' ','"
	OUTPUT=$(wp sql query "SELECT * from ${WP_TABLE_PREFIX}postmeta where post_id = '$POST_ID'" | tr '\t' ',')
	HEADERS=$(head -1 $OUTPUT)
	echo $HEADERS
}
sql_wp_autoload_options () {

	_debug "wp sql query \"SELECT * from ${WP_TABLE_PREFIX}options where autoload = 'yes' and option_name like '_transient%';\""
	wp sql query "SELECT * from ${WP_TABLE_PREFIX}options where autoload = 'yes' and option_name like '_transient%'l"
}

poop () {
	PANTS=$1
	echo "Found poop in $PANTS"
}

# ---------------
# -- Main Program
# ---------------
DCMD=""
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -d|--debug)
    DEBUG_ON="1"
    DCMD+="DEBUG_ON=1 "
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

_debug "Running wpst-goaccess $DCMD"
_debug_all $@


ACTION=$1
EXTRA=$2
_debug "ACTION=$ACTION EXTRA=$EXTRA"

wpst_init

if [[ -z $ACTION ]]; then
		usage
	else
		case $ACTION in
		post-meta)
		if [[ -z $EXTRA ]]; then _error "Missing post_id";usage;exit 1;fi
		sql_post_meta $EXTRA
		;;
		woo-order-meta)
		if [[ -z $EXTRA ]]; then _error "Missing post_id";usage;exit 1;fi
		sql_woo_order_meta $EXTRA
		;;
		wp-autoload-options)
		sql_wp_autoload_options
		;;
	esac
fi