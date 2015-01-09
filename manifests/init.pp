# == Class: sourcebans
#
# Install and configure SourceBans
#
# === Parameters
#
# Document parameters here.
#
# [*source_type*]
#   Method to use to access install media.
#   Default: puppet
# [*source_url*]
#   URL to use for install files.
#   Default: 
# [*web_proto*]
#   Protocol, http or https
#   Default: http
# [*web_server*]
#   Web server, should be the publically resolvable name
#   Default: $::fqdn
# [*web_port*]
#   Port to run on
#   Default: 80
# [*web_path*]
#   Path to append at the end of the URI. Used if sourcebans is a subdirectory
#   of another vhost.
#   Default: sourcebans
# [*web_user*]
#   Web server username
#   Default: apache
# [*web_group*]
#   Web server group
#   Default: apache
# [*web_root*]
#   Root path to install SourceBans into
#   Default: /opt/sourcebans
# [*sm_user*]
#   SourceMod username
#   Default: insserver
# [*sm_group*]
#   SourceMod group
#   Default: insserver
# [*sm_root*]
#   Root path to install SourceBans into
#   Default: /home/insserver/serverfiles/insurgency/addons/sourcemod
# [*sm_serverid*]
#   Server ID
#   Default: -1
# [*db_host*]
#   Database server
#   Default: localhost
# [*db_user*]
#   Database username
#   Default: sourcebans
# [*db_pass*]
#   Database user password
#   Default: sourcebans
# [*db_name*]
#   Database name
#   Default: sourcebans
# [*db_type*]
#   Database type (only MySQL supported)
#   Default: mysql
# [*admin_user*]
#   Admin username
#   Default: admin
# [*admin_pass*]
#   Admin user password
#   Default: Password#1
# [*admin_update*]
#   Always update admin user password to the admin_pass.
#   Default: false
#
# === Variables
#
# [*url*]
#   Assembled from web_ variables to give the URL that should be given to
#   clients to connect to in their browsers.
#
# === Examples
#
#  class { 'sourcebans':
#    admin_pass => 'Password#1',
#  }
#
# === Authors
#
# Jared Ballou <puppet@jballou.com>
#
# === Copyright
#
# Copyright 2014 Jared Ballou, unless otherwise noted.
#
class sourcebans(
  $source_type  = 'puppet',
  $source_url   = '',
  $role_sm      = false,
  $role_web     = false,
  $sm_user      = 'insserver',
  $sm_group     = 'insserver',
  $sm_root      = '/home/insserver/serverfiles/insurgency/addons/sourcemod',
  $sm_serverid  = -1,
  $db_host      = 'localhost',
  $db_user      = 'sourcebans',
  $db_pass      = 'sourcebans',
  $db_name      = 'sourcebans',
  $db_prefix    = 'sourcebans',
  $db_type      = 'mysql',
  $web_user     = 'apache',
  $web_group    = 'apache',
  $web_root     = '/opt/sourcebans',
  $web_proto    = 'http',
  $web_server   = $::fqdn,
  $web_port     = '',
  $web_path     = 'sourcebans',
  $admin_user   = 'admin',
  $admin_pass   = 'Password#1',
  $admin_update = false,
) {
  #Install MySQL if needed
  if ($db_host == 'localhost') {
    include mysql::server
  }
  #Assemble the complete URL, only append the port if it's non-standard
  if ($web_port and (($web_port != 80 and $web_proto == 'http') or ($web_port != 443 and $web_proto == 'https'))) {
    $url = "${web_proto}://${web_server}:${web_port}/${web_path}"
    $web_real_port = $web_port
  } else {
    $url = "${web_proto}://${web_server}/${web_path}"
    $web_real_port = $web_proto ? { 'https' => 443, default => 80, }
  }
  if ($role_web) {
    #Include Apache, mod_php and php-mysql
    include apache
    include apache::mod::php
    include mysql::bindings::php
    #Set defaults for resources
    Vcsrepo { owner => $web_user, group => $web_group, ensure => present, provider => git, revision => 'master', }
    File { owner => $web_user, group => $web_group, }

    #Install needed packages. TODO: Include other classes to avoid resource collisions
    package { ['git','gdb','mailx','wget','nano','tmux','glibc.i686','libstdc++.i686']: ensure => present, } ->
    #Hack to create install directory with parents if needed
    exec { 'create-sourcebans-web_root': command => "mkdir -p \"${web_root}\"", creates => $web_root,  } ->
    #Actual file resource for install directory
    file { $web_root: ensure => directory, mode => '0775', source => 'puppet:///modules/sourcebans/files/web_upload', recurse => remote, } ->
    #Apache vhost
    apache::vhost { $web_server:
      port          => $web_real_port,
      docroot       => "${web_root}",
      docroot_group => $web_group,
      docroot_owner => $web_user,
    } ->
    #Firewall rule for Apache
    firewall { '100 allow http access':
      port   => $web_real_port,
      proto  => tcp,
      action => accept,
    } ->
    #Update install.sql dump with any changes (currently just admin password)
    file { "${web_root}/sql/install.sql": content => template('sourcebans/install.sql.erb'), } ->
    #Create database, user, and grants as needed, if database does not exist the SQL dump will be imported
    mysql::db { $db_name:
      user           => $db_user,
      password       => $db_pass,
      host           => $db_host,
      grant          => 'ALL',
      sql            => "${web_root}/sql/install.sql",
    }
  }
  if ($role_sm) {
    file { $sm_root: owner => $sm_user, group => $sm_group, ensure => directory, mode => '0775', source => 'puppet:///modules/sourcebans/files/game_upload/addons/sourcemod', recurse => remote, }
  }
}
