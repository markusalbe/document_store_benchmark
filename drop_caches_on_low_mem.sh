#!/bin/bash
function drop_caches_on_low_mem() {
    echo "Free memory:";
    vmstat -n 1 | stdbuf -o0 awk '/[0-9]/{print $4}' | while read free_memory; do {
        echo "${free_memory}";
        if  [[ "${free_memory}" -lt "1500000" ]]; then {
            if [[ "1" -eq "1" ]]; then {
                echo "dropping caches";
                echo 3 > /proc/sys/vm/drop_caches;
                echo "caches dropped!";
            } fi;
        } fi;
    } done;
} 

drop_caches_on_low_mem;

