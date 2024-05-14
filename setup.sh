#!/bin/bash

function fix_yum_repos() {
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*;
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*;
}

function install_linux_tooling() {
    yes | yum install -y epel-release sudo;
    yes | yum install -y which less tar git wget vim screen strace gdb perf python3 python3-devel python3-pip libaio bash-completion nc gcc-c++ cmake fuse fuse-devel net-tools sysstat psmisc;
}

function install_dbdeployer() {
    VERSION=1.66.0;
    OS=linux;
    origin=https://github.com/datacharmer/dbdeployer/releases/download/v$VERSION;
    wget $origin/dbdeployer-$VERSION.$OS.tar.gz;
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

    mkdir -p $HOME/opt/mysql;
    cd $_;
    wget https://downloads.percona.com/downloads/Percona-Server-8.0/Percona-Server-8.0.33-25/binary/tarball/Percona-Server-8.0.33-25-Linux.x86_64.glibc2.17.tar.gz;
    tar xzf Percona-Server-8.0.33-25-Linux.x86_64.glibc2.17.tar.gz;
    mv Percona-Server-8.0.33-25-Linux.x86_64.glibc2.17 8.0.33;
    dbdeployer deploy replication --topology=group $HOME/opt/mysql/8.0.33;
}

function setup_mongodb_sandbox() {
    if [[ ! -x $(which mlaunch) ]]; then {
        install_mlaunch;
    } fi;

    echo "never" > /sys/kernel/mm/transparent_hugepage/enabled;    

    mkdir -p $HOME/opt/mongodb;
    cd $_;
    wget https://downloads.percona.com/downloads/percona-server-mongodb-5.0/percona-server-mongodb-5.0.22-19/binary/tarball/percona-server-mongodb-5.0.22-19-x86_64.glibc2.17.tar.gz;
    tar xzf percona-server-mongodb-5.0.22-19-x86_64.glibc2.17.tar.gz;
    mv percona-server-mongodb-5.0.22-19-x86_64.glibc2.17 5.0.22;
    mkdir -p $HOME/sandboxes/rs_psmdb_5_0_22;
    mlaunch init --replicaset --nodes=3 --binarypath $HOME/opt/mongodb/5.0.22/bin/ --dir $HOME/sandboxes/rs_psmdb_5_0_22;
}

fix_yum_repos;
install_linux_tooling;
install_dbdeployer;
install_mlaunch;
install_mongo_clients;
install_mgenerate;
install_mysqlsh;
setup_group_replication_sandbox;
setup_mongodb_sandbox;
