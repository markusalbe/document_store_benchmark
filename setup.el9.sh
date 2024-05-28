
function fix_yum_repos() {
}

function install_linux_tooling() {
    yes | yum install -y epel-release sudo;
    yes | yum install -y which less tar git wget vim screen strace gdb perf bc jq python3 python3-devel python3-pip libaio bash-completion nc gcc-c++ cmake fuse fuse-devel net-tools sysstat psmisc libnsl libnsl2 openldap-compat jq;

}

function install_mgenerate() {
    yes | yum install -y nodejs;
    npm install -g mgeneratejs;
}
