
function fix_yum_repos() {
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*;
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*;
}

function install_linux_tooling() {
    yes | yum install -y epel-release sudo;
    yes | yum install -y which less tar git wget vim screen strace gdb perf jq python3 python3-devel python3-pip libaio bash-completion nc gcc-c++ cmake fuse fuse-devel net-tools sysstat psmisc;
}

function install_dbdeployer() {
    VERSION=1.66.0;
    OS=linux;
    origin=https://github.com/datacharmer/dbdeployer/releases/download/v$VERSION;
    wget -c $origin/dbdeployer-$VERSION.$OS.tar.gz;
    tar -xzf dbdeployer-$VERSION.$OS.tar.gz;
    chmod +x dbdeployer-$VERSION.$OS;
    mv dbdeployer-$VERSION.$OS /usr/local/bin/dbdeployer;
    dbdeployer init;
}

function install_mlaunch() {
    pip3 install packaging;
    pip3 install pymongo;
    pip3 install psutil;
    pip3 install mtools;
}

function install_mongo_clients() {
    mkdir /opt/mongosh;
    cd $_;
    wget https://downloads.mongodb.com/compass/mongosh-2.1.1-linux-x64.tgz;
    tar xzf mongosh-2.1.1-linux-x64.tgz;
    mv mongosh-2.1.1-linux-x64 2.1.1;

    percona-release setup psmdb42;
    yes | yum install -y percona-server-mongodb-shell-4.2.14-15.el8.x86_64;
}

function install_mgenerate() {
    yes | dnf module reset nodejs;
    yes | dnf module install nodejs:12;

    yes | yum install -y npm;
    npm install -g mgeneratejs;
}

function install_mysqlsh() {
    yes | yum install -y https://repo.percona.com/yum/percona-release-latest.noarch.rpm;
    percona-release setup mysql-shell;
    yes | yum install -y percona-mysql-shell; 
}

function setup_group_replication_sandbox() {
    if [[ ! -x $(which dbdeployer) ]]; then {
        install_dbdeployer;
    } fi;

    mkdir -p ${HOME}/opt/mysql;
    cd $_;
    wget https://downloads.percona.com/downloads/Percona-Server-8.0/Percona-Server-8.0.33-25/binary/tarball/Percona-Server-8.0.33-25-Linux.x86_64.glibc2.17.tar.gz;
    tar xzf Percona-Server-8.0.33-25-Linux.x86_64.glibc2.17.tar.gz;
    mv Percona-Server-8.0.33-25-Linux.x86_64.glibc2.17 8.0.33;
    dbdeployer deploy replication --topology=group ./8.0.33;

    # the one we get from .env file ain't properly defined, as no sandbox was deployed when the file is sourced in this setup script.
    export MYSQL_SANDBOX_DIR=$(eval echo "$(dbdeployer defaults show | tail -n +2 | jq -r '.["sandbox-home"]')/$(dbdeployer sandboxes --latest | awk '{print $1}')" );
    cp -v $(dirname $0)/common.cnf ${MYSQL_SANDBOX_DIR}/;
    cnf="${MYSQL_SANDBOX_DIR}/common.cnf";

    printf "%sinclude %s" '!' "${cnf}" >> ${MYSQL_SANDBOX_DIR}/node1/my.sandbox.cnf;
    printf "%sinclude %s" '!' "${cnf}" >> ${MYSQL_SANDBOX_DIR}/node2/my.sandbox.cnf;
    printf "%sinclude %s" '!' "${cnf}" >> ${MYSQL_SANDBOX_DIR}/node3/my.sandbox.cnf;
    ${MYSQL_SANDBOX_DIR}/wipe_and_restart_all;
}

function setup_mongodb_sandbox() {
    if [[ ! -x $(which mlaunch) ]]; then {
        install_mlaunch;
    } fi;

    echo "never" > /sys/kernel/mm/transparent_hugepage/enabled;    

    mkdir -p ${HOME}/opt/mongodb;
    cd $_;
    wget https://downloads.percona.com/downloads/percona-server-mongodb-5.0/percona-server-mongodb-5.0.22-19/binary/tarball/percona-server-mongodb-5.0.22-19-x86_64.glibc2.17.tar.gz;
    tar xzf percona-server-mongodb-5.0.22-19-x86_64.glibc2.17.tar.gz;
    mv percona-server-mongodb-5.0.22-19-x86_64.glibc2.17 5.0.22;
    mkdir -p ${MONGODB_SANDBOX_DIR};
    mlaunch init --replicaset --nodes=3 --binarypath ${HOME}/opt/mongodb/5.0.22/bin/ --dir ${MONGODB_SANDBOX_DIR};
}

function generate_js_test_config() {

    cat << EOT > "$(dirname $0)/js_test_config.json"
{
    "dataDir": "${WORKDIR}/data",
    "schema": "test",
    "collection": "companies",
    "connectionOpts": {
        "host": "localhost",
        "port": $(${MYSQL_SANDBOX_DIR}/node1/metadata port),
        "user": "msandbox",
        "password": "msandbox"
    }
}

EOT

    [[ -f "$(dirname $0)/js_test_config.json" ]] || echo "$(dirname $0)/js_test_config.json not created";
}