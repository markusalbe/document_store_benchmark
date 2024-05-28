
function fix_yum_repos() {
}

function install_linux_tooling() {
    yes | yum install -y epel-release sudo;
    yes | yum install -y which less tar git wget vim screen strace gdb perf bc jq python3 python3-devel python3-pip libaio bash-completion nc gcc-c++ cmake fuse fuse-devel net-tools sysstat psmisc libnsl libnsl2 openldap-compat jq;

}

function install_mongo_clients() {
    mkdir /opt/mongosh;
    cd $_;
    wget -c https://downloads.mongodb.com/compass/mongosh-2.1.1-linux-x64.tgz;
    tar xzf mongosh-2.1.1-linux-x64.tgz;
    mv mongosh-2.1.1-linux-x64 2.1.1;

    # TODO:
    cd $HOME;
    wget https://fastdl.mongodb.org/linux/mongodb-shell-linux-x86_64-rhel80-5.0.26.tgz;

}

function install_mgenerate() {
    yes | yum install -y nodejs;
    npm install -g mgeneratejs;
}
