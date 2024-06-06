#!/bin/bash

#/CourierPrime·  ·       ·       ·       ($HOME/Library/Fonts/CourierPrime-Regular.ttf)·   ·       ;
#/CourierPrime,Bold·     ·       ·       ($HOME/Library/Fonts/CourierPrime-Bold.ttf)·      ·       ;
#/CourierPrime,Italic·   ·       ·       ($HOME/Library/Fonts/CourierPrime-Italic.ttf)·    ·       ;
#/CourierPrime,BoldItalic·       ·       ($HOME/Library/Fonts/CourierPrime-BoldItalic.ttf)··       ;

fontfile='Library/Fonts/Courier 10 Pitch BT.ttf'
if [ ! -f "$HOME/$fontfile" ]; then
	echo Please obtain the Courier 10 Pitch BT font and place it in:
	printf "\t$HOME/$fontfile\n"
    echo
    echo It is available from:
    echo 'https://github.com/thiagoeramos/redtape/blob/master/resources/_fonts/Courier%2010%20Pitch%20BT.ttf'
	exit 1
fi

text="$(printf "/CourierPitchBT\t\t\t\t(%s/Library/Fonts/%s)\t\t;" "$HOME" "$fontfile")"

fontmaps=/opt/homebrew/share/ghostscript/*/Resource/Init/Fontmap.GS

for fontmap in $fontmaps; do

	if [ ! -f "$fontmap" ]; then
		echo Ghostscript doesn\'t seem to be installed. Make sure that the file
		printf "%s exists.\n" "$fontmap"
		exit 1
	fi
	
	fgrep -qx "$text" "$fontmap"
	rc=$?
	
	if [ $rc == 1 ]; then
	
		printf "%s\n" "$text" >> "$fontmap" &&
		echo Courier 10 Pitch BT added to Ghostscript as CourierPitchBT
		exit 0
	
	elif [ $rc == 0 ]; then
	
		echo Courier 10 Pitch BT already installed in Ghostscript as CourierPitchBT
		exit 0
	
	else
	
		echo Error from fgrep
		exit $rc
	fi

done
