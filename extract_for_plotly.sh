#!/bin/bash

source "$(dirname $(readlink -f $0))/benchmark.env.sh";
source ${BASEDIR}/benchmark.common.sh;

if [[ $# < 1 ]]; then {
    extract_latest_for_plotly;
} else {
    uuid="${1}";
    extract_for_plotly "${uuid}";
} fi;