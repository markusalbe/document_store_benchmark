
function fix_yum_repos() {
    sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*;
    sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*;
}

function install_linux_tooling() {
    yes | yum install -y epel-release sudo;
    yes | yum install -y which less tar git wget vim screen strace gdb perf bc jq python3 python3-devel python3-pip libaio bash-completion nc gcc-c++ cmake fuse fuse-devel net-tools sysstat psmisc;
    rpm -Uvh http://mirror.centos.org/centos/8-stream/AppStream/x86_64/os/Packages/jq-1.6-3.el8.x86_64.rpm;
}

function install_mongo_clients() {
    mkdir /opt/mongosh;
    cd $_;
    wget -c https://downloads.mongodb.com/compass/mongosh-2.1.1-linux-x64.tgz;
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

