#!/bin/bash
set -e;
sudo prlimit --nofile=131072 --pid=$$;
source $(dirname $0)/benchmark.common.sh;
source $(dirname $0)/benchmark.data.sh;
source $(dirname $0)/benchmark.db_stats.sh;
source $(dirname $0)/client_thread_mysql.sh;

# create the datadir (and it's parent dir if it doesn't exist)
[[ -d "${WORKDIR}" ]] || mkdir -pv "${WORKDIR}";
[[ -d "${DATADIR}" ]] || mkdir -pv "${DATADIR}";

export TEST_UUID="$(date +%F_%T|tr ':' '-')"; # unique identifier for a given execution of the benchmark
export TEST_LOG="${WORKDIR}/logs/test.${TEST_UUID}.log";
export ERROR_LOG="${WORKDIR}/logs/error.${TEST_UUID}.log";
ln -vfs ${TEST_LOG} ${WORKDIR}/test.log;
ln -vfs ${ERROR_LOG} ${WORKDIR}/error.log;



# Central dispatcher for read-write test workers
function run_test() {
    local protocol=${1};
    local test_type=${2};
    local test_mode=${3};
    local threads=${4};
    local total_rows=${5};
    local batch_size=${6};
    local commit_frequency=${7:-0};

    local test_id="$(get_test_id ${protocol} ${test_type} ${test_mode} ${threads} ${total_rows} ${batch_size} ${commit_frequency})";
    local raw_chunks_datadir=$(get_raw_chunks_datadir "${batch_size}");
    local lookup_chunks_datadir=$(get_lookup_chunks_datadir "${protocol}" "${test_mode}" "${batch_size}");

    local t0=$(date +%s.%N);
    save_db_stats "${protocol}" "${test_id}" "t0";
    
    for thread in $(seq 1 ${threads}); do {
        echo_green "[$(ts)] Starting thread ${thread}/${threads} (${test_id})";
        client_params=$(jq -c -n \
            --arg testType "${test_type}" \
            --arg testMode "${test_mode}" \
            --arg testId "${test_id}" \
            --arg threadId "${thread}" \
            --arg batchCount "$((total_rows/threads/batch_size))" \
            --arg commitFrequency "${commit_frequency}" \
            --arg rawChunksDataDir "${raw_chunks_datadir}" \
            --arg lookupChunksDataDir "${lookup_chunks_datadir}" '$ARGS.named');

        case "${protocol}" in
            "mysql")   client_thread_mysql "${test_type}" "${test_mode}" "${test_id}" "${thread}" "$((total_rows/threads/batch_size))" "${commit_frequency}" "${raw_chunks_datadir}" "${lookup_chunks_datadir}" &    ;;
            "xcom")    ${MYSQLSH} -f client_thread_xcom.js "${client_params}" &  ;;
            "mongodb") TEST_PARAMS="${client_params}" ${MONGOSH} -f client_thread_mongodb.js &  ;;
        esac;
    } done;
    wait;
    local t1=$(date +%s.%N);
    
    save_results "${test_id}" "${t0}" "${t1}";

    save_db_stats "${protocol}" "${test_id}" "t1";
    show_test_db_stats "${protocol}" "${test_id}";

}

function run_loops() {
    local arr_protocols=${1};
    local arr_threads=${2};
    local arr_total_rows=${3}
    local arr_batch_sizes=${4};
    local arr_commit_frequencies=${5};
    local arr_update_test_modes=${6};
    local arr_read_test_modes=${7};
    local runs=${8:-1};

    echo_red "[$(ts)] Dropping VFS caches..."   >> "${TEST_LOG}" 2>&1;
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null;

    for r in $(seq 1 ${runs}); do {
        echo_red "[$(ts)] Starting run #${r} for test ${TEST_UUID}" >> "${TEST_LOG}" 2>&1;
        for total_rows in ${arr_total_rows[@]}; do {
            for protocol in ${arr_protocols[@]}; do {
                for threads in ${arr_threads[@]}; do {
                    for batch_size in ${arr_batch_sizes[@]}; do {

                        recreate_test_env "$(get_test_id ${protocol} "insert" ${test_mode} ${threads} ${total_rows} ${batch_size} 0)" "${protocol}" >> "${TEST_LOG}" 2>&1;

                        for commit_frequency in ${arr_commit_frequencies[@]}; do {
                            run_test "${protocol}" "insert" "ordered" ${threads} ${total_rows} ${batch_size} ${commit_frequency}  >> "${TEST_LOG}" 2>&1;
                        } done;

                        for commit_frequency in ${arr_commit_frequencies[@]}; do {
                            for update_test_mode in ${arr_update_test_modes[@]}; do {
                                run_test "${protocol}" "update" "${update_test_mode}" ${threads} ${total_rows} ${batch_size} ${commit_frequency}  >> "${TEST_LOG}" 2>&1;
                            } done;
                        } done;

                        for read_test_mode in ${arr_read_test_modes[@]}; do {
                            run_test  "${protocol}" "read" "${read_test_mode}" ${threads} ${total_rows} ${batch_size} 0  >> "${TEST_LOG}" 2>&1;
                        } done

                    } done;
                } done;
            } done;
        } done;
    } done
}

benchmark_config=${1:-"$(dirname $0)/benchmark.conf"};
source "${benchmark_config}";

echo -e "$(repeat '=' 80)\n[$(ts)] Starting test with params from ${benchmark_config}; Logging to ${TEST_LOG}\n" |tee -a "${TEST_LOG}";
tail -n +2 "${benchmark_config}";
run_loops "${arr_protocols[*]}" "${arr_threads[*]}" "${arr_total_rows[*]}" "${arr_batch_sizes[*]}" "${arr_commit_frequencies[*]}" "${arr_update_test_modes[*]}" "${arr_read_test_modes[*]}" "${runs[*]}" 
echo -e "$(repeat '=' 80)\n[$(ts)] Completed testing" |tee -a "${TEST_LOG}";


echo "[$(ts)] completed ${1} testing." | tee -a "${TEST_LOG}";
