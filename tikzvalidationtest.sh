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

TEST GIVEN_pgfplots_coordinates_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
  \begin{axis}
    \addplot coordinates {(0,1) (0.5,1) (1,1.2)}; 
  \end{axis} 
\end{tikzpicture}'

TEST GIVEN_pgfplots_function_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
  \begin{axis}[xmin=-1.5, xmax=1.5, samples=101]
    \addplot[blue, ultra thick] (x, {cos(deg(x)) / (3*x^2 - pi^2)});
  \end{axis}
\end{tikzpicture}'

TEST GIVEN_automata_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}[shorten >=1pt,node distance=2cm,auto]
  \node[state,initial]    (q_0)                {$q_0$};
  \node[state,accepting]  (q_1) [right of=q_0] {$q_1$};

  \path[->] (q_0) edge [bend left]  node {$a$} (q_1)
            (q_1) edge [bend left]  node {$b$} (q_0);
\end{tikzpicture}'

TEST GIVEN_draw_hyperbola_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
\draw[gray!50, very thin,-triangle 60] (-4,0) -- (4,-0); % x-axis
\draw[gray!50, very thin,-triangle 60] (0,-3) -- (0,3);  % y-axis
\draw[gray!50, very thin] (-2,-1.5) rectangle (2,1.5);
\draw[red,line width=2pt] (2.5,0) -- (2.5,1.125) node[right=1pt] {$\ell=\dfrac{b^2}{a}$}; % semi latus rectum
\draw[domain=-1.3:1.3,smooth,variable=\t,line width=2pt] plot ({2*cosh(\t)},{1.5*sinh(\t)});
\draw[domain=-1.3:1.3,smooth,variable=\t,line width=2pt] plot ({-2*cosh(\t)},{1.5*sinh(\t)});
\node at (-1.2,-2.5) {$\dfrac{x^2}{a^2} - \dfrac{y^2}{b^2}=1$ };
\node at (1.5,-2.5) {$r=\dfrac{b^2}{a - c \cos\theta}$ };
\node at (-1.5,2.5) {$(\pm a \cosh u, b \sinh u)$ };
\draw (-4,-3) -- (4,3);
\draw (4,-3) -- (-4,3);
\node at (-1.2,0.1) {a};
\node at (-1.85,0.75) {b};
\node at (-0.85,0.85) {c};
\draw[triangle 60-triangle 60, green] (0,-0.3) -- (2.5,-0.3);
\node[green] at (1.25,-4pt) {c};
\fill (-2.5,0) circle (0.1); % focus
\fill (2.5,0) circle (0.1);  % focus
\end{tikzpicture}'

TEST GIVEN_pgfplots_histogram_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
\begin{axis}[	tiny,
		width=6in,
		xtick=data,
		ymin=0 ]
	\addplot+[
		hist={ bins=10, density},
		fill=blue!20,
		mark=none,
	] table[ row sep=\\, y index=0 ] {
		data \\ 565 \\ 786 \\ 870 \\ 923 \\ 948 \\ 951 \\ 964 \\ 968 \\
		997 \\1007 \\1013 \\1037 \\1040 \\1051 \\1056 \\1080 \\
		1088 \\1090 \\1102 \\1103 \\1104 \\1120 \\1151 \\1159 \\
		1165 \\1185 \\1189 \\1207 \\1216 \\1233 \\1251 \\1256 \\
		1261 \\1292 \\1312 \\1317 \\1347 \\1358 \\1385 \\1416 \\
		1477 \\1500 \\1514 \\1567 \\1592 \\1588 \\1615 \\1713 \\
	 	2325 \\3168 \\
	};
\end{axis}
\end{tikzpicture}'

TEST GIVEN_draw_astronomical_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
\draw (-4,0) -- (4,0);
\draw (-4,0) circle (1.5);
\draw (-4,-1.5) -- (4,-.2);
\fill[draw=black!50,top color=blue!80,bottom color=black!40] 
    (-4,0) circle (.5) node {Earth};
\fill[draw=black!50,top color=orange!80,bottom color=black!40] 
    (4,0) circle (1) node {Sun};
\fill[draw=black!50,top color=gray,bottom color=black!20]
     (-4,-1.5) circle (.1) node[below = 1pt] {Satellite};
\end{tikzpicture}'

# Validate MarkFL's TikZ Examples
TEST GIVEN_draw_Sudoku_3D_cube_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}[every node/.style={minimum size=1cm},on grid]
	\begin{scope}[every node/.append style={yslant=-0.5},yslant=-0.5]
		\shade[right color=gray!10, left color=black!50] (0,0) rectangle +(3,3);
		\node at (0.5,2.5) {9};
		\node at (1.5,2.5) {7};
		\node at (2.5,2.5) {1};
		\node at (0.5,1.5) {2};
		\node at (1.5,1.5) {4};
		\node at (2.5,1.5) {8};
		\node at (0.5,0.5) {5};
		\node at (1.5,0.5) {3};
		\node at (2.5,0.5) {6};
		\draw (0,0) grid (3,3);
	\end{scope}
	\begin{scope}[every node/.append style={yslant=0.5},yslant=0.5]
		\shade[right color=gray!70,left color=gray!10] (3,-3) rectangle +(3,3);
		\node at (3.5,-0.5) {3};
		\node at (4.5,-0.5) {9};
		\node at (5.5,-0.5) {7};
		\node at (3.5,-1.5) {6};
		\node at (4.5,-1.5) {1};
		\node at (5.5,-1.5) {5};
		\node at (3.5,-2.5) {8};
		\node at (4.5,-2.5) {2};
		\node at (5.5,-2.5) {4};
		\draw (3,-3) grid (6,0);
	\end{scope}
	\begin{scope}[every node/.append style={
			yslant=0.5,xslant=-1},yslant=0.5,xslant=-1
		]
		\shade[bottom color=gray!10, top color=black!80] (6,3) rectangle +(-3,-3);
		\node at (3.5,2.5) {1};
		\node at (3.5,1.5) {4};
		\node at (3.5,0.5) {7};
		\node at (4.5,2.5) {5};
		\node at (4.5,1.5) {6};
		\node at (4.5,0.5) {8};
		\node at (5.5,2.5) {2};
		\node at (5.5,1.5) {3};
		\node at (5.5,0.5) {9};
		\draw (3,0) grid (6,3);
	\end{scope}
\end{tikzpicture}'

TEST GIVEN_draw_belt_and_pulley_system_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}

	% Definitions
	\pgfmathsetmacro{\b}{75}
	\pgfmathsetmacro{\a}{15}
	\pgfmathsetmacro{\R}{2}
	\pgfmathsetmacro{\r}{1}
	\pgfmathsetmacro{\P}{\R*tan(\b)}
	\pgfmathsetmacro{\Q}{\R/cos(\b)}
	\pgfmathsetmacro{\p}{\r/tan(\a)}
	\pgfmathsetmacro{\q}{\r/sin(\a)}

	% Pulleys

	% big pulley
	\draw (0,0) circle (\R) ;
	\fill[left color=gray!80, right color=gray!60, middle
	color=white] (0,0) circle (\R) ;
	\draw[thick, white] (0,0) circle (.8*\R);
	\shade[ball color=white] (0,0) circle (.3) node[left,xshift=-5] {$P$};

	% small pulley
	\draw (\Q+\q-.3, 0) circle (\r);
	\fill[left color=gray!80, right color=gray!60, middle
	color=white] (\Q+\q-.3, 0) circle (\r) ;
	\draw[thick, white] (\Q+\q-.3,0) circle (.8*\r);
	\shade[ball color=white] (\Q+\q-.3,0) circle (.15) 
	node[right, xshift=2] {$Q$};

	% belt and point labels
	\begin{scope}[ultra thick]
	\draw (\b:\R) arc (\b:360-\b:\R) ;
	\draw (\b:\R) -- ( \P, 0 ); 
	\draw (-\b:\R) -- ( \P, 0 );
	\draw (\Q-.3,0) -- + (\a:\p)  arc (105:-105:\r) ;
	\draw (\Q-.3,0) -- + (-\a:\p);
	%\draw (\b:\R) arc (\b:360-\b:\r) ;
	\end{scope}

	\draw (0,0) -- (\b:\R) node[midway, above,sloped] {$R$} node[above] {$A$};
	\draw (-\b:\R)--(0,0) ;
	\draw (\Q+\q-.3,0) -- +(105:\r) node[midway,above, sloped] {$r$}
	node[above] {$E$};
	\draw (\Q+\q-.3,0) -- +(-105:\r) node[below] {$D$};
	\node[below] at (-\b:\R) {$B$};
	\node[below] at (\Q-.3,0) {$C$};

	% center line
	\draw[dash pattern=on5pt off3pt] (0,0) -- (\Q+\q-.3,0);

	% angle label
	\node[fill=white] at (0.73*\Q, 0) {$\theta$} ;
	\draw (\Q-1.8,0) arc (180:195:1.5);
	\draw (\Q-1.8,0) arc (180:165:1.5);
\end{tikzpicture}'

# Use of cached version (performance)

# Protection of used disk size (performance)

# Validate tikzlive.html

# Validate tikztest.pl

