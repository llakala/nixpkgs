#!/usr/bin/env bash

# This script is used to test that the module system is working as expected.
# Executing it runs tests for `lib.modules`, `lib.options` and `lib.types`.
# By default it test the version of nixpkgs which is defined in the NIX_PATH.
#
# Run:
# [nixpkgs]$ lib/tests/modules.sh
# or:
# [nixpkgs]$ nix-build lib/tests/release.nix

set -o errexit -o noclobber -o nounset -o pipefail
shopt -s failglob inherit_errexit

# https://stackoverflow.com/a/246128/6605742
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

cd "$DIR"/modules

pass=0
fail=0

local-nix-instantiate() {
    nix-instantiate --timeout 1 --eval-only --show-trace --read-write-mode --json "$@"
}

# loc
#   prints the location of the call of to the function that calls it
# loc n
#   prints the location n levels up the call stack
loc() {
    local caller depth
    depth=1
    if [[ $# -gt 0 ]]; then
        depth=$1
    fi
    # ( lineno fnname file ) of the caller
    caller=( $(caller $depth) )
    echo "${caller[2]}:${caller[0]}"
}

line() {
    echo "----------------------------------------"
}
logStartFailure() {
    line
}
logEndFailure() {
    line
    echo
}

logFailure() {
    # bold red
    printf '\033[1;31mTEST FAILED\033[0m at %s\n' "$(loc 2)"
}

evalConfig() {
    local attr=$1
    shift

    local nix_args=()

    if [ "${ABORT_ON_WARN-0}" = "1" ]; then
        nix_args+=(--option abort-on-warn true)
    fi

    if [ "${STRICT_EVAL-0}" = "1" ]; then
        nix_args+=(--strict)
    fi

    local script="import ./default.nix { modules = [ $* ];}"
    local-nix-instantiate "${nix_args[@]}" -E "$script" -A "$attr"
}

reportFailure() {
    local attr=$1
    shift
    local script="import ./default.nix { modules = [ $* ];}"
    echo "$ nix-instantiate -E '$script' -A '$attr' --eval-only --json"
    evalConfig "$attr" "$@" || true
    ((++fail))
}

checkConfigOutput() {
    local outputContains=$1
    shift
    if evalConfig "$@" 2>/dev/null | grep -E --silent "$outputContains" ; then
        ((++pass))
    else
        logStartFailure
        echo "ACTUAL:"
        reportFailure "$@"
        echo "EXPECTED: result matching '$outputContains'"
        logFailure
        logEndFailure
    fi
}

invertIfUnset() {
    gate="$1"
    shift
    if [[ -n "${!gate:-}" ]]; then
        "$@"
    else
        ! "$@"
    fi
}

globalErrorLogCheck() {
    invertIfUnset "REQUIRE_INFINITE_RECURSION_HINT" \
      grep -i 'if you get an infinite recursion here' \
      <<<"$err" >/dev/null \
      || {
        if [[ -n "${REQUIRE_INFINITE_RECURSION_HINT:-}" ]]; then
            echo "Unexpected infinite recursion hint"
        else
            echo "Expected infinite recursion hint, but none found"
        fi
        return 1
      }
}

checkExpression() {
  local path=$1
  local output
  {
      output="$(local-nix-instantiate --strict "$path" 2>&1)" && ((++pass))
  } || {
      logStartFailure
      echo "$output"
      ((++fail))
      logFailure
      logEndFailure
  }
}

checkConfigError() {
    local errorContains=$1
    local err=""
    shift
    if err="$(evalConfig "$@" 2>&1 >/dev/null)"; then
        logStartFailure
        echo "ACTUAL: exit code 0, output:"
        reportFailure "$@"
        echo "EXPECTED: non-zero exit code"
        logFailure
        logEndFailure
    else
        if ! globalErrorLogCheck "$err"; then
            logStartFailure
            echo "LOG:"
            reportFailure "$@"
            echo "GLOBAL ERROR LOG CHECK FAILED"
            logFailure
            logEndFailure
        fi
        if echo "$err" | grep -zP --silent "$errorContains" ; then
            ((++pass))
        else
            logStartFailure
            echo "ACTUAL:"
            reportFailure "$@"
            echo "EXPECTED: error matching '$errorContains'"
            logFailure
            logEndFailure
        fi
    fi
}

checkConfigError 'The option .* does not exist. Definition values:\n\s*- In .*: true' config.enable ./disable-recursive/{main.nix,disable-foo.nix,disable-bar.nix}

cat <<EOF
====== module tests ======
$pass Pass
$fail Fail
EOF

if [ "$fail" -ne 0 ]; then
    exit 1
fi
exit 0
