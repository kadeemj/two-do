#!/bin/sh
set -euo pipefail

# Optional hook before xcodebuild. Smoke-test env flags match TwoDoUITests hooks
# (see TwoDoApp.swift / GoogleCalendarEventsService.swift).

export TWODO_SMOKE_TEST="${TWODO_SMOKE_TEST:-1}"
export TWODO_SMOKE_CAL="${TWODO_SMOKE_CAL:-1}"

echo "ci_pre_xcodebuild: TWODO_SMOKE_TEST=$TWODO_SMOKE_TEST TWODO_SMOKE_CAL=$TWODO_SMOKE_CAL"
echo "ci_pre_xcodebuild: ok"
