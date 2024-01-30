#!/usr/bin/env bash

DIR=`dirname $0`

ROOT=`python $DIR/findroot.py $1`

YA=${YA:-$ROOT/ya}

if [ -d $ROOT/.svn ]; then
    $YA make --checkout -j0 $1
fi

$YA make --add-result=".h" --add-result=".hh" --add-result=".hpp" --add-result=".c" --add-result=".cc" --add-result=".cpp" --output $ROOT/.ycm --keep-going --no-src-links --replace-result -r $1
