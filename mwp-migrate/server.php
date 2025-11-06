<?php
/**
 * Plugin Name: Server Label & Info
 * Description: Displays "OLD SERVER" or "NEW SERVER" in the admin bar and links to a server info page.
 * Version: 1.0.0
 */

if (!defined('ABSPATH')) exit;

add_action('admin_bar_menu', function($wp_admin_bar) {

    // === CONFIG ===
    $new_servers = [
        '192.168.1.200', // example IP
        'newserver.example.com',
    ];

    // Detect server info
    $server_ip   = $_SERVER['SERVER_ADDR'] ?? 'unknown';
    $server_host = php_uname('n') ?: ($_SERVER['HTTP_HOST'] ?? 'unknown');
    $is_new      = in_array($server_ip, $new_servers, true) || in_array($server_host, $new_servers, true);

    // Label + color
    $label = $is_new ? 'NEW SERVER' : 'OLD SERVER';
    $color = $is_new ? '#198754' : '#dc3545';

    // Add admin bar node (clickable)
    $wp_admin_bar->add_node([
        'id'    => 'server-label',
        'title' => sprintf(
            '<span style="background:%s;color:#fff;padding:2px 6px;border-radius:3px;font-weight:bold;">%s</span>',
            esc_attr($color),
            esc_html($label)
        ),
        'href'  => admin_url('tools.php?page=server-info'),
        'meta'  => ['title' => 'View Server Info'],
    ]);

}, 100);


// === Add Server Info Page under Tools ===
add_action('admin_menu', function() {
    add_management_page(
        'Server Info',
        'Server Info',
        'manage_options',
        'server-info',
        'render_server_info_page'
    );
});

function render_server_info_page() {
    if (!current_user_can('manage_options')) return;

    global $wpdb;

    $server_name = php_uname('n');
    $server_ip   = $_SERVER['SERVER_ADDR'] ?? 'unknown';
    $php_version = PHP_VERSION;
    $mysql_ver   = $wpdb->db_version();
    $wp_version  = get_bloginfo('version');
    $user        = wp_get_current_user()->user_login;
    $extensions  = implode(', ', array_slice(get_loaded_extensions(), 0, 15)); // limit output

    echo '<div class="wrap"><h1>Server Info</h1><table class="widefat striped" style="max-width:600px;">';
    $rows = [
        'Server Name'   => $server_name,
        'Server IP'     => $server_ip,
        'PHP Version'   => $php_version,
        'MySQL Version' => $mysql_ver,
        'WordPress'     => $wp_version,
        'Current User'  => $user,
        'Loaded Extensions' => $extensions,
    ];
    foreach ($rows as $label => $value) {
        printf('<tr><th>%s</th><td>%s</td></tr>', esc_html($label), esc_html($value));
    }
    echo '</table></div>';
}
