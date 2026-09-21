#!/usr/bin/bash
# Build and install the Deep bass add-on (bankstown) from one fixed upstream
# revision, in a terminal the user can watch.
#
# Nothing here asks the AUR.  The PKGBUILD next to this file names the
# upstream commit by its full hash and by the checksum of its archive, so
# makepkg fetches exactly that.  Before anything is built, this script reads
# back what was fetched and stops unless the commit and its tree are the ones
# named below; cargo then builds with the dependency set frozen to that
# commit's Cargo.lock.  The result is an ordinary package that pacman
# installs, asking for your password in this window.
set -euo pipefail

VERSION=1.1.0
COMMIT=e9829c9bccf5ed73768135c0ddd506f5a6690f9e
TREE=a8bbbb026af98053656283aed1801be3032c0876
PACKAGE=bankstown

here=$(cd -- "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")" && /usr/bin/pwd -P)

if /usr/bin/pacman -Q -- "$PACKAGE" >/dev/null 2>&1; then
  echo "$PACKAGE is already installed; nothing to build."
  exit 0
fi

# A build directory of our own under the cache, gone again afterwards.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-speaker-calibrator"
/usr/bin/mkdir -p -m 700 -- "$cache"
if [ -L "$cache" ] || [ ! -d "$cache" ] || [ ! -O "$cache" ]; then
  echo "Refusing to build under $cache: it is not a directory of ours." >&2
  exit 1
fi
build=$(/usr/bin/mktemp -d -p "$cache" build.XXXXXXXXXX)
trap '/usr/bin/rm -rf -- "$build"' EXIT
# Everything makepkg writes stays in that directory, whatever makepkg.conf says.
export BUILDDIR="$build" SRCDEST="$build" PKGDEST="$build" SRCPKGDEST="$build" LOGDEST="$build"

/usr/bin/install -m 0644 -- "$here/PKGBUILD" "$build/PKGBUILD"
cd -- "$build"

echo "Fetching $PACKAGE $VERSION at commit $COMMIT ..."
# --nobuild fetches and extracts only; makepkg checks the commit and the
# archive checksum here.  --syncdeps installs the Rust toolchain from the
# official repositories if it is missing, and asks before doing so.
/usr/bin/makepkg --nobuild --syncdeps

# What was fetched is read back before a single line is compiled.
got_commit=$(/usr/bin/git -C "$build/src/$PACKAGE" rev-parse 'HEAD^{commit}')
got_tree=$(/usr/bin/git -C "$build/src/$PACKAGE" rev-parse 'HEAD^{tree}')
if [ "$got_commit" != "$COMMIT" ] || [ "$got_tree" != "$TREE" ]; then
  echo "The fetched source is not the pinned revision (commit $got_commit, tree $got_tree); stopping." >&2
  exit 1
fi
echo "Verified: commit $got_commit, tree $got_tree."

# --noextract builds the verified checkout; nothing is fetched again.
# --install hands the finished package to pacman, which asks for your password.
/usr/bin/makepkg --noextract --install
echo "Installed $PACKAGE $VERSION. Switch Deep bass on in the panel."
