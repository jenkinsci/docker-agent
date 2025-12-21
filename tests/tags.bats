#!/usr/bin/env bats

load test_helpers

SUT_DESCRIPTION="tags"

@test "[${SUT_DESCRIPTION}] Default Linux tags unchanged" {
  assert_matches_golden expected_tags_linux make --silent tags-linux
}

@test "[${SUT_DESCRIPTION}] 'ON_TAG' Linux tags unchanged" {
  assert_matches_golden expected_tags_linux_on_tag make --silent tags-linux ON_TAG=true
}

@test "[${SUT_DESCRIPTION}] Default Windows tags unchanged" {
  assert_matches_golden expected_tags_windows make --silent tags-windows
}

@test "[${SUT_DESCRIPTION}] 'ON_TAG' Windows tags unchanged" {
  assert_matches_golden expected_tags_windows_on_tag make --silent tags-windows ON_TAG=true
}
