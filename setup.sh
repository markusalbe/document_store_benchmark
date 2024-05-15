#!/bin/bash

source "$(dirname $(readlink -f $0))/benchmark.env.sh";
source "${BASENAME}/setup.common.sh";

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
