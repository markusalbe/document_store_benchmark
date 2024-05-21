#!/bin/bash


function get_test_datadir() {
    local threads=${1};
    local total_rows=${2};
    local batch_size=${3};
    echo "${DATADIR}/total_rows_${total_rows}/threads_${threads}/rows_per_batch_${batch_size}";
}

function get_raw_chunks_datadir() {
    local batch_size=${1};
    echo "${DATADIR}/raw/rows_per_batch_${batch_size}";
}

function get_lookup_chunks_datadir() {
    local protocol=${1};
    local test_mode=${2:-""};
    local batch_size=${3:-""};

    local datadir="${DATADIR}/lookup/${protocol}";

    if [[ ! -z "${test_mode}" ]]; then {
        datadir="${datadir}/${test_mode}";
    } fi;

    if [[ ! -z "${batch_size}" ]]; then {
        datadir="${datadir}/rows_per_batch_${batch_size}";
    } fi;

    echo "${datadir}";
}

function generate_main_json() {
    local threads=${1:-8}; 
    local total_rows=${2};
    local target=${3};

    local template="${target}.template";
    
    echo_yellow "[$(ts)] Preparing main JSON file (${target}) with ${total_rows} documents using ${threads} threads";
    for i in $(seq 1 "${threads}"); do {
        echo_yellow "[$(ts)] mgeneratejs thread #${i} started";
        mgeneratejs -n "$((total_rows/threads))" < "${template}" > "${target}.tmp.${i}" &
    } done;
    wait;
    
    cat ${target}.tmp.* | sed -E 's/:\{"\$oid"//g; s/"\}(,"firm":)/"\1/g'  > "${target}";
    rm -vf ${target}.tmp.*;
    echo_green "[$(ts)] Done preparing main JSON file";
}

function cleanup_data_files() {
    local remove_main_json=${1:-0};
    if [[ ${remove_main_json} == 1 ]]; then {
        echo_yellow "[$(ts)] Removing main json file...";
        rm -vf "${JSON}";
    } fi;
    echo_yellow "[$(ts)] Removing lookup files...";
    find ${DATADIR} -type f -name "*lookup*" -delete;
    find ${DATADIR} -type s -name "*lookup*" -delete;
    echo_yellow "[$(ts)] Removing source data files...";
    find ${DATADIR} -type f -name  "chunk.*" -delete;
    echo_green "[$(ts)] Completed files cleanup.";
}

function split_data_files_by_thread() {
    local threads=${1};
    local total_rows=${2};
    local batch_size=${3};
    local test_datadir=$(get_test_datadir ${threads} ${total_rows} ${batch_size});

    mkdir -vp "${test_datadir}";

    local thread_chunk_size=$((total_rows/threads));
    local total_batches=$((thread_chunk_size/batch_size));

    echo "[$(ts)] Preparing data files for ${threads} threads: ${total_batches} batches of ${batch_size} documents each (in ${test_datadir})";
    for thread in $(seq 1 ${threads}); do {
        split --suffix-length=9 --additional-suffix=.json -d  -l${batch_size}  <(tail -n +$(( ((thread-1) * thread_chunk_size) + 1 )) "${JSON}" | head -n ${thread_chunk_size}  )   ${test_datadir}/thread.${thread}.;
    } done;
    echo "[$(ts)] Done preparing data files.";
}

function split_data_files_by_chunk_size() {
    local total_rows=${1};
    local batch_size=${2};
    local raw_chunks_datadir=$(get_raw_chunks_datadir ${batch_size});

    mkdir -vp "${raw_chunks_datadir}";

    local total_batches=$((total_rows/batch_size));

    echo_yellow "[$(ts)] Splitting data file with ${total_rows} rows into ${total_batches} batches of ${batch_size} rows each (in ${raw_chunks_datadir})";
    split --suffix-length=9  --numeric-suffixes --additional-suffix=.json --lines=${batch_size} "${JSON}" "${raw_chunks_datadir}/chunk.";
    echo_green "[$(ts)] Done splitting data file.";
}

function extract_and_split_lookup_conditions_using_symlinks() {
    local arr_batch_sizes=${1};

    mkdir -vp "$(get_lookup_chunks_datadir 'mysql')/pk_lookup";
    mkdir -vp "$(get_lookup_chunks_datadir 'mysql')/sk_lookup"

    # mkdir -vp "$(get_lookup_chunks_datadir 'mongodb')/sk_lookup";
    mkdir -vp "$(get_lookup_chunks_datadir 'mongodb')/pk_lookup";

    # mkdir -vp "$(get_lookup_chunks_datadir 'xcom')/sk_lookup";
    # mkdir -vp "$(get_lookup_chunks_datadir 'xcom')/pk_lookup";


    extract_pk "mysql" "$(get_lookup_chunks_datadir 'mysql')/pk_lookup.master";   
    extract_pk "mongodb" "$(get_lookup_chunks_datadir 'mongodb')/pk_lookup.master";   
    # symlink mongodb pk_lookup.master as xcom's one
    ln -s "$(get_lookup_chunks_datadir 'mongodb')/pk_lookup.master" "$(get_lookup_chunks_datadir 'xcom')/pk_lookup.master";

    extract_sk "mysql" "$(get_lookup_chunks_datadir 'mysql')/sk_lookup.master"; 
    # symlink mysql's sk_lookup.master for xcom and mongodb 
    ln -vfs "$(get_lookup_chunks_datadir 'mysql')/sk_lookup.master" "$(get_lookup_chunks_datadir 'xcom')/sk_lookup.master";
    ln -vfs "$(get_lookup_chunks_datadir 'mysql')/sk_lookup.master" "$(get_lookup_chunks_datadir 'mongodb')/sk_lookup.master";

    for batch_size in ${arr_batch_sizes[@]}; do {
        mysql_chunks_datadir="$(get_lookup_chunks_datadir 'mysql' 'pk_lookup' ${batch_size})";
        mkdir -vp "${mysql_chunks_datadir}";
        echo_yellow "[$(ts)] Splitting $(get_lookup_chunks_datadir 'mysql')/pk_lookup.master in batches of ${batch_size} rows each";
        split --suffix-length=9 --numeric-suffixes --additional-suffix=.dat --lines=${batch_size} "$(get_lookup_chunks_datadir 'mysql')/pk_lookup.master" "${mysql_chunks_datadir}/chunk.";

        mysql_chunks_datadir="$(get_lookup_chunks_datadir 'mysql' 'sk_lookup' ${batch_size})";
        mkdir -vp "${mysql_chunks_datadir}";
        echo_yellow "[$(ts)] Splitting $(get_lookup_chunks_datadir 'mysql')/sk_lookup.master in batches of ${batch_size} rows each";
        split --suffix-length=9 --numeric-suffixes --additional-suffix=.dat --lines=${batch_size} "$(get_lookup_chunks_datadir 'mysql')/sk_lookup.master" "${mysql_chunks_datadir}/chunk.";

        mongodb_chunks_datadir="$(get_lookup_chunks_datadir 'mongodb' 'pk_lookup' ${batch_size})";
        mkdir -vp "${mongodb_chunks_datadir}";
        echo_yellow "[$(ts)] Splitting $(get_lookup_chunks_datadir 'mongodb')/pk_lookup.master in batches of ${batch_size} rows each";        
        split --suffix-length=9 --numeric-suffixes --additional-suffix=.dat --lines=${batch_size} "$(get_lookup_chunks_datadir 'mongodb')/pk_lookup.master" "${mongodb_chunks_datadir}/chunk.";        
    } done

    # symlink mongodb as xcom for PK conditions
    ln -vfs "$(get_lookup_chunks_datadir 'mongodb' 'pk_lookup')" "$(get_lookup_chunks_datadir  'xcom' 'pk_lookup')";

    # symlink mysql as mongodb and xcom for SK conditions
    ln -vfs "$(get_lookup_chunks_datadir 'mysql' 'sk_lookup')" "$(get_lookup_chunks_datadir 'xcom' 'sk_lookup')";
    ln -vfs "$(get_lookup_chunks_datadir 'mysql' 'sk_lookup')" "$(get_lookup_chunks_datadir 'mongodb' 'sk_lookup')";
}


function extract_and_split_lookup_conditions_for_protocol() {
    local arr_batch_sizes=${1};
    local protocol=${2};

    mkdir -vp "$(get_lookup_chunks_datadir "${protocol}")/pk_lookup";

    extract_pk "${protocol}" "$(get_lookup_chunks_datadir "${protocol}")/pk_lookup.master";   
    extract_sk "${protocol}" "$(get_lookup_chunks_datadir "${protocol}")/sk_lookup.master"; 

    for batch_size in ${arr_batch_sizes[@]}; do {
        pk_chunks_datadir="$(get_lookup_chunks_datadir "${protocol}" 'pk_lookup' ${batch_size})";
        mkdir -vp "${pk_chunks_datadir}";
        echo_yellow "[$(ts)] Splitting $(get_lookup_chunks_datadir "${protocol}")/pk_lookup.master in batches of ${batch_size} rows each";
        split --suffix-length=9 --numeric-suffixes --additional-suffix=.dat --lines=${batch_size} "$(get_lookup_chunks_datadir "${protocol}")/pk_lookup.master" "${pk_chunks_datadir}/chunk.";

        sk_chunks_datadir="$(get_lookup_chunks_datadir "${protocol}" 'sk_lookup' ${batch_size})";
        mkdir -vp "${sk_chunks_datadir}";
        echo_yellow "[$(ts)] Splitting $(get_lookup_chunks_datadir "${protocol}")/sk_lookup.master in batches of ${batch_size} rows each";
        split --suffix-length=9 --numeric-suffixes --additional-suffix=.dat --lines=${batch_size} "$(get_lookup_chunks_datadir "${protocol}")/sk_lookup.master" "${sk_chunks_datadir}/chunk.";
    } done;
    
}


function extract_and_split_lookup_conditions_by_chunk_size() {
    local total_rows=${1};
    local batch_size=${2};
    local protocol=${3};
    local test_mode=${4};

    local protocol_lookup_datadir=$(get_lookup_chunks_datadir ${protocol});
    local chunks_lookup_datadir=$(get_lookup_chunks_datadir ${protocol} ${batch_size});

    local total_batches=$((total_rows/batch_size));

    echo_yellow "[$(ts)] Preparing ${total_batches} lookup files (${protocol}/${test_mode}) with batches of ${batch_size} documents each (in ${test_datadir})";
    #   local list_file="${DATADIR}/${test_mode}.${protocol}.list";
    local protocol_lookup_master_file="${protocol_lookup_datadir}/${test_mode}.master";
    case "${test_mode}" in
        "pk_lookup") extract_pk "${protocol}" "${protocol_lookup_master_file}";   ;;
        "sk_lookup") extract_sk "${protocol}" "${protocol_lookup_master_file}";   ;;    
    esac;

    echo_yellow "[$(ts)] Preparing ${total_batches} lookup files (${protocol}/${test_mode}) with batches of ${batch_size} documents each (in ${test_datadir})";

    echo_yellow "[$(ts)] Splitting batches for ${test_mode}...";
    split --suffix-length=9 --numeric-suffixes --additional-suffix=.dat --lines=${batch_size} "${protocol_lookup_master_file}" "${test_datadir}/thread.${test_mode}.${protocol}.${thread}.";
    echo_green "[$(ts)] Done splitting batches for ${test_mode}.";

    echo_green "[$(ts)] Done preparing lookup files.";
}

function extract_and_split_lookup_conditions_by_thread() {
    local threads=${1};
    local total_rows=${2};
    local batch_size=${3};
    local protocol=${4};
    local overwrite=${5:-0};
    local test_datadir=$(get_test_datadir ${threads} ${total_rows} ${batch_size});

    local thread_chunk_size=$((total_rows/threads));
    local total_batches=$((thread_chunk_size/batch_size));

    echo_yellow "[$(ts)] Preparing lookup files for ${threads} threads: ${total_batches} batches of ${batch_size} documents each (in ${test_datadir})";
    for test_mode in "pk_lookup" "sk_lookup"; do {
        local list_file="${DATADIR}/${test_mode}.${protocol}.list";
        local lookup_file_basename="${test_datadir}/thread.${test_mode}.${protocol}";
        # if first lookup file exists, then we skip (unless overwrite enabled)
        if [[ ! -f "${lookup_file_basename}.1.000000001" ]] || [[ ${overwrite} == 1 ]]; then {
            echo_yellow "[$(ts)] No thread lookup file found (or overwrite enabled)...";

            case "${test_mode}" in
                "pk_lookup") extract_pk "${protocol}" "${list_file}";   ;;
                "sk_lookup") extract_sk "${protocol}" "${list_file}";   ;;
            esac;

            echo_yellow "[$(ts)] Splitting batches for ${test_mode}...";
            for thread in $(seq 1 ${threads}); do {
                split --suffix-length=9 --additional-suffix=.json -d -l${batch_size}  <(tail -n +$((((thread-1) * thread_chunk_size) + 1)) "${list_file}" | head -n ${thread_chunk_size})  "${test_datadir}/thread.${test_mode}.${protocol}.${thread}.";
            } done;
            echo_green "[$(ts)] Done splitting batches for ${test_mode}.";
        } else {
            echo_green "[$(ts)] Lookup files already prepared, skipping creation"; 
        } fi;
    } done;
    echo_green "[$(ts)] Done preparing lookup files.";
}

function extract_pk() {
    local protocol="${1}";
    local list_file="${2}";

    echo_yellow "[$(ts)] Extracting PKs for "${protocol}" lookups";
    case "${protocol}" in
        "mysql") seq 1 $(wc -l "${JSON}" |awk '{print $1}') > "${list_file}";    ;;
        "xcom" | "mongodb") jq .'_id' "${JSON}" > "${list_file}";         ;;
    esac;
    echo_green "[$(ts)] Done extracting PKs for "${protocol}" lookups: ${list_file} with $(wc -l ${list_file}|awk '{print $1}') primary key values";
}

function extract_sk() {
    local protocol="${1}";
    local list_file="${2}";

    echo_yellow "[$(ts)] Extracting SKs for "${protocol}" lookups from ${JSON}";
    jq .'valuation' "${JSON}" > "${list_file}";
    echo_green "[$(ts)] Done extracting SKs for "${protocol}" lookups: ${list_file} with $(wc -l ${list_file}|awk '{print $1}') secondary key values";
}


function split_by_threads() {
    local arr_protocols=${1};
    local arr_threads=${2};
    local arr_total_rows=${3}
    local arr_batch_sizes=${4};
    for threads in ${arr_threads[@]}; do {
        for total_rows in ${arr_total_rows[@]}; do {
            for batch_size in ${arr_batch_sizes[@]}; do {
                echo_green "[$(ts)]Preparing source data files for ${total_rows} split over ${threads} threads doing batches of ${batch_size} rows";
                split_data_files_by_thread ${threads} ${total_rows} ${batch_size};
                for protocol in ${arr_protocols[@]}; do {
                    echo_yellow "[$(ts)]Preparing lookup data files for ${total_rows} split over ${threads} threads doing batches of ${batch_size} rows";
                    extract_and_split_lookup_conditions_by_thread "${threads}" "${total_rows}" "${batch_size}" "${protocol}" 1 ;
                } done;
            } done;
        } done;
    } done;
}

function split_by_chunk_size() {
    local arr_protocols=${1};
    local arr_total_rows=${2}
    local arr_batch_sizes=${3};
    local arr_read_test_modes=${4};
    local total_rows=$(echo ${arr_total_rows[*]}|tr " " "\n" |sort -nr |head -n1); # max rows

    for batch_size in ${arr_batch_sizes[@]}; do {
        echo_yellow "[$(ts)]Preparing source data files for ${total_rows} in batches of ${batch_size} rows";
        split_data_files_by_chunk_size ${total_rows} ${batch_size};
    } done;    

    echo_yellow "[$(ts)]Preparing lookup data files for ${total_rows} rows";
    extract_and_split_lookup_conditions_using_symlinks "${arr_batch_sizes[*]}";
}

