#!/bin/bash

FILES=/usr/local/lso/src/mars/*
TARGET=/usr/local/lso/bin
for file in $FILES
do
	if [ "$file" == "mkLink.sh" ]; then
		continue;
	fi
	if [ "$file" == "mars.cfg" ]; then
		continue;
	fi
	echo "Processing $file ..."
	if [ -f $TARGET/$file ]; then
		echo "$file already exists in $TARGET"
		read -r -p "Overwrite? [y/N] " yn
		case $yn in 
			[Yy]* ) ln -sfn $file $TARGET/$file; continue;;
			[Nn]* ) continue;;	
			* ) echo "Please enter yes or no.";;
		esac
	fi
done


