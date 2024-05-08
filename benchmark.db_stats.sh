#!/bin/bash
function show_test_db_stats() {
    local protocol="${1}";
    local test_id="${2}";

    local xpath_rows_inserted='.Innodb_rows_inserted';
    local xpath_rows_updated='.Innodb_rows_updated';
    local xpath_rows_read='.Innodb_rows_read';
    local xpath_com_insert='.Com_insert';
    local xpath_com_update='.Com_update';
    local xpath_com_find='.Com_select';

    if [[ "${protocol}" == "mongodb" ]]; then {
        xpath_rows_inserted='.document.inserted."$numberLong"';
        xpath_rows_updated='.document.updated."$numberLong"';
        xpath_rows_read='.document.returned."$numberLong"';
        xpath_com_insert='.commands.insert.total."$numberLong"';
        xpath_com_update='.commands.update.total."$numberLong"';
        xpath_com_find='.commands.find.total."$numberLong"'; 
    } fi;


    local stats_t0="$(get_db_stats_dir "${test_id}")/stats_t0.json";
    local stats_t1="$(get_db_stats_dir "${test_id}")/stats_t1.json";
    
    local rows_inserted_t0=$(jq -c "${xpath_rows_inserted} | tonumber"  < "${stats_t0}");  
    local rows_inserted_t1=$(jq -c "${xpath_rows_inserted} | tonumber"  < "${stats_t1}");

    local rows_updated_t0=$(jq -c "${xpath_rows_updated} | tonumber"  < "${stats_t0}");  
    local rows_updated_t1=$(jq -c "${xpath_rows_updated} | tonumber"  < "${stats_t1}");

    local rows_read_t0=$(jq -c "${xpath_rows_read} | tonumber"  < "${stats_t0}");  
    local rows_read_t1=$(jq -c "${xpath_rows_read} | tonumber"  < "${stats_t1}");

    local com_insert_t0=$(jq -c "${xpath_com_insert} | tonumber"  < "${stats_t0}");
    local com_insert_t1=$(jq -c "${xpath_com_insert} | tonumber"  < "${stats_t1}");

    local com_update_t0=$(jq -c "${xpath_com_update} | tonumber"  < "${stats_t0}");
    local com_update_t1=$(jq -c "${xpath_com_update} | tonumber"  < "${stats_t1}");

    local com_find_t0=$(jq -c "${xpath_com_find} | tonumber"  < "${stats_t0}");
    local com_find_t1=$(jq -c "${xpath_com_find} | tonumber"  < "${stats_t1}");

    local rows_inserted=$((rows_inserted_t1 - rows_inserted_t0));
    local rows_updated=$((rows_updated_t1 - rows_updated_t0));
    local rows_read=$((rows_read_t1 - rows_read_t0 - rows_updated - rows_inserted));

    local com_insert=$((com_insert_t1 - com_insert_t0));
    local com_update=$((com_update_t1 - com_update_t0));
    local com_find=$((com_find_t1 - com_find_t0));
    
    # TODO: separate render...?
    echo_yellow "TEST: ${TEST_UUID}/${test_id}";
    echo_yellow "INSERTED: ${rows_inserted} in ${com_insert} operations";
    echo_yellow "UPDATED: ${rows_updated} in ${com_update} operations";
    echo_yellow "READ: ${rows_read} in ${com_find} operations";

}


function get_db_stats_mongodb() {
    $MONGO --eval 'JSON.stringify(db.serverStatus().metrics)';
}

function get_db_stats_mysql() {
    local sql="
    SELECT JSON_OBJECTAGG(variable_name, variable_value) AS status_json 
      FROM (
       SELECT REPLACE(EVENT_NAME, 'statement/sql/', 'Com_') AS variable_name, COUNT_STAR AS variable_value FROM performance_schema.events_statements_summary_global_by_event_name WHERE EVENT_NAME = 'statement/sql/insert' OR EVENT_NAME='statement/sql/select' OR EVENT_NAME='statement/sql/delete' OR EVENT_NAME='statement/sql/update'
       UNION 
       SELECT variable_name, variable_value FROM performance_schema.global_status WHERE variable_name LIKE 'innodb_rows_%' OR variable_name LIKE 'handler_%'
      ) AS union_status";


    $MYSQL --raw -BNe "${sql}";
}

function get_db_stats() {
    local protocol="${1}";
    case "${protocol}" in
        "mysql" | "xcom")   get_db_stats_mysql;    ;;
        "mongodb") get_db_stats_mongodb;  ;;
    esac;
}

function get_db_stats_dir() {
    local test_id="${1}";
    local db_stats_dir="${WORKDIR}/db_stats/${TEST_UUID}/${test_id}";
    mkdir -p "${db_stats_dir}" 1>/dev/null;
    echo "${db_stats_dir}";
}

function save_db_stats() {
    local protocol="${1}";
    local test_id="${2}";
    local t=${3}; # t0 or t1
    local db_stats_file="$(get_db_stats_dir "${test_id}")/stats_${t}.json";
    touch "${db_stats_file}";
    get_db_stats "${protocol}" > "${db_stats_file}";
}


function check_rows_count_mysql() {
    ${MYSQL} -BNe "SELECT COUNT(*) FROM test.companies;";
}

function check_rows_count_xcom() {
    check_rows_count_mysql;
}

function check_rows_count_mongodb() {
    ${MONGOSH} --eval 'db.companies.countDocuments()';
}

