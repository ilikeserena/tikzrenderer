#!/bin/bash -e

SCRIPT_LOCATION=${PWD##*/}
echo "TESTING scripts in '$SCRIPT_LOCATION'"

function finish {
    EXITCODE=$?
    if [ $EXITCODE = 0 ]; then
       echo "SUCCESS"
    else
       echo "FAILED with \$?=$EXITCODE"
    fi
}

trap finish EXIT

# Flush cache and previous output
sudo find /opt/lampp/htdocs/tikz -name "test_*" -exec rm {} \;
[ -d out/ ] && rm -r out/
mkdir out/

function TEST {
    TEST_NAME="$1"
    TIKZ="$2"
    curl --silent "http://localhost/$SCRIPT_LOCATION/tikzrendersvg.pl?context=test" --get --data-urlencode "tikz=$TIKZ" >out/$TEST_NAME.svg
    diff --brief out/$TEST_NAME.svg ref/$TEST_NAME.svg
}

set -v

# Nominal sunny day scenario
TEST nominal \
    '\begin{tikzpicture} \draw (0,0) -- (1,1); \end{tikzpicture}' 

# lacheck error
TEST GIVEN_lacheck_error_WHEN_tikzrendersvg_THEN_lacheck_error \
    '\begin{tikzpicturez} \draw (0,0) -- (1,1); \end{tikzpicture}'

# dots (...) work regardless of lacheck error
TEST GIVEN_lacheck_dots_error_WHEN_tikzrendersvg_THEN_dots_render \
    '\begin{tikzpicture} \foreach \x in {1,...,3} \draw (\x,0.1) -- (\x,-0.1) node[below] {\x}; \end{tikzpicture}'

# dots (...) with other lacheck error fails
TEST GIVEN_lacheck_dots_and_other_error_WHEN_tikzrendersvg_THEN_lacheck_error \
    '\begin{tikzpicture} \foreach \x in {1,...,3} \draw (\x,0.1) -- (\x,-0.1) node[below] {\x}; \end{tikzpicturez}'

# pdflatex error
TEST GIVEN_pdflatex_error_WHEN_tikzrendersvg_THEN_pdflatex_error \
    '\begin{tikzpicture} \drawz (0,0) -- (1,1); \end{tikzpicture}' 

# pdf2svg error
# TODO

# permission error
# TODO

# preamble with special library
TEST GIVEN_preamble_with_feature_WHEN_tikzrendersvg_THEN_feature_renders '
    \begin{tikzpicture}
      %preamble \usetikzlibrary{arrows.meta}
      \draw[-{Stealth[scale=1.3,inset=1pt, angle=90:10pt]},semithick] (0,0) -- (3,0);
    \end{tikzpicture}'

# preamble with missing library
TEST GIVEN_preamble_with_missing_feature_WHEN_tikzrendersvg_THEN_feature_fails '
    \begin{tikzpicture}
      %preamble \usetikzlibrary{mindmap}
      \draw[-{Stealth[scale=1.3,inset=1pt, angle=90:10pt]},semithick] (0,0) -- (3,0);
    \end{tikzpicture}'

# Validate announced examples

# Use of cached version (performance)

# Protection of used disk size (performance)

# Validate tikzlive.html

# Validate tikztest.pl

