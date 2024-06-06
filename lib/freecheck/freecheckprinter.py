#!/usr/bin/env python3

# FreeCheck 0.4.0
# See AUTHORS.md and LICENSE for GPL 2.0/AGPL 3.0 copyright and license.

import os
import tomllib
import re
from importlib import resources as impresources
from . import postscript as postscript_files

ps_dir = impresources.files(postscript_files)

# This tells us how to format the strings from the cfg file
# so we can print it as a PostScript definition
# The key read will replace "value" for each of these
# Strings are enclosed in parentheses	(String)	(Foobar)
# Fonts are preceded by a "/"		/FontName	/Arial
# Digits are fine as they are		Digit		123
# Booleans are fine too			Bool		true
# But to be safe, do digits and bools as subroutines:
# Subroutines are in {}			{subr}		{3 mul}

# Formats have been moved to postscript_data.ps

formats_filename = ps_dir / "freecheck_formats.ps"
header_filename = ps_dir / "freecheck_header.ps"
program_filename = ps_dir / "freecheck_program.ps"


class FreeCheckPrinter:
    @staticmethod
    def check_routing_number(micr, fraction):
        # First 4 figits is routing symbol and next 4 digits is institution number.
        routing_number = micr[1:10]
        routing_symbol = routing_number[0:4]
        institution = routing_number[4:8]
        # Remove up to one leading zero from the routing symbol.
        routing_symbol = re.sub(r"^0", "", routing_symbol)
        # Remove one or more leading zeroes from the institution number.
        institution = re.sub(r"^0+", "", institution)
        # Expected format is "any two digits-institution number/routing symbol".
        expected_fraction = f"-{institution}/{routing_symbol}"
        if fraction[2:] != expected_fraction:
            raise ValueError(
                f"For the routing number '{routing_number}', the expected routing fraction was '##{expected_fraction}' (where ## is any two numbers), but the configured one was '{fraction}'."
            )

        if len(micr) != 11:
            raise ValueError(
                "The routing number MICR should be exactly 11 characters long; 9 digits with an 'R' at start end."
            )
        if micr[0] != "R" or micr[-1:] != "R":
            raise ValueError("The routing number MICR must start and end with 'R's.")

        cksum = 0
        weights = [3, 7, 1, 3, 7, 1, 3, 7]
        for i in range(0, 8):
            cksum = cksum + weights[i] * int(routing_number[i : i + 1])
        cksum = 10 - (cksum % 10)
        cksum = cksum % 10
        if cksum != int(routing_number[8:9]):
            raise ValueError(
                f"The routing number '{routing_number}' has an invalid checksum and is not correct."
            )

    def set_args(self, args):
        self.args = args

    def load_config(self):
        self.conf = tomllib.load(self.args.conf)
        if "Global" not in self.conf:
            raise ValueError("No [Global] section found in configuration file.")
        if self.args.account not in self.conf["Account"]:
            raise ValueError(
                f"Account '{self.args.account}' not found in configuration file."
            )
        if self.args.checktype not in self.conf["CheckBlank"]:
            raise ValueError(
                f"Check type '{self.args.checktype}' not found in configuration file."
            )
        if self.args.checkstyle not in self.conf["Style"]:
            raise ValueError(
                f"Style '{self.args.checkstyle}' not found in configuration file."
            )

    def show_options(self):
        if self.args.showaccounts:
            print("Accounts:")
            print("\n".join(["\t" + k for k in self.conf["Account"]]))
        if self.args.showstyles:
            print("Check Styles:")
            print("\n".join(["\t" + k for k in self.conf["CheckBlank"]]))
        if self.args.showblanks:
            print("Check Types:")
            print("\n".join(["\t" + k for k in self.conf["Style"]]))

    def load_format(self, d):
        if not hasattr(self, "format"):
            self.format = {}
        for k, v in d.items():
            self.format[k] = v

    def set_format(self):
        for x in [
            self.conf["Global"],
            self.conf["Account"][self.args.account],
            self.conf["CheckBlank"][self.args.checktype],
            self.conf["Style"][self.args.checkstyle],
        ]:
            self.load_format(x)

        if self.args.checknum:
            self.format["CheckNumber"] = self.args.checknum

        if self.args.pages:
            self.format["NumPages"] = self.args.pages

        if self.args.nomicr:
            self.format["PrintMICRLine"] = "false"

        if self.args.nobody:
            self.format["PrintCheckBody"] = "false"

        if self.args.test:
            self.format["PrintVOID"] = "true"
        else:
            self.format["PrintVOID"] = "false"

        if not re.match(r"R[0-9]+R", self.format["Routing"]):
            raise ValueError(
                "Error: routing number must be numeric, with an 'R' on each end."
            )

        if not re.match(r"[0-9\-CPS]*", self.format["AuxOnUs"]):
            raise ValueError(
                "Error: auxiliary on-us field may only be numbers, '-', or MICR symbols 'C', 'P', and 'S'."
            )

        if not re.match(r"[0-9]+", self.format["CheckNumber"]):
            raise ValueError("Error: check number must be numeric")

        if not re.match(r"[0-9]+", self.format["NumPages"]):
            raise ValueError("Error: number of pages must be numeric")

        if not re.match(
            r"[0-9]{2}\s*\-\s*[0-9]{1,4}\s*\/\s*[0-9]{3,4}", self.format["Fraction"]
        ):
            raise ValueError(
                "Error: routing fraction must be numeric and have a '-' in the numerator"
            )

        if self.format["CheckLayout"] not in ["Original", "QStandard", "QWallet"]:
            raise ValueError(
                "Error: check layout must be 'Original', 'QStandard', or 'QWallet'"
            )

        self.check_routing_number(self.format["Routing"], self.format["Fraction"])

    def generate_postscript(self):
        lines = []

        with header_filename.open("rt") as f:
            lines += [x.rstrip() for x in f]

        with formats_filename.open("rt") as f:
            lineno = 0
            for x in f:
                lineno += 1
                x = x.rstrip()
                stripped_x = x.lstrip()
                if stripped_x == "" or stripped_x[0] == "%":
                    pass
                elif stripped_x[0].isalpha:
                    words = stripped_x.split()
                    if len(words) != 2:
                        raise ValueError(
                            f"{formats_filename}:{lineno}: Invalid syntax; definitions must contain exactly 2 words: the definition name and the type."
                        )
                    if words[0] not in self.format:
                        # Comment out undefined fields.
                        if x[0] not in [" ", "\t"]:
                            x = "% " + x
                        elif x[0:2] == "  ":
                            x = "%" + x[1:]
                        else:
                            x = "%" + x
                    else:
                        stripped = x[0 : len(x) - len(stripped_x)] + "/"
                        # Printable text
                        if words[1] == "(value)":
                            # Simplistically escape (, ), and \
                            answer = (
                                self.format[words[0]]
                                .replace("\\", "\\\\")
                                .replace("(", "\\(")
                                .replace(")", "\\)")
                            )
                            x = stripped + x[:-6] + answer + x[-1:]
                        # Reference (usually to a font)
                        elif words[1] == "/value":
                            x = stripped + x[:-5] + self.format[words[0]]
                        # Parameter list (usually a set of coordinates), or
                        # Subroutine (often just an integer of a size in points or inches)
                        elif words[1] == "[value]" or words[1] == "{value}":
                            x = stripped + x[:-6] + self.format[words[0]] + x[-1:]
                        else:
                            raise ValueError(
                                f"{formats_filename}:{lineno}: Definition type of 'f{words[1]}' for 'f{words[0]}' is not valid."
                            )
                        x += " def"
                else:
                    raise ValueError(
                        f"{formats_filename}:{lineno}: Invalid syntax; lines must be blank, a comment starting with %, or contain a definition."
                    )
                lines += [x]

        with program_filename.open("rt") as f:
            lines += [x.rstrip() for x in f]

        lines += ["%%EOF"]

        return lines
