# ------------------------------
# -- GridPane specific functions
# ------------------------------

# Array help_gp_cmd
declare -A help_gp_cmd

function wpst_gp_cmds () {
    # Go through help_gp_cmd and print out the keys
    for key in "${!help_gp_cmd[@]}"; do
        # use printf to align the output
        printf "    gp-%-20s - %s\n" "$key" "${help_gp_cmd[$key]}"
        #echo "    gp-$key       - ${help_gp_cmd[$key]}"
    done
}

# - logs
help_gp_cmd[logs]='tail or show last lines on all GridPane logs.'
cmd_gp-logs () {
        gp-logs.sh ${*}
}
 
# - logcode
help_gp_cmd[logcode]='Look for specifc HTTP codes in web server logfiles and return top hits.'
cmd_gp-logcode () {
        gp-logcode.sh ${*}
}

# - mysqlmem
help_gp_cmd[mysqlmem]='GridPane monit memory calculation'
cmd_gp-mysqlmem () {
        gp-mysqlmem.sh ${*}
}

# - plugins
help_gp_cmd[plugins]='Lists WordPress plugins on all websites on a GridPane Server'
cmd_gp-plugins () {
        gp-plugins.sh ${*}
}

# - gpcron
help_gp_cmd[gpcron]='List sites using GP Cron'
cmd_gp-gpcron () {
	grep 'cron:true' /var/www/*/logs/*.env	
}

# - backups - execute log functions
help_gp_cmd[backups]='List backups for all sites on the server.'
cmd_gp-backups () {
	ls -aL /home/*/sites/*/logs/backups.env | xargs -l -I {} sh -c "echo {} | awk -F/ '{print \$5}'|tr '\n' '|'; tr '\n' '|' < {};echo \n"
}

# -- api - GridPane api
help_gp_cmd[api]='Interact with the GridPane API'
cmd_gp-api () {
	$SCRIPT_DIR/gp/gp-api.sh ${*}
}


