#!/usr/bin/perl

#---------------
#
#    FreeCheck - a free check printing application released
#                under the GNU General Public Licene.
#
#    Copyright (C) 2000 Eric Sandeen <sandeen-freecheck@sandeen.net>
#    Copyright (C) 2002 James Klicman <james@klicman.org>
#    Copyright (C) 2024 Josh Rodd <josh@rodd.us>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
#---------------
#
#    This contains portions of code from Artifex Ghostscript, which
#    is licensed under the Affero GNU Public License version 3. Use
#    of this code may bind you to the obligations of the AGPL.

$version = "0.4.0";
$systemConfigFile = "/etc/freecheck/freecheck.cfg";
$ConfigFile = $ENV{"HOME"} . "/.freecheck.cfg";

use Getopt::Long;
use File::Copy qw(copy);


if ( ! -e $ConfigFile ) {
	copy $systemConfigFile, $ConfigFile;
}

# This tells us how to format the strings from the cfg file
# so we can print it as a PostScript definition
# The key read will replace "value" for each of these
# Strings are enclosed in parentheses	(String)	(Foobar)
# Fonts are preceded by a "/"		/FontName	/Arial
# Digits are fine as they are		Digit		123
# Booleans are fine too			Bool		true
# But to be safe, do digits and bools as subroutines:
# Subroutines are in {}			{subr}		{3 mul}

%Formats = qw(
		# Globals
		MICRFontName		/value
		MICRFontSize		{value}
		TransitSymbol		(value)
		OnUsSymbol		(value)
		AmountSymbol		(value)
		DashSymbol		(value)
		MICRVerTweak		{value}
		MICRHorTweak		{value}
		# Account
		CheckNumber		{value}
		PrintCheckBody		{value}
		PrintMICRLine		{value}
		NumPages		{value}
		Name1			(value)
		Name2			(value)
		Address1		(value)
		Address2		(value)
		CityStateZip		(value)
		PhoneNumber		(value)
		BankName		(value)
		BankAddr1		(value)
		BankAddr2		(value)
		BankCityStateZip	(value)
		AuxOnUs			(value)
		Routing			(value)
		OnUs			(value)
		Fraction		(value)
		PrintVOID		{value}
		# Styles
		CheckLayout		/value
		StandardFontName	/value
		StandardFontSize	{value}
		BoldFontName		/value
		BoldFontSize		{value}
		CheckNumDigits		{value}
		CheckNumFontName	/value
		CheckNumFontSize	{value}
		FractionFontName	/value
		FractionFontSize	{value}
		Underline		{value}
		LineWidth		{value}
		MemoLineHeight		{value}
		SignatureLineHeight	{value}
		BankInfoHeight		{value}
		AmountLineHeight	{value}
		PayeeLineHeight		{value}
		DateLineHeight		{value}
		LogoFile		(value)
		LogoWidth		{value}
		LogoHeight		{value}
		LogoPadding		{value}
		LogoBorder		{value}
		LogoBBox		[value]
		BankLogoFile		(value)
		BankLogoWidth		{value}
		BankLogoHeight		{value}
		BankLogoPadding		{value}
		BankLogoBorder		{value}
		BankLogoBBox		[value]
		# Check Blank Types
		CheckHeight		{value}
		CheckWidth		{value}
		CheckHorOffset		{value}
		CheckVerOffset		{value}
		ChecksPerPage		{value}
		LeftMargin		{value}
		RightMargin		{value}
		TopMargin		{value}
		);
			
# Parse command line options and deal with them:

GetOptions	("account:s",	# Account definition file
		"checknum:i",	# Check number optional (overrides acct file)
		"pages:i",	# Number of pages to print
		"checkstyle:s",	# Check style (defaults to "normal_style.ps"
		"checktype:s",  # Check blank definition
		"nomicr",       # Prevents MICR line from printing (body only)
		"nobody",	# Prevents body from printing (MICR line only)
		"showaccounts",	# Show available accounts
		"showstyles",	# Show available check styles
		"showblanks",	# Show available check blanks
		"test",		# Don't increment check n, and print VOID
		"cgi:s",	# Accept big string from CGI script (or similar)
		"help")

or Show_Usage();

if ($opt_help) {
	Show_Usage();
}

# Some defaults...
if (!$opt_cgi) {
	$opt_account = "sample" unless defined $opt_account;
	$opt_checktype = "MVG3001" unless defined $opt_checktype;
	$opt_checkstyle = "normal" unless defined $opt_checkstyle;
}

# Pull the config file into a string...
$config_file = read_file($ConfigFile);

# See what sections are available
Get_Sections();

# If we're missing the [Global] section, or if a requested section
# cannot be found, die.
if (!$global_found) {
	die ("No [Global] section found in config file\n");
}

if ($accounts !~ /${opt_account}/i) {
	die ("Account $opt_account not found in config file\n");
}

if ($checkblanks !~ /$opt_checktype/i) {
	die ("Check type $opt_checktype not found in config file\n");
}

if ($checkstyles !~ /$opt_checkstyle/i) {
	die ("Style $opt_checkstyle not found in config file\n");
}

# Show list of available sections, if requested
if ($opt_showaccounts || $opt_showstyles || $opt_showblanks) {
	print "\nFreeCheck v$version\n";
	if ($opt_showaccounts) {
		print "Accounts:\n";
		foreach (split(/\s+/,$accounts)) {
			print "\t$_\n";
		}
	}
	if ($opt_showstyles) {
		print "Check Styles:\n";
		foreach (split(/\s+/,$checkstyles)) {
			print "\t$_\n";
		}
	}
	if ($opt_showblanks) {
		print "Check Types:\n";
		foreach (split(/\s+/,$checkblanks)) {
			print "\t$_\n";
		}
	}
	die("\n");
}

# Go through the config and fill up a hash with PostScript defines...
Parse_Config($config_file);

# Overwrite anything we got from the config file with what was on the
# Command Line (if anything...)

if ($opt_checknum) {
	$Definitions{"CheckNumber"} = $opt_checknum;
}

if ($opt_pages) {
	$Definitions{"NumPages"} = $opt_pages;
}

if ($opt_nomicr) {
	$Definitions{"PrintMICRLine"} = "false";
}

if ($opt_nobody) {
	$Definitions{"PrintCheckBody"} = "false";
}

# This probably isn't in the config file (although it might be...)
# so cover both possibilites (true/false)
if ($opt_test) {
	$Definitions{"PrintVOID"} = "true";
} else {
	$Definitions{"PrintVOID"} = "false";
}

# the --cgi option lets us pass in name value pairs in a string.
# This will overwrite anything we got from the config file, or
# from the other command line options (--cgi has the last word)
# Parse as follows:
# name is the first word, everything following it is the value
# each line contains one name/value pair.

while ( $opt_cgi =~ /(^\w+)\s+?(.*$)/mcg ) {
	$Definitions{$1} = $2;
}

##################
# Error Checking #
##################

$error = "";

# Make sure that MICR line is only numbers and symbols

if ( $Definitions{"Routing"} !~ /^R[0-9]+R$/ ) {
	$error = $error . "Error - Routing number must be numeric, with an \"R\" on each end\n";
}

if ( $Definitions{"AuxOnUs"} !~ /^[0-9\-CPS]*$/ ) {
	$error = $error . "Error - Auxiliary On-Us field may only be numeric, with \"-\", and MICR symbols (C,P,S)\n";
}

if ( $Definitions{"OnUs"} !~ /^[0-9\-CPS]+$/ ) {
	$error = $error . "Error - On-Us field may only be numeric, with \"-\", and MICR symbols (C,P,S)\n";
}

if ( $Definitions{"CheckNumber"} !~ /^[0-9]+$/ ) {
	$error = $error . "Error - Check number must be numeric \n";
}

if ( $Definitions{"NumPages"} !~ /^[0-9]+$/ ) {
	$error = $error . "Error - Number of pages must be numeric\n";
}

if ( $Definitions{"Fraction"} !~ /^[0-9]{2}\s*\-\s*[0-9]{1,4}\s*\/\s*[0-9]{3,4}$/ ) {
	$error = $error . "Error - Routing fraction must be numeric, with a \"-\" in the numerator\n";
}

if ($Definitions{'CheckLayout'} !~ /^(Original|QStandard|QWallet)$/) {
    $error .= "Error - CheckLayout must be Original, QStandard or QWallet\n";
}

# Get routing symbol and institution number from routing number
$RoutingSymbol = substr($Definitions{"Routing"},1,4);
$Institution = substr($Definitions{"Routing"},5,4);

# Strip any leading zeros...
# Only should be one on routing...
$RoutingSymbol =~ s/^0//;
# One or more on institution
#$Institution =~ s/^0+//;

# Fraction format:
#
# 2 digits, a "-", institution number (no leading zeros)
# ------------------------------------------------------
# routing number (no leading zeros)


if ( $Definitions{"Fraction"} !~ /^[0-9]{2}\-${Institution}\/${RoutingSymbol}$/ ) {
	$error = $error . "Error - Routing fraction does not match routing number\n";
}


# Test the MICR line for correctness
if ( length ($Definitions{"Routing"}) != 11 ) {
	$error = $error . "Error - Routing number must be exactly 9 digits long, with
				an \"R\" on each end\n";
}

# Test the MICR checksum
# Don't forget the real routing number is sandwiched between "Rs"

unless ( ( $Definitions{"Routing"} !~ /^R[0-9]+R$/) || ( length ($Definitions{"Routing"}) != 11 ) ){

	$CheckSum = 0;

	@CheckSumMults = (3, 7, 1, 3, 7, 1, 3, 7);
	for ($Digit = 1; $Digit < 9; $Digit++) {
		$CheckSum = $CheckSum +
			$CheckSumMults[$Digit-1] * substr($Definitions{"Routing"}, $Digit, 1);
	}
	
	$CheckSum = 10 - ($CheckSum % 10);

	# Kludge alert...
	if ($CheckSum == 10) {
		$CheckSum = 0;
	}

	if ( $CheckSum ne substr($Definitions{"Routing"}, 9, 1) ) {
		$error = $error . "Error - Routing Number Checksum Incorrect\n";
	}
}

if (defined $Definitions{'LogoFile'}) {
    if (open(EPS,"<$Definitions{'LogoFile'}")) {
        my $foundbbox = 0;
        while (<EPS>) {
            break if /^%%EndComments/;
            next unless s/^%%((?:HiRes)?BoundingBox):\s*//;
            my $hires = ($1 eq 'HiResBoundingBox');
            $foundbbox = 1;
            if (/^(\d+(?:\.\d+)?(?:\s+\d+(?:\.\d+)?){3})\s*(?:%.*)?$/) {
                $Definitions{'LogoBBox'} = $1;
            } else {
                $error .= "Error - Can't parse EPS Logo BoundingBox comment\n";
            }
            # keep looking until HiResBoundingBox or EndComments
            break if $hires;
        }
        close(EPS);

        unless ($foundbbox) {
            $error .= "Error - Required EPS Logo BoundingBox not found\n";
        }
    } else {
        $error .= "Error - Can't open LogoFile $Definitions{'LogoFile'}: $!\n";
    }
}

if (defined $Definitions{'BankLogoFile'}) {
    if (open(EPS,"<$Definitions{'BankLogoFile'}")) {
        my $foundbbox = 0;
        while (<EPS>) {
            break if /^%%EndComments/;
            next unless s/^%%((?:HiRes)?BoundingBox):\s*//;
            my $hires = ($1 eq 'HiResBoundingBox');
            $foundbbox = 1;
            if (/^(\d+(?:\.\d+)?(?:\s+\d+(?:\.\d+)?){3})\s*(?:%.*)?$/) {
                $Definitions{'BankLogoBBox'} = $1;
            } else {
                $error .= "Error - Can't parse EPS Logo BoundingBox comment\n";
            }
            # keep looking until HiResBoundingBox or EndComments
            break if $hires;
        }
        close(EPS);

        unless ($foundbbox) {
            $error .= "Error - Required EPS Logo BoundingBox not found\n";
        }
    } else {
        $error .= "Error - Can't open LogoFile $Definitions{'BankLogoFile'}: $!\n";
    }
}

# die() if we got errors
if ( $error && !$opt_test ) {
	print STDERR $error;
	die("Errors Encountered\n");
}

# Print PostScript

# Initial stuff:
print <<"__END_OF_POSTSCRIPT__";
%!PS-Adobe-3.0
%%Title: FreeCheck
%%LanguageLevel: 2
%%EndComments
%%BeginProlog
/inch {72 mul} def
__END_OF_POSTSCRIPT__

# Go through $Definitions and print them out PostScript-Like
Print_Defs();

if (defined $Definitions{'BankLogoFile'}) {
    my $filesize = (stat($Definitions{'BankLogoFile'}))[7];
    print <<"__END_OF_POSTSCRIPT__";
%%BeginProcSet: banklogo
%%Creator: Josh Rodd <josh\@rodd.us>
%%CreationDate: June 2024
%%Version: 0.4

% if
/BankLogoPadding where
{
    pop % discard dict
}
% else
{
    /BankLogoPadding 0 def
}
ifelse

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Calculate BankLogoMatrix
%
% BankLogoXScale
BankLogoWidth BankLogoPadding 2 mul sub
% BankBBWidth
    BankLogoBBox 2 get % x2
    BankLogoBBox 0 get % x1
    sub % x2 x1 sub
div % BankLogoWidth BankBBWidth div
% BankLogoYScale
BankLogoHeight BankLogoPadding 2 mul sub
% BBHeight
    BankLogoBBox 3 get % y2
    BankLogoBBox 1 get % y1
    sub % y2 y1 sub
div % BankLogoHeight BankBBHeight div

% if
2 copy lt % BankLogoXScale BankLogoYScale lt
{
    pop % discard BankLogoYScale
}
% else
{
    exch pop % discard BankLogoXScale
}
ifelse
% ^ (BankLogoXScale < BankLogoYScale ? BankLogoXScale : BankLogoYScale)
dup matrix scale /BankLogoMatrix exch def

/DrawBankLogo {
    /BankLogoForm where {
        pop % discard dict
        gsave

        % Don't draw a border for the bank logo.
        % /BankLogoBorder where {
        %     pop % discard dict
        %     newpath
        %     LeftMargin BankLogoBorder 2 div add
        %     CheckHeight TopMargin sub BankLogoBorder 2 div sub  moveto

        %     BankLogoWidth BankLogoBorder sub 0 rlineto
        %     0 BankLogoHeight BankLogoBorder sub neg rlineto
        %     BankLogoWidth BankLogoBorder sub neg 0 rlineto
        %     closepath
        %     BankLogoBorder setlinewidth stroke
        % } if

        % Logo is placed in front of the bank info on the check
        LeftMargin CheckHeight BankInfoHeight mul TopMargin add translate

        BankLogoForm /BBox get aload pop % ^ llx lly urx ury

        % translate top-left corner of BankLogoBBox to current point
        % ^ llx lly urx ury
        3 index neg % llx neg  ^ llx lly urx ury -llx
        1 index neg % ury neg  ^ llx lly urx ury -llx -ury
        BankLogoForm /Matrix get
        transform % -llx -ury BankLogoMatrix transform
        translate % transformedX transformedY translate

        % calculate real width and height of BankLogoBBox
        % ^ llx lly urx ury
        exch      % ^ llx lly ury urx
        4 -1 roll % ^ lly ury urx llx
        sub % urx llx sub ^ lly ury urx-llx
        3 -2 roll % ^ urx-llx lly ury
        exch      % ^ urx-llx ury lly
        sub % ury lly sub
        % ^ urx-llx ury-lly
        BankLogoForm /Matrix get
        transform % urx-llx ury-lly BankLogoMatrix transform
        % ^ RealBankLogoWidth RealBankLogoHeight

        % Calculate difference of RealBankLogoWidth, RealBankLogoHeight
        % and BankLogoWidth, BankLogoHeight for centering logo.
        exch BankLogoWidth exch sub 2 div
        exch BankLogoHeight exch sub 2 div neg
        translate % BankLogoHAlign BankLogoVAlign translate
        0 inch 0 inch translate

        BankLogoForm execform

        grestore
    } if
} def
%%EndProcSet

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%
% The following EPS Form handling code is based on code contained in
% Adobe Technical Note #5144 Using EPS Files in PostScript Language Forms.
%

%%BeginResource: procset forms_ops 1.0 0
%%Title: (Forms Operators)
%%Version: 1.0
userdict /forms_ops 10 dict dup begin put

/StartEPSF { % prepare for EPSF inclusion
    userdict begin
    /PreEPS_state save def
    /dict_stack countdictstack def
    /ops_count count 1 sub def
    /showpage {} def
} bind def

/EPSFCleanUp { % clean up after EPSF inclusion
    count ops_count sub {pop} repeat
    countdictstack dict_stack sub {end} repeat
    PreEPS_state restore
    end % userdict
} bind def

/STRING_SIZE 16000 def % Best value to not fragment printer's VM
% recommended ARRAY_SIZE = filesize/16000 + 2
% +2 resulted in errors
% +3 worked
/ARRAY_SIZE $filesize 16000 idiv 3 add def

% for initial counter and final empty string.
/buffer STRING_SIZE string def
/inputFile currentfile 0 (% EOD_Marker_$$) /SubFileDecode filter def

/readdata { % array readdata --
    1 { % put counter on stack
        % stack: array counter
        2 copy % stack: array counter array counter
        inputFile buffer readstring % read contents of currentfile into buffer
        % stack: array counter array counter string boolean
        4 1 roll % put boolean indicating EOF lower on stack
        STRING_SIZE string copy % copy buffer string into new string
        % stack: array counter boolean array counter newstring
        put % put string into array
        not {exit} if % if EOF has been reached, exit loop.
        1 add % increment counter
    } loop
    % increment counter and place empty string in next position
    1 add 2 copy () put pop
    currentglobal true setglobal exch
    0 1 array put % create an array for counter in global VM,
    % so as not to be affected by save/restore calls in EPS file.
    % place as first element of string array.
    setglobal % restore previously set value
} bind def
currentdict readonly pop end
%%EndResource
%%EndProlog
%%BeginSetup
% set MaxFormItem to be equivalent to MaxFormCache
<< /MaxFormItem currentsystemparams /MaxFormCache get >> setuserparams
% make forms procset available
forms_ops begin
userdict begin
% download form resource
%%BeginResource: form BankLogoForm
/BankLogoForm
    10 dict begin
        /FormType 1 def
        /EPSArray ARRAY_SIZE array def
        /AcquisitionProc {
            EPSArray dup 0 get dup 0 get % array counter_array counter
            dup 3 1 roll % array counter counter_array counter
            1 add 0 exch put % increment counter
            get % use old counter as index into array, placing
            % next string on operand stack.
        } bind def
        /PaintProc {
            begin
                StartEPSF
                % May want to translate here, prior to executing EPS
                EPSArray 0 get 0 1 put
                //AcquisitionProc 0 () /SubFileDecode filter
                cvx exec
                EPSFCleanUp
            end
        } bind def
        /Matrix //BankLogoMatrix def
        /BBox //BankLogoBBox def
        currentdict
    end
def % BankLogoForm
BankLogoForm /EPSArray get
readdata
%%BeginDocument: ($Definitions{'BankLogoFile'})
__END_OF_POSTSCRIPT__

    open(EPS, "<$Definitions{'BankLogoFile'}") || die "can't open bank logo file: $!\n";
    print while (<EPS>);
    close(EPS);

	print <<"__END_OF_POSTSCRIPT__";
%%EndDocument
% EOD_Marker_$$
%%EndResource
%%EndSetup
__END_OF_POSTSCRIPT__
}

if (defined $Definitions{'LogoFile'}) {
    my $filesize = (stat($Definitions{'LogoFile'}))[7];
    print <<"__END_OF_POSTSCRIPT__";
%%BeginProcSet: logo
%%Creator: James Klicman <james\@klicman.org>
%%CreationDate: October 2002
%%Version: 0.3

% if
/LogoPadding where
{
    pop % discard dict
}
% else
{
    /LogoPadding 0 def
}
ifelse

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Calculate LogoMatrix
%
% LogoXScale
LogoWidth LogoPadding 2 mul sub
% BBWidth
    LogoBBox 2 get % x2
    LogoBBox 0 get % x1
    sub % x2 x1 sub
div % LogoWidth BBWidth div
% LogoYScale
LogoHeight LogoPadding 2 mul sub
% BBHeight
    LogoBBox 3 get % y2
    LogoBBox 1 get % y1
    sub % y2 y1 sub
div % LogoHeight BBHeight div

% if
2 copy lt % LogoXScale LogoYScale lt
{
    pop % discard LogoYScale
}
% else
{
    exch pop % discard LogoXScale
}
ifelse
% ^ (LogoXScale < LogoYScale ? LogoXScale : LogoYScale)
dup matrix scale /LogoMatrix exch def

/DrawLogo {
    /LogoForm where {
        pop % discard dict
        gsave

        % Don't draw a border for the logo anymore.
        % /LogoBorder where {
        %     pop % discard dict
        %     newpath
        %     LeftMargin LogoBorder 2 div add
        %     CheckHeight TopMargin sub LogoBorder 2 div sub  moveto

        %     LogoWidth LogoBorder sub 0 rlineto
        %     0 LogoHeight LogoBorder sub neg rlineto
        %     LogoWidth LogoBorder sub neg 0 rlineto
        %     closepath
        %     LogoBorder setlinewidth stroke
        % } if


        % Logo is placed at the top-left corner of the check
        LeftMargin  CheckHeight TopMargin sub  translate

        LogoForm /BBox get aload pop % ^ llx lly urx ury

        % translate top-left corner of LogoBBox to current point
        % ^ llx lly urx ury
        3 index neg % llx neg  ^ llx lly urx ury -llx
        1 index neg % ury neg  ^ llx lly urx ury -llx -ury
        LogoForm /Matrix get
        transform % -llx -ury LogoMatrix transform
        translate % transformedX transformedY translate

        % calculate real width and height of LogoBBox
        % ^ llx lly urx ury
        exch      % ^ llx lly ury urx
        4 -1 roll % ^ lly ury urx llx
        sub % urx llx sub ^ lly ury urx-llx
        3 -2 roll % ^ urx-llx lly ury
        exch      % ^ urx-llx ury lly
        sub % ury lly sub
        % ^ urx-llx ury-lly
        LogoForm /Matrix get
        transform % urx-llx ury-lly LogoMatrix transform
        % ^ RealLogoWidth RealLogoHeight

        % Calculate difference of RealLogoWidth, RealLogoHeight
        % and LogoWidth, LogoHeight for centering logo.
        exch LogoWidth exch sub 2 div
        exch LogoHeight exch sub 2 div neg
        translate % LogoHAlign LogoVAlign translate

        % LogoForm execform

        grestore
    } if
} def
%%EndProcSet

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%
% The following EPS Form handling code is based on code contained in
% Adobe Technical Note #5144 Using EPS Files in PostScript Language Forms.
%

%%BeginResource: procset forms_ops 1.0 0
%%Title: (Forms Operators)
%%Version: 1.0
userdict /forms_ops 10 dict dup begin put

/StartEPSF { % prepare for EPSF inclusion
    userdict begin
    /PreEPS_state save def
    /dict_stack countdictstack def
    /ops_count count 1 sub def
    /showpage {} def
} bind def

/EPSFCleanUp { % clean up after EPSF inclusion
    count ops_count sub {pop} repeat
    countdictstack dict_stack sub {end} repeat
    PreEPS_state restore
    end % userdict
} bind def

/STRING_SIZE 16000 def % Best value to not fragment printer's VM
% recommended ARRAY_SIZE = filesize/16000 + 2
% +2 resulted in errors
% +3 worked
/ARRAY_SIZE $filesize 16000 idiv 3 add def

% for initial counter and final empty string.
/buffer STRING_SIZE string def
/inputFile currentfile 0 (% EOD_Marker_$$) /SubFileDecode filter def

/readdata { % array readdata --
    1 { % put counter on stack
        % stack: array counter
        2 copy % stack: array counter array counter
        inputFile buffer readstring % read contents of currentfile into buffer
        % stack: array counter array counter string boolean
        4 1 roll % put boolean indicating EOF lower on stack
        STRING_SIZE string copy % copy buffer string into new string
        % stack: array counter boolean array counter newstring
        put % put string into array
        not {exit} if % if EOF has been reached, exit loop.
        1 add % increment counter
    } loop
    % increment counter and place empty string in next position
    1 add 2 copy () put pop
    currentglobal true setglobal exch
    0 1 array put % create an array for counter in global VM,
    % so as not to be affected by save/restore calls in EPS file.
    % place as first element of string array.
    setglobal % restore previously set value
} bind def
currentdict readonly pop end
%%EndResource
%%EndProlog
%%BeginSetup
% set MaxFormItem to be equivalent to MaxFormCache
<< /MaxFormItem currentsystemparams /MaxFormCache get >> setuserparams
% make forms procset available
forms_ops begin
userdict begin
% download form resource
%%BeginResource: form LogoForm
/LogoForm
    10 dict begin
        /FormType 1 def
        /EPSArray ARRAY_SIZE array def
        /AcquisitionProc {
            EPSArray dup 0 get dup 0 get % array counter_array counter
            dup 3 1 roll % array counter counter_array counter
            1 add 0 exch put % increment counter
            get % use old counter as index into array, placing
            % next string on operand stack.
        } bind def
        /PaintProc {
            begin
                StartEPSF
                % May want to translate here, prior to executing EPS
                EPSArray 0 get 0 1 put
                //AcquisitionProc 0 () /SubFileDecode filter
                cvx exec
                EPSFCleanUp
            end
        } bind def
        /Matrix //LogoMatrix def
        /BBox //LogoBBox def
        currentdict
    end
def % LogoForm
LogoForm /EPSArray get
readdata
%%BeginDocument: ($Definitions{'LogoFile'})
__END_OF_POSTSCRIPT__

    open(EPS, "<$Definitions{'LogoFile'}") || die "can't open logo file: $!\n";
    print while (<EPS>);
    close(EPS);

	print <<"__END_OF_POSTSCRIPT__";
%%EndDocument
% EOD_Marker_$$
%%EndResource
%%EndSetup
__END_OF_POSTSCRIPT__
}

# Then print the main body
print while (<DATA>);

if (defined $Definitions{'LogoFile'}) {
	print <<"__END_OF_POSTSCRIPT__";
end % userdict
end % forms_ops
__END_OF_POSTSCRIPT__
}

print "%%EOF\n";


# Update the config file with the new check number, if it's not just a test
if (!$opt_test && !$opt_cgi) {
	$next_check_number = $Definitions{"CheckNumber"}
		+ ($Definitions{"NumPages"} * $Definitions{"ChecksPerPage"});

	$config_file = Replace_Val($config_file, "Account", $opt_account,
				"CheckNumber", $next_check_number);
	write_file ($ENV{"HOME"} . "/.freecheck.cfg", $config_file);
}

###############
# Subroutines #
###############

# read_file and write_file shamelessly stolen from the File::Slurp module
# Short enough, and I didn't want to require a non-standard module

sub read_file
{
	my ($file) = @_;

	local(*F);
	my $r;
	my (@r);

	open(F, "<$file") || die "open $file: $!";
	@r = <F>;
	close(F);

	return @r if wantarray;
	return join("",@r);
}

sub write_file
{
	my ($f, @data) = @_;

	local(*F);

	open(F, ">$f") || die "open >$f: $!";
	(print F @data) || die "write $f: $!";
	close(F) || die "close $f: $!";
	return 1;
}

# Wow, this is ugly!  Anybody have a better suggestion?
sub Parse_Config {
	local ($config_file) = ($_[0]);
	# Find each section we're looking for...
	while ($config_file =~ /^\[\s*(
					Global |
					Account\s+${opt_account} |
					Style\s+${opt_checkstyle} |
					CheckBlank\s+${opt_checktype}
					)\s*\]/xmgci) {
		# and get the lines under it one by one
		while ($config_file =~ /(^.+$)/mgc) {
			$line = $+;
			# If this line is a comment, skip it
			if ($line =~ /^#/) {
				next;
			}
			# If the line we just found is a new section..."[...]"
			if ($line =~ /^\[.+\]/) {
				# and it is another section we're looking for
				# Grab the next line, and keep going
				if ($line =~ /\[\s*(
						Global |
						Account\s+${opt_account} |
						Style\s+${opt_checkstyle} |
						CheckBlank\s+${opt_checktype}
						)\s*]/xi) {
					# Grab the next line, and keep going
					next;
				} else {
					# Not a section we need, so break out
					# of the loop
					last;
				}
			}
			
			($key, $val) = split (/\s*=\s*/,$line);
			# Need to strip trailing whitespace...
			$val =~ s/\s*$//;
			$Definitions{$key} = $val;
		} # line-by-line while
	} # section match conditional
}

sub Replace_Val {
	local ($string, $section, $name, $key, $value) =
	      ($_[0],   $_[1],    $_[2], $_[3], $_[4]);
	# We want to get "[section name] ... key = value" and replace it
	# with the new value.
	
	# s - "." matches ANYTHING including newline
	# m - ^ and $ match after and before any newline
	# in this case, ".+?" means the minimum number of <anything> i.e. end
	# when we find the first instance of $key after [section name]
	$string =~
	s/(^\[\s*$section\s+$name\s*\].+?^${key}\s*=\s*).*?$/$+$value/smi;
	$string;
}
# Given a section type, list all the section names of that type
sub Get_Sections {
	local $section;
	while ($config_file =~ /^\[\s*(
					Global |
					Account.+ |
					Style.+ |
					CheckBlank.+
					)\s*\]/xmgci) {
		$section = $+;
		if ( $section =~/CheckBlank\s+(.+)/i ) {
			$checkblanks = "$+ $checkblanks";
		} elsif ( $section =~/Style\s+(.+)/i ) {
			$checkstyles = "$+ $checkstyles";
		} elsif ( $section =~/Account\s+(.+)/i ) {
			$accounts = "$+ $accounts";
		} elsif ( $section =~/Global/i ) {
			$global_found = "true";
		}
	}
}

sub Show_Usage {
	print "\nFreeCheck v.$version - a Free Check printing Utility\n\n";
	print "Usage: freecheck <options>:\n";
	print "\n";
	print "options:\n";
	print "  --account    <filename>    account to use (default \"$opt_account\")\n";
	print "  --checknum   <integer>     starting check number (overrides cfg)\n";
	print "  --pages      <integer>     number of pages to print (overrides cfg)\n";
	print "  --checkstyle <filename>    check style to use (default \"$opt_checkstyle\")\n";
	print "  --checktype  <filename>    blank check type to use (default \"$opt_checktype\")\n";
	print "  --nomicr                   do not print MICR line\n";
	print "  --nobody                   do not print check body\n";
	print "  --showaccounts             show all configured accounts\n";
	print "  --showstyles               show all configured check styles\n";
	print "  --showblanks               show all configured check blanks\n";
	print "  --help                     print this message\n";
	print "  --test                     print but don't increment check number\n";
	print "                               and print VOID on the check\n";
	print "  --cgi                      accept string from CGI script (see docs)\n";
	print "\nconfig file \"~/.freecheck.cfg\"\n";
	die "\n";
}

sub Print_Defs {
	# Go through each def in the hash table, and print according to the
	# formatting hash
	while ( ($key, $val) = each (%Definitions) ) {
		print "/$key\t";
		$_ = $Formats{$key};
		s/value/$val/;
		print;
		print " def\n";
	}
}
# End of Perl
__END__

% This is the main body of the postscript file, that acts on all of the
% definitions we got from the config file.

% Available Check Layouts
/CheckLayoutDict <<
    /Original { DrawOriginalCheckBody }
    /QStandard { DrawQStandardCheckBody }
    /QWallet { DrawQWalletCheckBody }
>> def

% Other Constants:

% Size of the rectangular box for the amount (digits)
/AmountBoxWidth		{1 inch} def
/AmountBoxHeight	{0.25 inch} def

% Max number of digits in check number, and allocate string
/CheckNumDigits 	4 def
/CheckNumberString 	CheckNumber log floor 1 add cvi string def

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Helpful Printing Routines                                                  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Shows a line, then does a "carriage return / line feed"
% But only if the string exists (more than 0 chars)
% (How do we get the current font size (height)?)

/ShowAndCR {
	% if
	dup length 0 gt	% First copy
	{
		dup show		% Second copy
		stringwidth pop neg 0 rmoveto	% Original copy & move back
		neg 0 exch rmoveto % line down
	}
	% else
	{
	    pop % discard (string)
	    pop % discard height
	}
	ifelse
} def

%%BeginProcSet: substitute
%%Creator: James Klicman <james@klicman.org>
%%CreationDate: October 2002
%%Version: 0.3
%
% (string) (O) (N)  substitute  -
%
% example:  (A?C) (?) (B)  substitute -> (ABC)
%
/substitute {
    0 get exch 0 get exch % convert (O) and (N) to char codes
    0 % counter
    3 index % (string) {} forall
    {
        % ^ (string) O N counter C
        3 index % (O)[0]
        eq % (string)[i] == (O)[0]
        {
            % ^ (string) O N counter
            3 index % (string)
            % ^ (string) O N counter (string)
            1 index % counter
            % ^ (string) O N counter (string) counter
            3 index % N
            % ^ (string) O N counter (string) counter N
            put % (string) counter N put
        } if
        1 add % increment counter
    } forall
    pop % counter
    pop % N
    pop % O
    pop % (string)
} def
%%EndProcSet

% Fix up the MICR line components (replace placeholders with MICR
% characters)
% Argh... surely there's a better way - anyone? use "forall?"

/FixMICR {

	/CheckNumStart -1 def
	/CheckNumEnd -1 def
	/CheckNumInOnUs false def
	/CheckNumInAuxOnUs false def

	% Get starting and ending positions for check number in
	% (Aux)OnUs field
	% (This will break if check number is entered in both fields)
	
	OnUs length 1 sub -1 0 {
		dup  % dups the index
		OnUs exch get (C) 0 get eq {
			/CheckNumInOnUs true def
			% If end number not yet defined, define it
			CheckNumEnd 0 lt {
				/CheckNumEnd exch def
			} {
				/CheckNumStart exch def
			} ifelse
			
		} {
			pop
		} ifelse
	} for
	
	AuxOnUs length 1 sub -1 0 {
		dup  % dups the index
		AuxOnUs exch get (C) 0 get eq {
			/CheckNumInAuxOnUs true def
			% If end number not yet defined, define it
			CheckNumEnd 0 lt {
				/CheckNumEnd exch def
			} {
				/CheckNumStart exch def
			} ifelse
			
		} {
			pop
		} ifelse
	} for
	

	% Replace "R" in routing number with actual transit number symbol
	% That's it - should be no spaces, dashes, or anything but digits
	Routing (R) TransitSymbol substitute

	% Replace "S" with space character in AuxOnUs
	AuxOnUs (S) ( ) substitute
		
	% Replace "-" with dash character in AuxOnUs
	AuxOnUs (-) DashSymbol substitute

	% Replace "P" with OnUs character in AuxOnUs
	AuxOnUs (P) OnUsSymbol substitute

	% Replace "S" with space character in OnUs
	OnUs (S) ( ) substitute

	% Replace "-" with dash character in OnUs
	OnUs (-) DashSymbol substitute

	% Replace "P" with OnUs character in OnUs
	OnUs (P) OnUsSymbol substitute

} def

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Original Feature Printing Routines                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/DrawMemoLine {
	LeftMargin MemoLineHeight CheckHeight mul moveto
	2.5 inch 0 inch rlineto
	-2.5 inch 0 inch rmoveto
	0 2 rmoveto
	(Memo) show
} def

/center

/DrawSignatureLine { % Expects height of signature line
		 % and right edge of check for
		 % beginning position

	CheckWidth SignatureLineHeight CheckHeight mul moveto
	RightMargin neg 0 rmoveto
	-2.5 inch 0 rmoveto
	2.5 inch 0 inch rlineto
	-1.25 inch -0.15 inch rmoveto
	(Authorized Signature) centeralign show

} def

/DrawAmountLine {
	CheckWidth AmountLineHeight CheckHeight mul moveto
	RightMargin neg 0 rmoveto
	(DOLLARS) stringwidth pop neg 0 rmoveto
	(DOLLARS) show
	(DOLLARS) stringwidth pop neg 0 rmoveto
	-2 0 rmoveto
	LeftMargin AmountLineHeight CheckHeight mul lineto
} def

/DrawAccountHolderInfo {
	LeftMargin CheckHeight moveto
	0 TopMargin neg rmoveto
	0 StandardFontSize neg rmoveto

    % make room for Logo if specified
    /LogoForm where {
        pop % discard dict
        LogoWidth
        /LogoBorder where {
            pop % discard dict
            LogoBorder 2 div add
        } if
        /LogoPadding where {
            pop % discard dict
            LogoPadding 2 div add
        } if
        0 rmoveto
    } if

	StandardFontSize Name1 ShowAndCR
	StandardFontSize Name2 ShowAndCR

	StandardFontName findfont
	StandardFontSize 1 sub scalefont
	setfont

	StandardFontSize 1 sub Address1 ShowAndCR
	StandardFontSize 1 sub Address2 ShowAndCR
	StandardFontSize 1 sub CityStateZip ShowAndCR
	StandardFontSize 1 sub PhoneNumber ShowAndCR

	StandardFontName findfont
	StandardFontSize 1 add scalefont
	setfont
} def

/DrawDateLine {
	0.6 CheckWidth mul DateLineHeight CheckHeight mul moveto
    % Don't print the word "date".
	% (Date) show
	1 inch 0 rlineto
} def

/DrawBankInfo {
	LeftMargin BankInfoHeight CheckHeight mul moveto

    % make room for Logo if specified
    /BankLogoForm where {
        pop % discard dict
        BankLogoWidth
        /BankLogoBorder where {
            pop % discard dict
            BankLogoBorder 2 div add
        } if
        /BankLogoPadding where {
            pop % discard dict
            BankLogoPadding 2 div add
        } if
        0 rmoveto
    } if

	StandardFontSize BankName ShowAndCR

	StandardFontName findfont
	StandardFontSize 1 sub scalefont
	setfont
	
	StandardFontSize 1 sub BankAddr1 ShowAndCR
	StandardFontSize 1 sub BankAddr2 ShowAndCR
	StandardFontSize 1 sub BankCityStateZip ShowAndCR

	StandardFontName findfont
	StandardFontSize 1 add scalefont
	setfont
} def

/DrawPayeeLine {

	LeftMargin PayeeLineHeight CheckHeight mul moveto
	(ORDER OF) show
	(ORDER OF) stringwidth pop neg  StandardFontSize rmoveto
	(PAY TO THE) show
	0 StandardFontSize neg rmoveto
	4 0 rmoveto
	currentpoint mark
	
	CheckWidth PayeeLineHeight CheckHeight mul moveto
	RightMargin neg 0 rmoveto
	AmountBoxWidth neg 0 rmoveto

	0 AmountBoxHeight rlineto
	AmountBoxWidth 0 rlineto
	0 AmountBoxHeight neg rlineto
	AmountBoxWidth neg 0 rlineto

	-4 0 rmoveto
	
	/Helvetica-Bold findfont
	14 scalefont
	setfont
	
	($) stringwidth pop neg 0 rmoveto
	($) show
	($) stringwidth pop neg 0 rmoveto
	
	-4 0 rmoveto
	cleartomark
	lineto

	StandardFontName findfont
	StandardFontSize scalefont
	setfont

} def

/DrawCheckNumber {
	CheckWidth CheckHeight moveto
	RightMargin neg TopMargin neg rmoveto
	CheckNumFontName findfont
	CheckNumFontSize scalefont
	setfont

	CheckNumberString stringwidth pop neg 0 rmoveto
	0 -14 rmoveto
	CheckNumberString show

	StandardFontName findfont
	StandardFontSize scalefont
	setfont
} def

/DrawFraction {
	0.6 CheckWidth mul CheckHeight moveto
	0 TopMargin neg rmoveto
	0 StandardFontSize neg rmoveto
	Fraction show
} def

/DrawStub {
	CheckHorOffset 2 inch ge {
		save
		newpath
		CheckHorOffset neg 0 translate
		StandardFontName findfont
		StandardFontSize 1 sub scalefont
		setfont
		/StubSpacing {CheckHeight 6 div} def
		CheckHorOffset 2 div StubSpacing 5 mul moveto
		CheckNumberString show
		0.3 inch StubSpacing 4 mul moveto
		(Date ) show
		CheckHorOffset 0.3 inch sub StubSpacing 4 mul lineto
		0.3 inch StubSpacing 3 mul moveto
		(Payee ) show
		CheckHorOffset 0.3 inch sub StubSpacing 3 mul lineto
		0.3 inch StubSpacing 2 mul moveto
		(Amount ) show
		CheckHorOffset 0.3 inch sub StubSpacing 2 mul lineto
		0.3 inch StubSpacing 1 mul moveto
		(Memo ) show
		CheckHorOffset 0.3 inch sub StubSpacing 1 mul lineto
		stroke
		restore
	} if
} def	

/DrawOriginalCheckBody {
	DrawBankInfo
	DrawAccountHolderInfo
	DrawMemoLine
	DrawSignatureLine
	DrawAmountLine
	DrawPayeeLine
	DrawCheckNumber
	DrawFraction
	DrawDateLine
	/DrawLogo where { pop DrawLogo } if
	/DrawBankLogo where { pop DrawBankLogo } if
	DrawStub
} def

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% QStandard & QWallet Feature Printing Routines                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%BeginProcSet: nextline
%%Creator: James Klicman <james@klicman.org>
%%CreationDate: October 2002
%%Version: 0.3

%
% state used by initline and nextline
%
/LINESTATE <<
    /x 0
    /y 0
    /rx 0
    /ry 0
>> def

%
%   LineHeight  initline  -
%
/initline {
    LINESTATE begin
        currentpoint
        /y exch def
        /x exch def
        /ty exch def
        /tx exch def
    end
} def

%
%   -  nextline  -
%
/nextline {
    LINESTATE begin
        x tx add
        dup /x exch def % x += tx
        y ty add
        dup /y exch def % y += ty
        moveto % x y moveto
    end
} def
%%EndProcSet


%%BeginProcSet: alignment
%%Creator: James Klicman <james@klicman.org>
%%CreationDate: October 2002
%%Version: 0.3
%
%   (string)  centeralign  (string)
%
/centeralign {
    dup % dup (string)
    stringwidth % calculate string xWidth, yHeight
    pop % discard yHeight
    2 div neg % -(xWidth / 2)
    0 rmoveto % rmoveto center
} def

%
%   (string)  rightalign  (string)
%
/rightalign {
    dup stringwidth % calculate string xWidth, yHeight
    pop % discard yHeight
    neg 0 rmoveto % -xWidth 0 rmoveto
} def

%
%   (string)  stringbbox  x1 y1 x2 y2
%
%   This procedure is based on the method described in Chapter 5 page 333
%   of the PostScript Language Reference third edition.
%
/stringbbox {
    gsave
    newpath 0 0 moveto false charpath flattenpath pathbbox % x1 y1 x2 y2
    grestore
} def

%
%   (string)  topalign  (string)
%
/topalign {
    dup stringbbox % ^+ x1 y1 x2 y2
    neg 0 exch rmoveto % 0 -y2 rmoveto
    pop % x2
    pop % y1
    pop % x1
} def

%
%   (string)  bottomalign  (string)
%
/bottomalign {
    dup stringbbox % ^+ x1 y1 x2 y2
    pop % y2
    pop % x2
    neg 0 exch rmoveto % 0 -y1 rmoveto
    pop % x1
} def
%%EndProcSet


%%BeginProcSet: qchecks
%%Creator: James Klicman <james@klicman.org>
%%CreationDate: October 2002
%%Version: 0.3

/QStandardConfig <<
    /RightMarginX CheckWidth RightMargin sub
    /UnderlineOffset -3
    /MemoLineWidth 3.25 inch
    /SignatureLineWidth 3.25 inch
    /PayToTheOrderOf {
            currentpoint % oldpoint
            0 StandardFontSize rmoveto  % move up one line
            (PAY TO THE) show
            moveto % oldpoint moveto
            (ORDER OF ) show
        }
    % QStandard Coords, Check Size 8.5" x 3.5"
    /Date [ 503.08 183.44]
    /Amount [ 499.96 147.44 ]
    /Verbal [ 36.04 123.44 ]
    /Payee [ 84.04 147.44 ]
    /Memo [ 63.16 39.44 ]
    /Address [ 72.04 99.44 ]
    /Stub false
>> def

/QWalletConfig <<
    /RightMarginX CheckWidth RightMargin sub
    /UnderlineOffset -2
    /MemoLineWidth 2.5 inch
    /SignatureLineWidth 2.5 inch
    /PayToTheOrderOf {
            0 StandardFontSize 2 mul rmoveto  % move up two lines
            0 StandardFontSize neg initline
            (PAY) show nextline
            (TO THE) show nextline
            (ORDER OF ) show
        }
    % QWallet Coords, Check Size 6" x 2.8333"
    /Date [ 346.12 147.44 ]
    /Amount [ 331.96 135.44 ]
    /Verbal [ 24.04 123.44 ]
    /Payee [ 46.12 135.44 ]
    /Address [ 25.0 99.44 ]
    /Memo [ 45.16 39.44 ]
    /Stub true
    /StubDate [ 31.96 147.44 ]
    /StubPayee [ 31.96 123.44 ]
    /StubAmount [ 52.12 87.44 ]
    /StubMemo [ 31.96 63.44 ]
    /StubCategory [ 31.96 39.44 ]
    /StubAccount [ 31.96 15.44 ]
>> def


%
%   /name  (label)  DrawQLabeline-rightmargin  -
%
%   draw label and underline to right margin
%
/DrawQLabeline-rightmargin {
    % show label
    % ^ /name (label)
    exch QCONFIG exch get aload pop  % ^ (label) X Y
    2 copy  % ^ (label) X Y X Y
    moveto  % X Y moveto
    3 -1 roll  % (label) X Y -> X Y (label)
    rightalign show  % (label) rightalign show

    % ^ X Y

    Underline { % if
        % underline
        % line goes from end of label to right margin
        % ^ X Y
        exch ( ) stringwidth pop sub exch % backup X one space
        QCONFIG /UnderlineOffset get add % adjust underline position
        newpath
        dup  % UnderlineY dup
        3 1 roll  % X, Y, Y -> Y, X, Y
        moveto  % X Y moveto
        % UnderlineY is on the stack

        QCONFIG /RightMarginX get
        exch lineto % RightMarginX UnderlineY lineto
        stroke
    }
    % else
    { pop pop }
    ifelse
} def

/DrawQDate {
    /Date (Date  ) DrawQLabeline-rightmargin
} def

/DrawQAmount {
    /Amount ($  ) DrawQLabeline-rightmargin
} def

/DrawQPayee {
    % label: PAY TO THE ORDER OF
    LeftMargin
    QCONFIG /Payee get 1 get  % PayeeY
    moveto  % LeftMargin PayeeY moveto
    QCONFIG /PayToTheOrderOf get exec

    Underline { % if
        % underline: Payee
        % line goes from end of "ORDER OF" to beginning of "$ amount"
        currentpoint
        QCONFIG /UnderlineOffset get add % CurrentY + UnderlineOffset
        newpath
        dup  % UnderlineY dup
        3 1 roll  % X, Y, Y -> Y, X, Y
        moveto  % X Y moveto
        % ^ UnderlineY

        QCONFIG /Amount get 0 get  % AmountX
        ( $  ) stringwidth pop % AdjustX
        sub % PayeeLineEndX = AmountX - AdjustX

        exch lineto % PayeeLineEndX UnderlineY lineto
        stroke
    } if
} def

/DrawQVerbal {
    % label: Dollars
    QCONFIG /RightMarginX get
    ( DOLLARS) stringwidth
	pop % discard yHeight
    sub % RightMarginX - StringWidthX

    % ^ LabelX

    QCONFIG /Verbal get 1 get % VerbalY
    2 copy  % LabelX VerbalY 2 copy
    moveto  % LabelX VerbalY moveto
    ( DOLLARS) show

    % ^ LabelX VerbalY

    Underline { % if
        newpath
        QCONFIG /UnderlineOffset get add % VerbalY + UnderlineOffset
        dup % dup UnderlineY
        3 1 roll % X Y Y -> Y X Y
        moveto % LabelX UnderlineY moveto

        LeftMargin exch lineto % LeftMargin UnderlineY lineto

        stroke
    }
    % else
    { pop pop }
    ifelse
} def

/DrawQMemo {
    % label: Memo
    LeftMargin
    QCONFIG /Memo get 1 get % MemoY
    moveto  % LeftMargin MemoY moveto
    (Memo ) show

    Underline { % if
        % underline: Memo
        0 QCONFIG /UnderlineOffset get rmoveto  % 0 UnderlineOffset rmoveto
        currentpoint
        newpath
        moveto % currentpoint moveto
        QCONFIG /MemoLineWidth get 0 rlineto
        stroke
    } if
} def

/DrawQSignature {
    QCONFIG /RightMarginX get

    % if
    userdict /SignatureLineHeight known
    {
        SignatureLineHeight
    }
    % else
    {
        QCONFIG /Memo get 1 get % MemoY
        QCONFIG /UnderlineOffset get % UnderlineOffset
        add % MemoY UnderlineOffset add
    } ifelse

    % ^ RightMarginX SignatureY
    newpath
    moveto % RightMarginX UnderlineY moveto
    QCONFIG /SignatureLineWidth get neg 0 rlineto
    stroke
} def

%
%   [(string) ...] boldlines  DrawQInfo  -
%
%   Draw array of strings as separate lines of text centered and topaligned
%   to the currentpoint. Null strings are skipped. If the string is non-null
%   and it's index is less than boldlines, the bold font is used.
%
/DrawQInfo {
    0 % counter
    false % istopaligned
    % ^ [(string)] boldlines counter istopaligned
    4 -1 roll % ^ boldlines counter istopaligned [(string)]
    {
        % ^ boldlines counter istopaligned (string)
        dup length 0 gt { % if

            % bold font if one of boldlines
            2 index % counter
            4 index % boldlines
            lt {
	currentfont % save font to stack
	BoldFontName findfont
	StandardFontSize scalefont
	setfont
	5 1 roll % ^ font boldlines counter istopaligned (string)
            } if

            exch % ^ (string) istopaligned
            % if istopaligned
            {
	nextline
	true % istopaligned
            }
            % else
            {
	topalign
	0 StandardFontSize neg initline
	true % istopaligned
            }
            ifelse

            exch % ^ istopaligned (string)
            centeralign show % (string) centeralign show

            % ^ boldlines counter istopaligned

            % restore font if one of boldlines
            1 index % counter
            3 index % boldlines
            lt {
	% ^ font boldlines counter istopaligned
	4 -1 roll % ^ boldlines counter istopaligned font
	setfont % restore font from stack
            } if
        }
        % else
        { pop } % discard (string)
        ifelse

        exch 1 add exch % increment counter
    } forall
    pop % discard istopaligned
    pop % discard counter
    pop % discard boldlines
} def

/DrawQBankInfo {
    QCONFIG /Date get 0 get 4 div 3 mul % DraweeX
    CheckHeight TopMargin sub % DraweeY
    moveto % DraweeX DraweeY moveto
    [ BankName BankAddr1 BankAddr2 BankCityStateZip ] 1 DrawQInfo
} def

/DrawQAccountHolderInfo {
    QCONFIG /Date get 0 get 3 div % DraweeX
    CheckHeight TopMargin sub % DrawerY
    moveto % DrawerX DrawerY moveto
    [ Name1 Name2 Address1 Address2 CityStateZip PhoneNumber ] 2 DrawQInfo
} def

/DrawQCheckNumberAndFraction {
    currentfont % save font to stack
    CheckNumFontName findfont
    CheckNumFontSize scalefont
    setfont

    CheckWidth RightMargin sub % NumberX
    CheckHeight TopMargin sub % NumberY
    moveto % NumberX NumberY moveto
    CheckNumberString topalign
    0 StandardFontSize 1.25 mul neg initline
    rightalign show
    nextline

    FractionFontName findfont
    FractionFontSize scalefont
    setfont

    Fraction topalign rightalign show

    setfont % restore font from stack
} def

%
%  LeftX RightX Y (label)  DrawQStubLabeline  -
%
/DrawQStubLabeline {
    4 -1 roll % ^ RightX Y (label) LeftX
    2 index % Y index
    moveto  % LeftX Y moveto
    % ^ RightX Y (label)
    show % (label) show
    % ^ RightX Y
    QCONFIG /UnderlineOffset get % ^ RightX Y UnderlineOffset
    dup 0 exch rmoveto % Offset start of line
    add % Y UnderlineOffset add
    lineto % RightX Y lineto
} def

/DrawQStub {
    CheckHorOffset 2 inch ge
    QCONFIG /Stub get
    and { % if
        gsave

        CheckHorOffset neg 0 translate

        newpath

        StandardFontName findfont
        StandardFontSize 1 sub scalefont
        setfont

        0.1875 inch % ^ LeftX
        dup CheckHorOffset exch sub % ^ LeftX RightX

        2 copy % LeftX RightX
        QCONFIG /StubDate get 1 get % DateY
        (DATE )
        DrawQStubLabeline

        2 copy % LeftX RightX
        QCONFIG /StubPayee get 1 get % PayeeY
        (PAYEE )
        DrawQStubLabeline

        2 copy % LeftX RightX
        QCONFIG /StubAmount get 1 get % AmountY
        (AMOUNT )
        DrawQStubLabeline

        2 copy % LeftX RightX
        QCONFIG /StubMemo get 1 get % MemoY
        (MEMO )
        DrawQStubLabeline

        2 copy % LeftX RightX
        QCONFIG /StubCategory get 1 get % CategoryY
        (CATG. )
        DrawQStubLabeline

        2 copy % LeftX RightX
        QCONFIG /StubAccount get 1 get % AccountY
        (ACCT. )
        DrawQStubLabeline

        Underline { stroke } if

        CheckNumFontName findfont
        CheckNumFontSize scalefont
        setfont

        % ^ LeftX RightX
        CheckHeight TopMargin sub  moveto % RightX TextTop moveto
        CheckNumberString topalign rightalign show

        pop % LeftX

        grestore
    } if
} def

/DrawQCheckBody {
    DrawQDate
    DrawQAmount
    DrawQPayee
    DrawQVerbal
    DrawQMemo
    DrawQSignature
    DrawQBankInfo
    DrawQAccountHolderInfo
    DrawQCheckNumberAndFraction
    DrawQStub
    /DrawLogo where { pop DrawLogo } if
    /DrawBankLogo where { pop DrawBankLogo } if
} def

/DrawQStandardCheckBody {
    /QCONFIG QStandardConfig def
    DrawQCheckBody
} def

/DrawQWalletCheckBody {
    /QCONFIG QWalletConfig def
    DrawQCheckBody
} def
%%EndProcSet

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Standard Feature Printing Routines                                         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/DrawMICR {
	% 0.25 high, 5.6875 from right edge should be in the middle
	% of the tolerance band
	CheckWidth 0.25 inch moveto
	-5.6875 inch 0 inch rmoveto
	MICRHorTweak MICRVerTweak rmoveto
	% Now we're at the nominal start of the routing number

	MICRFontName findfont
	MICRFontSize scalefont
	setfont

	% Number of digits in the CheckNumberString
	/CheckNumDigit CheckNumberString length 1 sub def

	CheckNumInAuxOnUs {
		CheckNumEnd -1 CheckNumStart {
			CheckNumDigit 0 ge {
				AuxOnUs exch CheckNumberString CheckNumDigit get put
				/CheckNumDigit CheckNumDigit 1 sub def
			} {
				AuxOnUs exch (0) 0 get put
			} ifelse
		} for
	} if


	AuxOnUs stringwidth pop neg 0 rmoveto
	AuxOnUs show

	Routing show

	CheckNumInOnUs {
		CheckNumEnd -1 CheckNumStart {
			CheckNumDigit 0 ge {
				OnUs exch CheckNumberString CheckNumDigit get put
				/CheckNumDigit CheckNumDigit 1 sub def
			} {
				OnUs exch (0) 0 get put
			} ifelse
		} for
	} if

	OnUs show
		
	StandardFontName findfont
	StandardFontSize scalefont
	setfont
} def


/DrawVOID {
	save
	StandardFontName findfont
	50 scalefont
	setfont
	newpath
	CheckWidth 2 div 1 inch moveto
	30 rotate
	(V O I D) stringwidth pop 0 moveto
	(V O I D) true charpath
	stroke
	restore
} def

/DrawCheck {

	% Convert CheckNumber integer to a string
	CheckNumber CheckNumberString cvs
	pop % discard reference to CheckNumberString
	
	PrintCheckBody {
		CheckLayoutDict CheckLayout get exec
	} if

	PrintMICRLine {
		DrawMICR
	} if

	PrintVOID {
		% Draw border around check, and print "VOID" for testing
		0 0 moveto
		CheckWidth 0 lineto
		CheckWidth CheckHeight lineto
		0 CheckHeight lineto

		0 0 lineto

		DrawVOID
	} if

} def

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main Printing Procedure                                                    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

/CurrentPage 1 def

% Replace symbol placeholders with actual glyphs
% Also get starting and ending position for check number
FixMICR

NumPages { % repeat
	/CheckNumber CheckNumber ChecksPerPage add def
	CheckHorOffset CheckVerOffset translate

	StandardFontName findfont
	StandardFontSize scalefont
	setfont

	LineWidth setlinewidth

	% Loop through printing checks, starting with the bottom one

	ChecksPerPage { % repeat
		/CheckNumber CheckNumber 1 sub def
		newpath
		DrawCheck
		stroke
		0 CheckHeight translate
	} repeat

	showpage

	/CheckNumber CheckNumber ChecksPerPage add def
	/CurrentPage CurrentPage 1 add def
} repeat
