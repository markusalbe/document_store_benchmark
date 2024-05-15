#!/bin/bash

source "$(dirname $(readlink -f $0))/benchmark.common.sh";

while true; do {
    clear;
    show_latest_results;
    sleep 2;
} done;


