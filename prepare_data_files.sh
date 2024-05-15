#!/bin/bash
source "$(dirname $(readlink -f $0))/benchmark.env.sh";
source "${BASEDIR}/benchmark.common.sh";
source "${BASEDIR}/benchmark.data.sh";

benchmark_config=${1:-"${BASEDIR}/benchmark.mini.conf"};
source "${benchmark_config}";

overwrite=${2:-0};
overwrite_main_json=${3:-0};


if [[ ${overwrite_main_json} == 1 ]] || [[ ${overwrite} == 1 ]]; then {
    echo_red "[$(ts)] Overwrite set; cleaning up data and lookup files...";
    cleanup_data_files ${overwrite_main_json};
} fi;

if [[ ! -f "${JSON}" ]] || [[ ${overwrite_main_json} == 1 ]]; then {
    total_rows=$(echo ${arr_total_rows[*]}|tr " " "\n" |sort -nr |head -n1); # max rows
    echo_red "[$(ts)] Main JSON file not found or overwrite set; (re)creating ${JSON} with ${total_rows}...";
    generate_main_json 8 ${total_rows} "${JSON}";
} else {
    echo "[$(ts)] Main JSON file found at ${JSON}, skipping creation";
} fi;

split_by_chunk_size "${arr_protocols[*]}" "${arr_total_rows[*]}" "${arr_batch_sizes[*]}" "${arr_read_test_modes[*]}";
