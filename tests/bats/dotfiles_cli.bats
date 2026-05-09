#!/usr/bin/env bats

setup_file() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  export REPO_ROOT
}

@test "help lists the test command" {
  run "${REPO_ROOT}/bin/dotfiles" help

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"test"* ]]
  [[ "${output}" == *"Run smoke, Bats, and optional static checks"* ]]
}
