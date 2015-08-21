#!/bin/bash

FILE1=/usr/local/lso/src/mars/main.pl
FILE2=/usr/local/lso/src/mars/treebuilder.pl
TARGET=/usr/local/lso/bin
file1=${FILE1##*/}
file2=${FILE2##*/}
ln -sfn $FILE1 $TARGET/$file1
ln -sfn $FILE2 $TARGET/$file2


