TERMUX_PKG_HOMEPAGE=https://proot-me.github.io/
TERMUX_PKG_DESCRIPTION="Emulate chroot, bind mount and binfmt_misc for non-root users"
TERMUX_PKG_LICENSE="GPL-2.0"

_COMMIT=1f4ec1c9d3fcc5d44c2a252eda6d09b0c24928cd
TERMUX_PKG_VERSION=5.1.107
TERMUX_PKG_REVISION=25
TERMUX_PKG_SRCURL=https://github.com/termux/proot/archive/${_COMMIT}.zip
TERMUX_PKG_SHA256=1119f1d27ca7a655eb627ad227fbd9c7a0343ea988dad3ed620fd6cd98723c20
TERMUX_PKG_DEPENDS="libtalloc-static"

termux_step_pre_configure() {
  CPPFLAGS+=" -DARG_MAX=131072"
  LDFLAGS+=" -static"

  # ------------------------------------------------------------
  # FIX 1 (Solution 1): disable stripping loader.exe (llvm-strip OOM)
  # FIX 2 (Required): remove any -Ttext=0x... from linker flags (x86_64 "File too large")
  #
  # We patch recursively to avoid missing the real file (src/GNUmakefile, loader/*, etc.)
  # ------------------------------------------------------------

  cd "$TERMUX_PKG_SRCDIR"

  # 1) Disable: llvm-strip loader.exe  (comment it out anywhere)
  # 2) Remove: -Ttext=0x... (with or without surrounding commas)
  #    Examples handled:
  #      , -Ttext=0x600...,
  #      ,-Ttext=0x600...,
  #      -Ttext=0x600...,
  #      -Ttext=0x600...
  #
  # Apply to all makefiles and scripts under source tree.
  find . -type f \( -name 'GNUmakefile' -o -name 'Makefile' -o -name '*.mk' -o -name '*.make' \) -print0 \
    | while IFS= read -r -d '' f; do
        # Comment out llvm-strip loader.exe lines
        sed -i -E 's/^([[:space:]]*)llvm-strip([[:space:]]+loader\.exe)/\1# llvm-strip\2/g' "$f"

        # Remove -Ttext=0x... (comma-aware)
        sed -i -E 's/([,[:space:]])-Ttext=0x[0-9A-Fa-f]+([,[:space:]])/\1\2/g' "$f"
        sed -i -E 's/([,[:space:]])-Ttext=0x[0-9A-Fa-f]+/\1/g' "$f"
        sed -i -E 's/-Ttext=0x[0-9A-Fa-f]+([,[:space:]])/\1/g' "$f"
        sed -i -E 's/-Ttext=0x[0-9A-Fa-f]+//g' "$f"
      done

  # Clean up any accidental double commas from removals: ",," -> ","
  find . -type f \( -name 'GNUmakefile' -o -name 'Makefile' -o -name '*.mk' -o -name '*.make' \) -print0 \
    | while IFS= read -r -d '' f; do
        sed -i -E 's/,,+/,/g' "$f"
      done
}

termux_step_make_install() {
  cd "$TERMUX_PKG_SRCDIR/src"

  sed -i 's/P_tmpdir/"\/tmp"/g' path/temp.c

  make V=1
  make install

  # Strip main binary only (ok)
  $STRIP proot

  # Optional copy (kept from your script)
  mkdir -p /home/builder/termux-packages || true
  cp proot /home/builder/termux-packages || true
}
