#!/usr/bin/env python3

# FreeCheck 0.4.0
# See AUTHORS.md and LICENSE for GPL 2.0/AGPL 3.0 copyright and license.

from . import FreeCheckPrinterMain


def test_freecheckprintermain(mocker):
    mocker.patch("sys.argv", ["freecheck.py"])
    FreeCheckPrinterMain.main()
