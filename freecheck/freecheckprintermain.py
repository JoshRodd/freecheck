#!/usr/bin/env python3

# FreeCheck 0.4.0
# See AUTHORS.md and LICENSE for GPL 2.0/AGPL 3.0 copyright and license.

import os
import sys
import argparse
import tomllib

from . import FreeCheckPrinter

FREECHECK_VERSION = "0.4.0"
DEFAULT_CONFIG_FILE = "~/.freecheck.toml"


###
# This implements a main method suitable to be called from a command
# line program. Using it is very simple:
#
# import freecheck
#
# freecheck.FreeCheckPrinterMain.main()
###
class FreeCheckPrinterMain:

    @staticmethod
    def main():
        ap = argparse.ArgumentParser(
            prog="freecheck",
            description="A free check printing utility.",
            epilog="Please see the file README.md for more information.",
        )

        ap.add_argument(
            "--version", action="version", version="%(prog)s " + f"{FREECHECK_VERSION}"
        )
        ap.add_argument(
            "--account",
            type=str,
            help="Account definition name; default is 'sample'",
            default="sample",
        )
        ap.add_argument(
            "--checknum", type=int, help="Check number optional (overrides acct file)"
        )
        ap.add_argument("--pages", type=int, help="Number of pages to print")
        ap.add_argument(
            "--checkstyle",
            type=str,
            help="Check style; default is 'Normal')",
            default="Normal",
        )
        ap.add_argument(
            "--checktype",
            type=str,
            help="Check blank definition; default is 'MVG3001'",
            default="MVG3001",
        )
        ap.add_argument(
            "--nomicr",
            help="Prevents MICR line from printing (body only)",
            action="store_true",
        )
        ap.add_argument(
            "--nobody",
            help="Prevents body from printing (MICR line only)",
            action="store_true",
        )
        ap.add_argument(
            "--showaccounts", help="Show available accounts", action="store_true"
        )
        ap.add_argument(
            "--showstyles", help="Show available check styles", action="store_true"
        )
        ap.add_argument(
            "--showblanks", help="Show available check blanks", action="store_true"
        )
        ap.add_argument(
            "--test",
            help="Print VOID on check",
            action="store_true",
        )
        default_config_file = os.path.expanduser(DEFAULT_CONFIG_FILE)
        ap.add_argument(
            "--conf",
            type=argparse.FileType("rb"),
            help=f"Change configuration file; default is '{default_config_file}'",
            default=default_config_file,
        )
        fcp = FreeCheckPrinter()
        fcp.set_args(ap.parse_args())
        try:
            fcp.load_config()
        except tomllib.TOMLDecodeError as e:
            print(f"Syntax error in configuration file:\n{e}", file=sys.stderr)
            sys.exit(1)
        except ValueError as e:
            print(f"Error in configuration file:\n{e}", file=sys.stderr)
        if fcp.show_options():
            return
        fcp.set_format()
        ps_data = fcp.generate_postscript()
        print("\n".join(ps_data))

def freecheck_run():
    FreeCheckPrinterMain.main()
