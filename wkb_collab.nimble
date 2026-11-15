# wkb-collab -- a wkbenchless package. Install it with the editor's
# package-install; this file only lists the nimble libraries it needs.
version       = "0.1.0"
author        = "Luis F. Araujo"
description   = "wkbenchless package: P2P collaborative editing over Tox"
license       = "MIT"
requires "nim >= 2.0.0"
requires "https://github.com/lf-araujo/nim-tuntox"  # the Tox tunnel; built only where pkg-config finds c-toxcore
