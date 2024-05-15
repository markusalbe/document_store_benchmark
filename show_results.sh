#!/bin/bash
source "$(dirname $(readlink -f $0))/benchmark.common.sh";

if [[ "$#" > 0 ]]; then {
    show_results ${1};
} else {
    show_latest_results;
} fi;