# ASUS ROG controls delegated to the vendored controller.  The controller
# performs all range checks and feature detection before it touches firmware.
ASUS_CONTROL="$OMASETTINGS_BIN_DIR/asus-g16-control"

asus_state() {
  [[ -x $ASUS_CONTROL ]] || { echo '{"available":false}'; return; }
  capture bash "$ASUS_CONTROL" state || echo '{"available":false}'
}

asus_cmd() {
  [[ -x $ASUS_CONTROL ]] || die "ASUS controls are not installed"
  bash "$ASUS_CONTROL" "$@"
}
