#!/bin/bash

source "$(dirname $(readlink -f $0))/benchmark.env.sh";
source "${BASEDIR}/setup.common.sh";
source "${BASEDIR}/setup.$(grep PLATFORM_ID /etc/os-release | grep -Eo '[a-z]{1,3}[0-9]{1,2}').sh";
fix_yum_repos;
install_linux_tooling;
install_percona_repos
install_dbdeployer;
install_mysqlsh;
install_mlaunch;
install_mongo_clients;
install_mgenerate;
setup_group_replication_sandbox;
setup_mongodb_sandbox;
generate_js_test_config
