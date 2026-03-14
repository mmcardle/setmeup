#!/usr/bin/env bats

setup() {
    load test_helper
    require_setup
}

@test "interactive shell output is clean (no background noise)" {
    run bash -ic 'sleep 2; echo CLEAN_TEST_MARKER; exit'
    echo "$output" | grep -qx 'CLEAN_TEST_MARKER'
}
