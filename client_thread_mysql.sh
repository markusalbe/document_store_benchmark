#!/bin/bash



function client_thread_mysql() {
    local test_type="${1}";
    local test_mode="${2}";
    local test_id="${3}";
    local thread=${4};
    local batch_count=${5};
    local commit_frequency=${6:-0};
    local raw_chunks_datadir="${7}";
    local lookup_chunks_datadir="${8}";

    echo "[$(ts)][thread ${thread}] Invoking MySQL ${test_type} test...";
    case "${test_type}" in
        "insert")  client_thread_mysql_insert "${test_mode}" "${test_id}" "${thread}" "${batch_count}" "${commit_frequency}" "${raw_chunks_datadir}";    ;;
        "update")  client_thread_mysql_update "${test_mode}" "${test_id}" "${thread}" "${batch_count}" "${commit_frequency}" "${lookup_chunks_datadir}";    ;;
        "read")    client_thread_mysql_read   "${test_mode}" "${test_id}" "${thread}" "${batch_count}" "${commit_frequency}" "${lookup_chunks_datadir}";    ;;        
    esac;

}

# The MySQL client worker
function client_thread_mysql_insert() {
    local test_mode="${1}";
    local test_id="${2}";
    local thread=${3};
    local batch_count=${4};
    local commit_frequency=${5:-0};
    local raw_chunks_datadir="${6}";

    local base_sql="INSERT INTO test.companies (doc) VALUES ";

    local statement_cnt=0;  # number of batches INSERTed
    local batch_offset=$(( (thread-1) * batch_count ));

    local t0=$(date +%s.%N);
    echo "[$(ts)][thread ${thread}] Processing $batch_count batches...";

    echo "SET GLOBAL autocommit=1;" | $MYSQL;
    if [[ "${commit_frequency}" -gt 0 ]]; then {
        echo "SET GLOBAL autocommit=0;" | $MYSQL;
    } fi;

    (for batch in $(seq 0 $((batch_count-1))); do {
        if [[ "${commit_frequency}" -gt 0 ]] && [[ ${statement_cnt} -eq 0 ]]; then {
            echo "BEGIN;";
        } fi;
        sql=$(echo -n "${base_sql} ('" && tr -d "'\\" 2>/dev/null < "${raw_chunks_datadir}/chunk.$(printf '%09d' $(( batch_offset+batch)) ).json" |tr "\n" "\t" |sed -E "s/\t/'),('/g; s/\"{2,}/\"/g;");
    	echo "${sql%,(\'};";
        statement_cnt=$((statement_cnt+1));

        if [[ "${commit_frequency}" -gt 0 ]] && [[ ${statement_cnt} -eq "${commit_frequency}" ]]; then {
            echo "COMMIT;";
            statement_cnt=0;
        } fi;

        [[ -f /tmp/exit-benchmark ]] && break;
    } done) |  $MYSQL > /dev/null 2>>"${ERROR_LOG}";

    if [[ "${commit_frequency}" -gt 0 ]]; then {
        echo "[$(ts)][thread ${thread}] Running catch-all COMMIT..." >> "${TEST_LOG}" ;
        echo "COMMIT;"  | ${MYSQL};
    } fi;
    local t1=$(date +%s.%N);

    save_partial_results "${test_id}" "${t0}" "${t1}" ${thread};
    echo "[$(ts)][thread ${thread}] Processing of batches done";
}

function client_thread_mysql_update() {
    local test_mode="${1}";
    local test_id="${2}";
    local thread=${3};
    local batch_count=${4};
    local commit_frequency=${5:-0};
    local lookup_chunks_datadir="${6}";

    local statement_cnt=0;  
    local batch_offset=$(( (thread-1) * batch_count ));

    local base_sql='UPDATE test.companies SET doc = JSON_SET(doc, "$.crunchBaseRank", doc->>"$.crunchBaseRank" + 12345) WHERE ';

    case "${test_mode}" in
        "pk_lookup") base_sql="${base_sql} id IN ";          ;;
        "sk_lookup") base_sql="${base_sql} valuation IN ";   ;;
    esac;


    local t0=$(date +%s.%N);
    echo "[$(ts)][thread ${thread}] Processing $batch_count batches...";

    echo "SET GLOBAL autocommit=1;" | $MYSQL;
    if [[ "${commit_frequency}" -gt 0 ]]; then {
        echo "SET GLOBAL autocommit=0;" | $MYSQL;
    } fi;

    (for batch in $(seq 0 $((batch_count-1))); do {
        if [[ "${commit_frequency}" -gt 0 ]] && [[ ${statement_cnt} -eq 0 ]]; then {
            echo "BEGIN;";
        } fi;

        echo "${base_sql} ( $(tr "\n" ","  <  "${lookup_chunks_datadir}/chunk.$(printf '%09d' $((batch_offset+batch)) ).dat" ) NULL);"; # the NULL at the end is to 'utilize' the comma at the end of the string
        statement_cnt=$((statement_cnt+1));

        if [[ "${commit_frequency}" -gt 0 ]] && [[ "${statement_cnt}" -eq "${commit_frequency}" ]]; then {
            echo "COMMIT;";
            statement_cnt=0;
        } fi;
    } done) | $MYSQL > /dev/null 2>>"${TEST_LOG}";

    if [[ "${commit_frequency}" -gt 0 ]]; then {
        echo "[$(ts)][thread ${thread}] Running catch-all COMMIT..." >> "${TEST_LOG}" ;
        echo "COMMIT;"  | ${MYSQL};
    } fi;
    local t1=$(date +%s.%N);

    save_partial_results "${test_id}" "${t0}" "${t1}" "${thread}";
    echo_green "[$(ts)][thread ${thread}] Processing of batches done";
}

function client_thread_mysql_read() {
    local test_mode="${1}";
    local test_id="${2}";
    local thread=${3};
    local batch_count=${4};
    local commit_frequency=${5:-0};
    local lookup_chunks_datadir="${6}";

    local batch_offset=$(( (thread-1) * batch_count ));    

    local base_sql="SELECT COUNT(*) AS 'thd_${thread}_found_rows' FROM test.companies WHERE ";
    case "${test_mode}" in
        "pk_lookup") base_sql="${base_sql} id IN ";                    ;;
        "sk_lookup") base_sql="${base_sql} valuation IN ";   ;;
    esac;

    local t0=$(date +%s.%N);
    echo_yellow "[$(ts)][thread ${thread}] Processing $batch_count batches...";

    (for batch in $(seq 0 $((batch_count-1))); do {
        echo "${base_sql} ( $(tr "\n" "," < "${lookup_chunks_datadir}/chunk.$(printf '%09d' $((batch_offset+batch)) ).dat") NULL);" ;
        statement_cnt=$((statement_cnt+1));
    } done) | $MYSQL 1> /dev/null 2>>"${TEST_LOG}";

    local t1=$(date +%s.%N);
    save_partial_results "${test_id}" "${t0}" "${t1}" "${thread}";
    echo_green "[$(ts)][thread ${thread}] Processing of batches done";
}
