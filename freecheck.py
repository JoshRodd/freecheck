#!/usr/bin/env python3

# FreeCheck 0.4.0
# See AUTHORS.md and LICENSE for GPL 2.0/AGPL 3.0 copyright and license.

import os
import sys
import argparse
import tomllib
import re
from pprint import pprint

freecheck_version = "0.4.0"
default_config_file = os.path.expanduser("~/.freecheck.toml")

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

formats_filename = "freecheck_formats.ps"

# Parse command line options and deal with them:

class FreeCheckPrinterMain():
    @staticmethod
    def main():
        ap = argparse.ArgumentParser(
            prog="freecheck",
            description="A free check printing utility.",
            epilog="Please see the file README.md for more information.")

        ap.add_argument("--version", action="version", version='%(prog)s ' + f"{freecheck_version}")
        ap.add_argument("--account", type=str, help="Account definition name; default is 'sample'", default="sample")
        ap.add_argument("--checknum", type=int, help="Check number optional (overrides acct file)")
        ap.add_argument("--pages", type=int, help="Number of pages to print")
        ap.add_argument("--checkstyle", type=str, help="Check style; default is 'Normal')", default="Normal")
        ap.add_argument("--checktype", type=str, help="Check blank definition; default is 'MVG3001'", default="MVG3001")
        ap.add_argument("--nomicr", help="Prevents MICR line from printing (body only)", action="store_true")
        ap.add_argument("--nobody", help="Prevents body from printing (MICR line only)", action="store_true")
        ap.add_argument("--showaccounts", help="Show available accounts", action="store_true")
        ap.add_argument("--showstyles", help="Show available check styles", action="store_true")
        ap.add_argument("--showblanks", help="Show available check blanks", action="store_true")
        ap.add_argument("--test", help="Don't increment check n, and print VOID", action="store_true")
        ap.add_argument("--conf", type=argparse.FileType("rb"), help=f"Change configuration file; default is '{default_config_file}'", default=default_config_file)
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

class FreeCheckPrinter():
    @staticmethod
    def check_routing_number(micr, fraction):
        # First 4 figits is routing symbol and next 4 digits is institution number.
        routing_number = micr[1:10]
        routing_symbol = routing_number[0:4]
        institution = routing_number[4:8]
        # Remove up to one leading zero from the routing symbol.
        routing_symbol = re.sub(r'^0', '', routing_symbol)
        # Remove one or more leading zeroes from the institution number.
        institution = re.sub(r'^0+', '', institution)
        # Expected format is "any two digits-institution number/routing symbol".
        expected_fraction = f"-{institution}/{routing_symbol}"
        if fraction[2:] != expected_fraction:
            raise ValueError(f"For the routing number '{routing_number}', the expected routing fraction was '##{expected_fraction}' (where ## is any two numbers), but the configured one was '{fraction}'.")

        if len(micr) != 11:
            raise ValueError("The routing number MICR should be exactly 11 characters long; 9 digits with an 'R' at start end.")
        if micr[0] != 'R' or micr[-1:]:
            raise ValueError("The routing number MICR must start and with 'R's.")

        cksum = 0
        weights = [3, 7, 1, 3, 7, 1, 3, 7]
        for i in range(0, 8):
            cksum = cksum + weights[i] * int(routing_number[i:i + 1])
        cksum = (10 - (chksum % 10)) % 10
        if cksum != int(micr[8:9]):
            raise ValueError(f"The routing number '{routing_number}' has an invalid checksum and is not correct.")

    def set_args(self, args):
        self.args = args

    def load_config(self):
        self.conf = tomllib.load(self.args.conf)
        if 'Global' not in self.conf:
            raise ValueError("No [Global] section found in configuration file.")
        if self.args.account not in self.conf['Account']:
            raise ValueError(f"Account '{self.args.account}' not found in configuration file.")
        if self.args.checktype not in self.conf['CheckBlank']:
            raise ValueError(f"Check type '{self.args.checktype}' not found in configuration file.")
        if self.args.checkstyle not in self.conf['Style']:
            raise ValueError(f"Style '{self.args.checkstyle}' not found in configuration file.")

    def show_options(self):
        if self.args.showaccounts:
            print("Accounts:")
            print("\n".join(['\t' + k for k in self.conf['Account']]))
        if self.args.showstyles:
            print("Check Styles:")
            print("\n".join(['\t' + k for k in self.conf['CheckBlank']]))
        if self.args.showblanks:
            print("Check Types:")
            print("\n".join(['\t' + k for k in self.conf['Style']]))

    def load_format(self, d):
        if not hasattr(self, 'format'):
            self.format = {}
        for k, v in d.items():
            self.format[k] = v

    def set_format(self):
        for x in [
            self.conf['Global'],
            self.conf['Account'][self.conf.account],
            self.conf['CheckBlank'][self.conf.checktype],
            self.conf['Style'][self.conf.checkstyle]
        ]:
            self.load_format(x)

        if self.args.checknum:
            self.format['CheckNumber'] = self.args.checknum

        if self.args.pages:
            self.format['NumPages'] = self.args.pages

        if self.args.nomicr:
            self.format['PrintMICRLine'] = "false"

        if self.args.nobody:
            self.format['PrintCheckBody'] = "false"

        if self.args.test:
            self.format['PrintVOID'] = "true"
        else:
            self.format['PrintVOID'] = "false"

        if not re.match(r"R[0-9]+R", self.format['Routing']):
            raise ValueError("Error: routing number must be numeric, with an 'R' on each end.")

        if not re.match(r"[0-9\-CPS]*", self.format['AuxOnUs']):
            raise ValueError("Error: auxiliary on-us field may only be numbers, '-', or MICR symbols 'C', 'P', and 'S'.")

        if not re.match(r"[0-9]+", self.format['CheckNumber']):
            raise ValueError("Error: check number must be numeric")

        if not re.match(r"[0-9]+", self.format['NumPages']):
            raise ValueError("Error: number of pages must be numeric")

        if not re.match(r"[0-9]{2}\s*\-\s*[0-9]{1,4}\s*\/\s*[0-9]{3,4}", self.format['Fraction']):
            raise ValueError("Error: routing fraction must be numeric and have a '-' in the numerator")

        if self.format['CheckLayout'] not in ['Original', 'QStandard', 'QWallet']:
            raise ValueError("Error: check layout must be 'Original', 'QStandard', or 'QWallet'")

        self.check_routing_number(self.format['Routing'], self.format['Fraction'])

#
#if (defined $Definitions{'LogoFile'}) {
#    if (open(EPS,"<$Definitions{'LogoFile'}")) {
#        my $foundbbox = 0;
#        while (<EPS>) {
#            break if /^%%EndComments/;
#            next unless s/^%%((?:HiRes)?BoundingBox):\s*//;
#            my $hires = ($1 eq 'HiResBoundingBox');
#            $foundbbox = 1;
#            if (/^(\d+(?:\.\d+)?(?:\s+\d+(?:\.\d+)?){3})\s*(?:%.*)?$/) {
#                $Definitions{'LogoBBox'} = $1;
#            } else {
#                $error .= "Error - Can't parse EPS Logo BoundingBox comment\n";
#            }
#            # keep looking until HiResBoundingBox or EndComments
#            break if $hires;
#        }
#        close(EPS);
#
#        unless ($foundbbox) {
#            $error .= "Error - Required EPS Logo BoundingBox not found\n";
#        }
#    } else {
#        $error .= "Error - Can't open LogoFile $Definitions{'LogoFile'}: $!\n";
#    }
#}
#
#if (defined $Definitions{'BankLogoFile'}) {
#    if (open(EPS,"<$Definitions{'BankLogoFile'}")) {
#        my $foundbbox = 0;
#        while (<EPS>) {
#            break if /^%%EndComments/;
#            next unless s/^%%((?:HiRes)?BoundingBox):\s*//;
#            my $hires = ($1 eq 'HiResBoundingBox');
#            $foundbbox = 1;
#            if (/^(\d+(?:\.\d+)?(?:\s+\d+(?:\.\d+)?){3})\s*(?:%.*)?$/) {
#                $Definitions{'BankLogoBBox'} = $1;
#            } else {
#                $error .= "Error - Can't parse EPS Logo BoundingBox comment\n";
#            }
#            # keep looking until HiResBoundingBox or EndComments
#            break if $hires;
#        }
#        close(EPS);
#
#        unless ($foundbbox) {
#            $error .= "Error - Required EPS Logo BoundingBox not found\n";
#        }
#    } else {
#        $error .= "Error - Can't open LogoFile $Definitions{'BankLogoFile'}: $!\n";
#    }
#}
#
## die() if we got errors
#if ( $error && !$opt_test ) {
#	print STDERR $error;
#	die("Errors Encountered\n");
#}
#
## Print PostScript
#
## Initial stuff:

# Splurt out 'freecheck_program_header.ps' here.

# Splurt out 'freecheck_formats.ps' here (after substitutions).

# Logo specific stuff.
#if (defined $Definitions{'LogoFile'}) {
#    my $filesize = (stat($Definitions{'LogoFile'}))[7];
#    print <<"__END_OF_POSTSCRIPT__";
#%%BeginProcSet: logo
#%%Creator: James Klicman <james\@klicman.org>
#%%CreationDate: October 2002
#%%Version: 0.3
#
#% if
#/LogoPadding where
#{
#    pop % discard dict
#}
#% else
#{
#    /LogoPadding 0 def
#}
#ifelse
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#%
#% Calculate LogoMatrix
#%
#% LogoXScale
#LogoWidth LogoPadding 2 mul sub
#% BBWidth
#    LogoBBox 2 get % x2
#    LogoBBox 0 get % x1
#    sub % x2 x1 sub
#div % LogoWidth BBWidth div
#% LogoYScale
#LogoHeight LogoPadding 2 mul sub
#% BBHeight
#    LogoBBox 3 get % y2
#    LogoBBox 1 get % y1
#    sub % y2 y1 sub
#div % LogoHeight BBHeight div
#
#% if
#2 copy lt % LogoXScale LogoYScale lt
#{
#    pop % discard LogoYScale
#}
#% else
#{
#    exch pop % discard LogoXScale
#}
#ifelse
#% ^ (LogoXScale < LogoYScale ? LogoXScale : LogoYScale)
#dup matrix scale /LogoMatrix exch def
#
#/DrawLogo {
#    /LogoForm where {
#        pop % discard dict
#        gsave
#
#        % Don't draw a border for the logo anymore.
#        % /LogoBorder where {
#        %     pop % discard dict
#        %     newpath
#        %     LeftMargin LogoBorder 2 div add
#        %     CheckHeight TopMargin sub LogoBorder 2 div sub  moveto
#
#        %     LogoWidth LogoBorder sub 0 rlineto
#        %     0 LogoHeight LogoBorder sub neg rlineto
#        %     LogoWidth LogoBorder sub neg 0 rlineto
#        %     closepath
#        %     LogoBorder setlinewidth stroke
#        % } if
#        
#
#        % Logo is placed at the top-left corner of the check
#        LeftMargin  CheckHeight TopMargin sub  translate
#
#        LogoForm /BBox get aload pop % ^ llx lly urx ury
#
#        % translate top-left corner of LogoBBox to current point
#        % ^ llx lly urx ury
#        3 index neg % llx neg  ^ llx lly urx ury -llx
#        1 index neg % ury neg  ^ llx lly urx ury -llx -ury
#        LogoForm /Matrix get
#        transform % -llx -ury LogoMatrix transform
#        translate % transformedX transformedY translate
#
#        % calculate real width and height of LogoBBox
#        % ^ llx lly urx ury
#        exch      % ^ llx lly ury urx
#        4 -1 roll % ^ lly ury urx llx
#        sub % urx llx sub ^ lly ury urx-llx
#        3 -2 roll % ^ urx-llx lly ury 
#        exch      % ^ urx-llx ury lly 
#        sub % ury lly sub 
#        % ^ urx-llx ury-lly
#        LogoForm /Matrix get
#        transform % urx-llx ury-lly LogoMatrix transform
#        % ^ RealLogoWidth RealLogoHeight
#
#        % Calculate difference of RealLogoWidth, RealLogoHeight
#        % and LogoWidth, LogoHeight for centering logo.
#        exch LogoWidth exch sub 2 div
#        exch LogoHeight exch sub 2 div neg
#        translate % LogoHAlign LogoVAlign translate
#
#        % LogoForm execform
#
#        grestore
#    } if
#} def
#%%EndProcSet
#
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
#
#%
#% The following EPS Form handling code is based on code contained in
#% Adobe Technical Note #5144 Using EPS Files in PostScript Language Forms.
#%
#
#%%BeginResource: procset forms_ops 1.0 0
#%%Title: (Forms Operators)
#%%Version: 1.0
#userdict /forms_ops 10 dict dup begin put
#
#/StartEPSF { % prepare for EPSF inclusion
#    userdict begin
#    /PreEPS_state save def
#    /dict_stack countdictstack def
#    /ops_count count 1 sub def
#    /showpage {} def
#} bind def
#
#/EPSFCleanUp { % clean up after EPSF inclusion
#    count ops_count sub {pop} repeat
#    countdictstack dict_stack sub {end} repeat
#    PreEPS_state restore
#    end % userdict
#} bind def
#
#/STRING_SIZE 16000 def % Best value to not fragment printer's VM
#% recommended ARRAY_SIZE = filesize/16000 + 2
#% +2 resulted in errors
#% +3 worked
#/ARRAY_SIZE $filesize 16000 idiv 3 add def
#
#% for initial counter and final empty string.
#/buffer STRING_SIZE string def
#/inputFile currentfile 0 (% EOD_Marker_$$) /SubFileDecode filter def
#
#/readdata { % array readdata --
#    1 { % put counter on stack
#        % stack: array counter
#        2 copy % stack: array counter array counter
#        inputFile buffer readstring % read contents of currentfile into buffer
#        % stack: array counter array counter string boolean
#        4 1 roll % put boolean indicating EOF lower on stack
#        STRING_SIZE string copy % copy buffer string into new string
#        % stack: array counter boolean array counter newstring
#        put % put string into array
#        not {exit} if % if EOF has been reached, exit loop.
#        1 add % increment counter
#    } loop
#    % increment counter and place empty string in next position
#    1 add 2 copy () put pop
#    currentglobal true setglobal exch
#    0 1 array put % create an array for counter in global VM,
#    % so as not to be affected by save/restore calls in EPS file.
#    % place as first element of string array.
#    setglobal % restore previously set value
#} bind def
#currentdict readonly pop end
#%%EndResource
#%%EndProlog
#%%BeginSetup
#% set MaxFormItem to be equivalent to MaxFormCache
#<< /MaxFormItem currentsystemparams /MaxFormCache get >> setuserparams
#% make forms procset available
#forms_ops begin
#userdict begin
#% download form resource
#%%BeginResource: form LogoForm
#/LogoForm
#    10 dict begin
#        /FormType 1 def
#        /EPSArray ARRAY_SIZE array def
#        /AcquisitionProc {
#            EPSArray dup 0 get dup 0 get % array counter_array counter
#            dup 3 1 roll % array counter counter_array counter
#            1 add 0 exch put % increment counter
#            get % use old counter as index into array, placing
#            % next string on operand stack.
#        } bind def
#        /PaintProc {
#            begin
#                StartEPSF
#                % May want to translate here, prior to executing EPS
#                EPSArray 0 get 0 1 put
#                //AcquisitionProc 0 () /SubFileDecode filter
#                cvx exec
#                EPSFCleanUp
#            end
#        } bind def
#        /Matrix //LogoMatrix def
#        /BBox //LogoBBox def
#        currentdict
#    end
#def % LogoForm
#LogoForm /EPSArray get
#readdata
#%%BeginDocument: ($Definitions{'LogoFile'})
#__END_OF_POSTSCRIPT__
#
#    open(EPS, "<$Definitions{'LogoFile'}") || die "can't open logo file: $!\n";
#    print while (<EPS>);
#    close(EPS);
#
#	print <<"__END_OF_POSTSCRIPT__";
#%%EndDocument
#% EOD_Marker_$$
#%%EndResource
#%%EndSetup
#__END_OF_POSTSCRIPT__
#}
#


## Then print the main body
#print while (<DATA>);
#
#if (defined $Definitions{'LogoFile'}) {
#print <<"__END_OF_POSTSCRIPT__";

# If there's a logo, print this stuff:
#end % userdict
#end % forms_ops

print("%%EOF")

# Don't do the insanity of trying to bump up the check number!
#
#
## Update the config file with the new check number, if it's not just a test
#if (!$opt_test && !$opt_cgi) {
#	$next_check_number = $Definitions{"CheckNumber"} 
#		+ ($Definitions{"NumPages"} * $Definitions{"ChecksPerPage"});
#
#	$config_file = Replace_Val($config_file, "Account", $opt_account, 
#				"CheckNumber", $next_check_number);
#	write_file ($ENV{"HOME"} . "/.freecheck.cfg", $config_file);
#}
#
################
## Subroutines #
################
#
## read_file and write_file shamelessly stolen from the File::Slurp module
## Short enough, and I didn't want to require a non-standard module
#
#sub read_file
#{
#	my ($file) = @_;
#
#	local(*F);
#	my $r;
#	my (@r);
#
#	open(F, "<$file") || die "open $file: $!";
#	@r = <F>;
#	close(F);
#
#	return @r if wantarray;
#	return join("",@r);
#}
#
#sub write_file
#{
#	my ($f, @data) = @_;
#
#	local(*F);
#
#	open(F, ">$f") || die "open >$f: $!";
#	(print F @data) || die "write $f: $!";
#	close(F) || die "close $f: $!";
#	return 1;
#}
#
#sub Replace_Val {
#	local ($string, $section, $name, $key, $value) = 
#	      ($_[0],   $_[1],    $_[2], $_[3], $_[4]);
#	# We want to get "[section name] ... key = value" and replace it
#	# with the new value.
#	
#	# s - "." matches ANYTHING including newline
#	# m - ^ and $ match after and before any newline
#	# in this case, ".+?" means the minimum number of <anything> i.e. end
#	# when we find the first instance of $key after [section name]
#	$string =~ 
#	s/(^\[\s*$section\s+$name\s*\].+?^${key}\s*=\s*).*?$/$+$value/smi;
#	$string;
#}

if __name__ == "__main__":
    FreeCheckPrinterMain.main()
