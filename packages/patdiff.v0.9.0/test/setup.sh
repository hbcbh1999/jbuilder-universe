#!/bin/bash

export HERE=$(readlink -f $(dirname $0))
export PATH="$(readlink -f $HERE/../bin/):$PATH"

function visible_colors {
    $HERE/visible-colors.sh
}

export -f visible_colors

function start_test {
    set -u -o pipefail
}

export -f start_test
