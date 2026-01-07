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
}

termux_step_make_install() {
  cd "$TERMUX_PKG_SRCDIR/src"

  # Your existing fix
  sed -i 's/P_tmpdir/"\/tmp"/g' path/temp.c

  # ------------------------------------------------------------
  # FIX (must be right before make, because build happens in src/)
  #
  # 1) Solution 1: disable stripping loader.exe (llvm-strip OOM)
  # 2) Fix x86_64 ld.lld "File too large":
  #    remove BOTH "-Ttext=0x..." and "Ttext=0x..." (split-line case)
  # ------------------------------------------------------------
  if [ -f GNUmakefile ]; then
    # disable llvm-strip loader.exe
    sed -i -E 's/^([[:space:]]*)llvm-strip([[:space:]]+loader\.exe)/\1# llvm-strip\2/g' GNUmakefile

    # remove -Ttext=0x.... (normal)
    sed -i -E 's/,-Ttext=0x[0-9A-Fa-f]+//g' GNUmakefile
    sed -i -E 's/[[:space:]]-Ttext=0x[0-9A-Fa-f]+//g' GNUmakefile

    # remove Ttext=0x.... (split-line case, no leading "-")
    sed -i -E 's/,Ttext=0x[0-9A-Fa-f]+//g' GNUmakefile
    sed -i -E 's/[[:space:]]Ttext=0x[0-9A-Fa-f]+//g' GNUmakefile

    # cleanup possible ",," after removal
    sed -i -E 's/,,+/,/g' GNUmakefile
  fi

  # Build & install
  make V=1
  make install

  # Strip main proot binary only
  $STRIP proot
  mkdir -p /home/builder/termux-packages || true
  cp proot /home/builder/termux-packages || true
}
