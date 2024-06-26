#!/bin/bash

source "$(dirname $(readlink -f $0))/benchmark.env.sh";

function ts() { date --utc --iso-8601=s; }
function echo_red() { echo -e "\033[31m${1}\033[0m"; }
function echo_green() { echo -e "\033[32m${1}\033[0m"; }
function echo_yellow() { echo -e "\033[33m${1}\033[0m"; }
function repeat() {
    local char="${1}";
    local len=${2};
    printf "%${len}s\n" |tr " " "${char}";
}


function create_table() {
    local protocol=${1};
    case "${protocol}" in
        "mysql")   ${MYSQL} -vvv < create_collection_mysql.sql ;           ;;
        "xcom")    ${MYSQLSH} -f create_collection_xcom.js;               ;;
        "mongodb") ${MONGOSH} -f create_collection_mongodb.js;            ;; 
    esac;
}

# Teardown and create fresh sandbox instances for each iteration of the test.
function recreate_test_env() {
    local test_id=${1};
    local protocol=${2};
    echo "[$(ts)] Restarting environment for test ${test_id}";
    echo "[$(ts)] Restarting ${protocol} instances...";
    case "${protocol}" in
        "mysql" | "xcom") ${MYSQL_SANDBOX_DIR}/wipe_and_restart_all >> "${WORKDIR}/test_env.log" 2>&1 ;             ;;
        "mongodb") recreate_mongodb_test_env >> "${WORKDIR}/test_env.log" 2>&1 ;                                    ;;
    esac;

    echo "[$(ts)] Creating schema for ${protocol}...";
    create_table "${protocol}" >> "${WORKDIR}/test_env.log" 2>&1 ;
    
    # echo "[$(ts)] Dropping VFS caches...";     
    # echo 3 |sudo tee /proc/sys/vm/drop_caches;

    echo "[$(ts)] Completed restarting environment for test ${test_id}";
}

function stop_test_env() {
    protocol=${1};
    echo "[$(ts)] Stopping ${protocol} environment";
    case "${protocol}" in
        "mysql" | "xcom")  ${MYSQL_SANDBOX_DIR}/stop_all >> "${WORKDIR}/test_env.log" 2>&1 ;  ;;
        "mongodb")
            [[ -f "${MONGODB_SANDBOX_DIR}/.mlaunch_startup" ]] && mlaunch kill --signal 9 --dir="${MONGODB_SANDBOX_DIR}";
            killall -9 mongod || echo "No more mongod running"
            ;;
    esac;
}

function wait_for_mongodb_shutdown() {
    while [[ $(ps -C mongod -opid h |wc -l) > 0 ]]; do { sleep 1; echo -n "."; } done;
}

function recreate_mongodb_test_env() {
    # [[ -f "${MONGODB_SANDBOX_DIR}/.mlaunch_startup" ]] && mlaunch kill --signal 9 --dir="${MONGODB_SANDBOX_DIR}";
    echo -n "Terminating mongodb instances...";
    killall -9 mongod || echo "No mongod running";
    rm -rf "${MONGODB_SANDBOX_DIR}/replset"  "${MONGODB_SANDBOX_DIR}/.mlaunch_startup";
    wait_for_mongodb_shutdown;
    echo "";
    mlaunch init --replicaset --priority --nodes 3 --port=27017 --binarypath ${MONGODB_BIN_DIR} --dir="${MONGODB_SANDBOX_DIR}" --wiredTigerCacheSizeGB=4 --bind_ip 127.0.0.1;
    mlaunch list --dir="${MONGODB_SANDBOX_DIR}";
    sleep 10;
    echo "[$(ts)] Done launching MongoDB replicaset...";
}

function get_test_id() {
    local protocol=${1};
    local test_type=${2};
    local test_mode=${3};
    local threads=${4};
    local total_rows=${5};
    local batch_size=${6};
    local commit_frequency=${7:-0};
    echo "${TEST_UUID},${protocol},${test_type},${test_mode},${threads},${total_rows},${batch_size},${commit_frequency}";
}

function get_test_id_fields() {
    echo "test_uuid,protocol,test_type,test_mode,threads,total_rows,batch_size,commit_frequency";
}

function save_results() {
    local test_id=${1};
    local t0=${2};
    local t1=${3};
    local time=$(echo "${t1}-${t0}"|bc);
    echo "$(ts),${test_id},${time}" >> ${WORKDIR}/results/all_test_times.out;
}

function get_results_fields() {
    echo "ts,$(get_test_id_fields),time";
}

function save_partial_results() {
    local test_id=${1};
    local t0=${2};
    local t1=${3};
    local thread=${4};

    local time=$(echo "${t1}-${t0}"|bc);
    echo "$(ts),${test_id},${thread},{$time}" >> "${WORKDIR}/results/partial_test_times.out";
}

function get_partial_results_fields() {
    echo "ts,$(get_test_id_fields),thread_id,time";
}

function show_results() {
    local results_file="${WORKDIR}/results/all_test_times.out";
    local test_uuid=${1};
    echo "$(date +'%F %T') - Results of ${test_uuid}";
    repeat '-' 53;
    (get_results_fields && grep "${test_uuid}" "${results_file}" ) | tr "," " " | column -t;
}

function show_latest_results() {
    local results_file="${WORKDIR}/results/all_test_times.out";
    local latest_test_uuid=$(tail -n1 $results_file |awk -F',' '{print $2}');
    show_results "${latest_test_uuid}";
}

function extract_for_plotly() {
    local test_uuid="${1}";
    local results_file="${2:-${WORKDIR}/results/all_test_times.out}";    
    # protocol
    # `- test_type,test_mode
    #    `- threads
    #       `-  batch_size -> time
    #  Fields in results line:
    #  =======================
    #  1  ts
    #  2  test_uuid
    #  3  protocol
    #  4  test_type
    #  5  test_mode
    #  6  threads
    #  7  total_rows
    #  8  batch_size
    #  9  commit_frequency
    # 10  time

    (get_results_fields && grep "${test_uuid}" "${results_file}") \
    | awk -F',' '
    // {
        if (NR > 1) { 
            k=sprintf("%s,%s,%s_%s,%s,%s,%s,%s", $2,$3,$4,$5,$6,$7,$8,$9);
            times[k]+=$10;
            cnt[k]++;
        } else {
            printf("%s,%s,%s_%s,%s,%s,%s,%s,%s\n", $2,$3,$4,$5,$6,$7,$8,$9,$10);
        }
    }

    END {
        k="";
        for (k in times) {
            printf("%s,%5.2f\n", k, times[k]/cnt[k]);
        }
    }' \
    | tr "," " " \
    | sort -n -k4 -k6 \
    | tr " " "," \
    | sed 's/test_type_test_mode/test/'; # headers get smashed and have uninteligible name...make it "test"
}

function extract_latest_for_plotly() {
    local results_file="${1:-${WORKDIR}/results/all_test_times.out}";
    local latest_test_uuid=$(tail -n1 $results_file |awk -F',' '{print $2}');
    extract_for_plotly "${latest_test_uuid}" > ${WORKDIR}/plotly/test.${latest_test_uuid}.csv;
}


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
    pmm_annotate "${protocol}" "${test_type}" "${test_mode}" ${threads} ${batch_size};
    
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

    # echo_red "[$(ts)] Dropping VFS caches..."   >> "${TEST_LOG}" 2>&1;
    # echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null;

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

