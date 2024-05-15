#!/bin/bash

export BASEDIR="$(dirname $(readlink -f $0))";
export WORKDIR="${BASEDIR}/benchmark";
export DATADIR="${WORKDIR}/data";
export JSON="${DATADIR}/companies.json";

# export MYSQL_SANDBOX_DIR="$(dbdeployer sandboxes --latest |awk '{print $1}')";
# export MYSQL_SANDBOX_DIR="${HOME}/sandboxes/group_msb_8_0_33";
export MYSQL_SANDBOX_DIR=$(eval echo "$(dbdeployer defaults show |tail -n +2|jq -r '.["sandbox-home"]')/$(dbdeployer sandboxes --latest |awk '{print $1}')" );
export MYSQL="${MYSQL_SANDBOX_DIR}/n1 -A --max-allowed-packet=1073741824 ";
export MYSQL_ALL_NODES="${MYSQL_SANDBOX_DIR}/use_all";
export MYSQLSH="$(which mysqlsh)";

export MONGODB_SANDBOX_DIR="${HOME}/sandboxes/rs_psmdb_5_0_22";
export MONGODB_BIN_DIR="${HOME}/opt/mongodb/5.0.22/bin/";
export MONGOSH="/opt/mongosh/2.1.1/bin/mongosh --host=127.0.0.1 --port=27017 --quiet";
export MONGO="$(which mongo) --host=127.0.0.1 --port=27017 --quiet";

