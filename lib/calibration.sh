# The complete calibration engine is vendored in this plugin.  Keeping its
# profile and PipeWire service contract intact makes the migration lossless.
CALIBRATION_BIN="$OMASETTINGS_BIN_DIR/../audio_calibration/speaker-calibrate.py"
CALIBRATION_PYTHON="/usr/bin/python3"

calibration_state() {
  [[ -f $CALIBRATION_BIN ]] || { echo '{"available":false}'; return; }
  # The engine records detailed response curves.  They are useful to its
  # dedicated analysis view, but would make every Settings refresh enormous.
  # Keep the operational state and profile choices here instead.
  capture "$CALIBRATION_PYTHON" "$CALIBRATION_BIN" status-cache-json \
    | jq -c '{available: true, service, enabled, bypass, defaultSink,
      defaultSinkDescription, calibratedSink, deepBass, loudnessCompensation,
      loudnessTracker, verification,
      profile: (if .profile then .profile | {created_at, speaker, microphone,
        voicing, loudness, bass, channel_trim, deep_bass, loudness_compensation}
        else null end),
      compare: (.compare // {} | {available, active, bypass, level_match_db,
        current, previous}),
      bassEnhancer: (.bassEnhancer // {} | {available, installed, usable, package, path}),
      measurementSupport: (.measurementSupport // {})}' 2>/dev/null \
    || echo '{"available":false}'
}

calibration_cmd() {
  if [[ ${1:-} == open-panel ]]; then
    omarchy-shell design-nexus.settings openCalibration
    return
  fi
  [[ -f $CALIBRATION_BIN ]] || die "speaker calibration is not installed"
  "$CALIBRATION_PYTHON" "$CALIBRATION_BIN" "$@"
}
