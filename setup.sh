#!/bin/bash

source "$(dirname $0)/benchmark.env.sh";
source "$(dirname $0)/setup.common.sh";

fix_yum_repos;
install_linux_tooling;
install_dbdeployer;
install_mlaunch;
install_mongo_clients;
install_mgenerate;
install_mysqlsh;
setup_group_replication_sandbox;
setup_mongodb_sandbox;
generate_js_test_config
