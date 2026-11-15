## Build settings for wkb-collab, run by the editor's build (src/wkbbuild.nims)
## with `nim e`; it prints `wkb-build:` directives (see there).
##
## nim-tuntox (github.com/lf-araujo/nim-tuntox) is the in-process Tox tunnel
## behind the collab channel. Its toxcore binding asks pkg-config for
## c-toxcore at compile time, so the usual installs are made visible even when
## the shell that launched the editor didn't export PKG_CONFIG_PATH.
## nim-tuntox is found at $WKB_TUNTOX_DIR, beside this package or the editor
## checkout, or as an installed nimble package (`nimble install -d` here
## installs it). The tunnel is built (`wkbTox`) when nim-tuntox AND a
## pkg-config-visible toxcore are both here; without them collab is LAN /
## host:port only (src/wkbtox.nim). WKB_REQUIRE_TOX=1 (and macOS) make a
## missing tunnel an error; -d:wkbNoTox on the editor build leaves it out.
import std/[os, strutils]

let pkgDir = getEnv("WKB_PKG_DIR", thisDir())
let wkbRoot = getEnv("WKB_ROOT")

proc tuntoxSrc(dir: string): string =
  ## The dir holding tuntox.nim for a checkout (src/) or an installed package.
  if fileExists(dir & "/src/tuntox.nim"): dir & "/src"
  elif fileExists(dir & "/tuntox.nim"): dir
  else: ""

let tuntoxDir = block:
  var found = ""
  if getEnv("WKB_TUNTOX_DIR").len > 0: found = getEnv("WKB_TUNTOX_DIR")
  else:
    for sibling in [pkgDir & "/../nim-tuntox", wkbRoot & "/../nim-tuntox"]:
      if found.len == 0 and tuntoxSrc(sibling).len > 0: found = sibling
  if found.len == 0:
    let nimbleDir = if getEnv("NIMBLE_DIR").len > 0: getEnv("NIMBLE_DIR")
                    else: getHomeDir() & ".nimble"
    # several installs (each `nimble install` of a changed checkout adds a
    # new tuntox-<ver>-<hash> dir): take the most recently installed one
    var newest = ""
    if dirExists(nimbleDir & "/pkgs2"):
      for d in listDirs(nimbleDir & "/pkgs2"):
        if d.extractFilename.startsWith("tuntox-") and tuntoxSrc(d).len > 0:
          let stamp = gorge("stat -f %m " & quoteShell(d) & " 2>/dev/null || stat -c %Y " &
                            quoteShell(d)).strip
          if newest.len == 0 or stamp.parseInt > newest.parseInt:
            newest = stamp; found = d
  if found.len == 0: found = pkgDir & "/../nim-tuntox"   # for the error text
  found

let tuntoxPath = tuntoxSrc(tuntoxDir)
if tuntoxPath.len > 0: echo "wkb-build: path ", tuntoxPath

var pcFound = ""
if getEnv("PKG_CONFIG_PATH").len == 0:
  for pc in [getHomeDir() & ".local/lib64/pkgconfig",
             getHomeDir() & ".local/lib/pkgconfig",
             tuntoxDir & "/vendor/lib64/pkgconfig"]:
    # skip a .pc whose prefix is not on this machine (the vendored toxcore is
    # a Linux build; on macOS brew's pkg-config finds toxcore)
    let tox = pc & "/toxcore.pc"
    if fileExists(tox):
      var prefix = ""
      for line in readFile(tox).splitLines:
        if line.startsWith("prefix="): prefix = line[7 .. ^1]
      if prefix.len > 0 and not dirExists(prefix): continue
    if dirExists(pc):
      pcFound = pc
      echo "wkb-build: env PKG_CONFIG_PATH=", pc   # for the compile (tuntox asks pkg-config)
      break

let pcEnv = if pcFound.len > 0 and not defined(windows):
              "PKG_CONFIG_PATH=" & quoteShell(pcFound) & " " else: ""
if tuntoxPath.len > 0 and gorgeEx(pcEnv & "pkg-config --exists toxcore").exitCode == 0:
  echo "wkb-build: define wkbTox"
elif defined(macosx) or getEnv("WKB_REQUIRE_TOX") == "1":
  echo "wkb-build: error the Tox tunnel is required on this build but unavailable: " &
    "need nim-tuntox (at " & tuntoxDir & ", $WKB_TUNTOX_DIR, or `nimble install -d` in " &
    "wkb-collab) and toxcore via pkg-config. Build with -d:wkbNoTox to leave it out."
