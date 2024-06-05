FreeCheck
=========
Version 0.4.0
June 5, 2025

Written by:
- Eric Sandeen, <sandeen-freecheck@sandeen.net>
- James Klicman, <james@klicman.org>
- Caleb Maclennan, <caleb@alerque.com>
- Josh Rodd, <josh@rodd.us>

READ THE "WARNING.md" FILE BEFORE YOU PROCEED!
==============================================

WHY DID YOU WRITE THIS?
-----------------------
I wanted a free alternative to MIPS/VersaCheck. 'nuff said.

REQUIREMENTS
------------
The first thing that you MUST have to be able to use FreeCheck is a
good Type 1 MICR font. I have created one, called "GnuMICR" that I think
is pretty excellent - but it has not been well tested. :) There are also
commercial fonts you can buy, if that floats your boat. See
www.bizfonts.com, for example.

You must also have either a PostScript printer, or a recent version
of GhostScript. FreeCheck generates the check as a PostScript file.
Ghostscript can be used to convert the PostScript output to a PDF file
using the ps2pdf tool.

Technically, you must also use MICR toner, but MICR toner is not generally
needed to successful negotiate a check as of 2024. At a minimum, use a real
laser printer. An inkjet printer is not recommended.

Also, you should use security blank check stock, not just plain
paper.

The repository at <https://github.com/alerque/gnumicr> contains a usable
MICR font.

INSTALLATION
------------

There isn't one. You can copy the source distribution somewhere and run it
if you prefer.

CONFIGURATION
-------------

On first run the program will copy the system default configuration file to
your home directory. From there you can edit it with your accounts and any
custom check styles or layouts.

Edit the file `~/.freecheck.cfg` to add your account information, and define
any new check blanks or styles you want.  Take a look at the [Global]
section, too, to set things up for your system. Pay close attention
to the MICR line specification instructions. Most configuration instructions
can be found in this file. If something's too confusing, let me know.

USAGE
-----
FreeCheck just generates a PostScript file to STDOUT. That means that you
must either redirect it to a file, a printer, or a viewer.

So, to print (assuming Linux or macOS CUPS, etc.):
```
./freecheck <options> | ps2pdf - | lpr
```

To view:
```
./freecheck.pl <options> | ps2pdf - output.pdf
```

and then open the `output.pdf` file.

To save a file:
```
freecheck.pl <options> | ps2pdf - | mycheckfile.ps
```

If you really want the PostScript output, simply remove the `ps2pdf`
step.

OPTIONS
-------
`freecheck` doesn't require any options, unless you want it to do something
useful. By itself, it will print a couple sheets of standard checks
with a dummy account.

Type `freecheck --help` to see what options are available

For now, if you get tired of typing all those command line options, just
edit the defaults at the top of the main script.

HOW DOES IT WORK?
-----------------
FreeCheck is a Frankenstein-like combination of PostScript, Perl, and
Python at this point. The guts of the check layout are in PostScript,
which is embedded at the end of the Perl script. This PostScript depends
on lots of variable definitions to decide what it should actually print.
That's where the Perl and Python comes in - reading a config file, and
generating lots of lines of the type

```
        /foo {bar} def
```
which define what's shown on the page.
