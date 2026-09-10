#!/bin/bash

function set_up() {
  source ./src/misc.sh
  source ./src/github.sh
}

pr_number=123
files_to_ignore=''
ignore_line_deletions='false'
ignore_file_deletions='false'

function test_should_count_changes() {
  mock curl cat ./tests/fixtures/pull_request_api

  assert_equals 174 "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}

function test_should_count_changes_ignore_line_deletions() {
  ignore_line_deletions='true'

  mock curl cat ./tests/fixtures/pull_request_api

  assert_equals 173 "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}

# NOTE: when `files_to_ignore` or `ignore_file_deletions` is set, we have to invoke the PR files API and iterate each file
# one at at time. This is why the mock call is diffent in the subsequent test cases
function test_should_count_changes_ignore_file_deletions() {
  ignore_file_deletions='true'

  mock curl cat ./tests/fixtures/pull_request_files_api

  assert_equals 2779 "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}

function test_should_ignore_files_with_glob() {
  files_to_ignore=("*.lock" ".editorconfig")

  mock curl cat ./tests/fixtures/pull_request_files_api

  assert_equals 517 "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}

function test_should_ignore_files_with_glob_ignore_line_deletions() {
  files_to_ignore=("*.lock" ".editorconfig")
  ignore_line_deletions='true'

  mock curl cat ./tests/fixtures/pull_request_files_api

  assert_equals 224 "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}

function test_should_ignore_files_with_glob_ignore_file_deletions() {
  files_to_ignore=("*.lock" ".editorconfig")
  ignore_file_deletions='true'

  mock curl cat ./tests/fixtures/pull_request_files_api

  assert_equals 394 "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}

function test_should_count_changes_across_pages() {
  ignore_file_deletions='true'

  # Plain function instead of `mock`, as the response has to differ per page:
  # a full page of 100 files with 2 changes each, then the fixture as last page
  function curl() {
    case "$*" in
      *"page=1") jq -n '[range(100) | {filename: "file-\(.)", status: "modified", additions: 1, deletions: 1}]' ;;
      *"page=2") cat ./tests/fixtures/pull_request_files_api ;;
    esac
  }

  assert_equals $((200 + 2779)) "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}

function test_should_count_nothing_on_error_response() {
  ignore_file_deletions='true'

  mock curl echo '{"message": "Not Found"}'

  assert_equals 0 "$(github::calculate_total_modifications "$pr_number" "${files_to_ignore[*]}" "$ignore_line_deletions" "$ignore_file_deletions")"
}
