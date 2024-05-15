#!/bin/bash
set -e;
sudo prlimit --nofile=131072 --pid=$$;
source "$(dirname $(readlink -f $0))/benchmark.env.sh";
source ${BASEDIR}/benchmark.common.sh;
source ${BASEDIR}/benchmark.data.sh;
source ${BASEDIR}/benchmark.db_stats.sh;
source ${BASEDIR}/client_thread_mysql.sh;

# create the datadir (and it's parent dir if it doesn't exist)
[[ -d "${WORKDIR}" ]] || mkdir -pv "${WORKDIR}";
[[ -d "${DATADIR}" ]] || mkdir -pv "${DATADIR}";

export TEST_UUID="$(date +%F_%T|tr ':' '-')"; # unique identifier for a given execution of the benchmark
export TEST_LOG="${WORKDIR}/logs/test.${TEST_UUID}.log";
export ERROR_LOG="${WORKDIR}/logs/error.${TEST_UUID}.log";
ln -vfs ${TEST_LOG} ${WORKDIR}/test.log;
ln -vfs ${ERROR_LOG} ${WORKDIR}/error.log;


benchmark_config=${1:-"${BASEDIR}/benchmark.conf"};
source "${benchmark_config}";

echo -e "$(repeat '=' 80)\n[$(ts)] Starting test with params from ${benchmark_config}; Logging to ${TEST_LOG}\n" |tee -a "${TEST_LOG}";
tail -n +2 "${benchmark_config}";
run_loops "${arr_protocols[*]}" "${arr_threads[*]}" "${arr_total_rows[*]}" "${arr_batch_sizes[*]}" "${arr_commit_frequencies[*]}" "${arr_update_test_modes[*]}" "${arr_read_test_modes[*]}" "${runs[*]}" 
echo -e "$(repeat '=' 80)\n[$(ts)] Completed testing" |tee -a "${TEST_LOG}";


echo "[$(ts)] completed ${1} testing." | tee -a "${TEST_LOG}";
