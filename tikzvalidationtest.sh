#!/bin/bash -e

SCRIPT_LOCATION=cgi-bin
HTML_TIKZ_DIR=/var/www/html/tikz
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
sudo find "$HTML_TIKZ_DIR" -name "test_*" -exec rm {} \;
[ -d out/ ] && rm -r out/
mkdir out/

function TEST {
    TEST_NAME="$1"
    TIKZ="$2"

    # Test directly
    #export HTTP_COOKIE=...
    #export HTTP_HOST=test.example.com
    #export HTTP_REFERER=...
    #export HTTP_USER_AGENT=...
    #export PATH_INFO=
    #export QUERY_STRING=$(/opt/lampp/bin/perl -MURI::Escape -e 'print "context=test&tikz=".uri_escape($ARGV[0]);' "$TIKZ")
    #export REQUEST_METHOD=GET
    #/opt/lampp/bin/perl tikzrendersvg.pl | tail --lines +3 > out/$TEST_NAME.svg

    # Test through curl
    curl --silent "http://localhost/$SCRIPT_LOCATION/tikzrendersvg.pl?context=test" --get --data-urlencode "tikz=$TIKZ" > out/$TEST_NAME.svg

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

# Newline and space after "{" works regardless of lacheck error
TEST GIVEN_lacheck_space_after_brace_error_WHEN_tikzrendersvg_THEN_dots_render '
    \begin{tikzpicture}
        \foreach \x in {1,2} {
            \draw (\x,0.1) -- (\x,-0.1) node[below] { \x };
        }
    \end{tikzpicture}'

# dots with other lacheck error fails
TEST GIVEN_lacheck_dots_and_other_error_WHEN_tikzrendersvg_THEN_lacheck_error \
    '\begin{tikzpicture} \foreach \x in {1,...,3} \draw (\x,0.1) -- (\x,-0.1) node[below] {\x}; \end{tikzpicturez}'

# pdflatex error
TEST GIVEN_pdflatex_error_WHEN_tikzrendersvg_THEN_pdflatex_error \
    '\begin{tikzpicture} \drawz (0,0) -- (1,1); \end{tikzpicture}' 

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
  %preamble \usepackage{pgfplots}
  \begin{axis}
    \addplot coordinates {(0,1) (0.5,1) (1,1.2)}; 
  \end{axis} 
\end{tikzpicture}'

TEST GIVEN_pgfplots_function_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
  %preamble \usepackage{pgfplots}
  \begin{axis}[xmin=-1.5, xmax=1.5, samples=101]
    \addplot[blue, ultra thick] (x, {cos(deg(x)) / (3*x^2 - pi^2)});
  \end{axis}
\end{tikzpicture}'

TEST GIVEN_automata_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}[shorten >=1pt,node distance=2cm,auto]
  %preamble \usetikzlibrary{automata}
  \node[state,initial]    (q_0)                {$q_0$};
  \node[state,accepting]  (q_1) [right of=q_0] {$q_1$};

  \path[->] (q_0) edge [bend left]  node {$a$} (q_1)
            (q_1) edge [bend left]  node {$b$} (q_0);
\end{tikzpicture}'

TEST GIVEN_draw_hyperbola_example_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
%preamble \usepackage{amsmath}
%preamble \usetikzlibrary{arrows}
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
%preamble \usepackage{pgfplots}
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
        %preamble \usetikzlibrary{positioning}
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

TEST GIVEN_draw_Escher_Brick_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}[scale=4.5, line join=bevel]
	% \a and \b are two macros defining characteristic
	% dimensions of the impossible brick.
	\pgfmathsetmacro{\a}{0.18}
	\pgfmathsetmacro{\b}{1.37}

	\tikzset{%
		apply style/.code={\tikzset{#1}},
		brick_edges/.style={thick,draw=black},
		face_coloura/.style={fill=gray!50},
		face_colourb/.style={fill=gray!25},
		face_colourc/.style={fill=gray!90},
	}

	\foreach \theta/\v/\facestyleone/\facestyletwo in {%
	0/0/{brick_edges,face_coloura}/{brick_edges,face_colourc},
	180/-\a/{brick_edges,face_colourb}/{brick_edges,face_colourc}
	}{
		\begin{scope}[rotate=\theta,shift={(\v,0)}]
			\draw[apply style/.expand once=\facestyleone]  		
			({-.5*\b},{1.5*\a}) --
			++(\b,0)            --
			++(-\a,-\a)         --
			++({-\b+2*\a},0)    --
			++(0,-{2*\a})       --
			++(\b,0)            --
			++(-\a,-\a)         --
			++(-\b,0)           --
			cycle;
			\draw[apply style/.expand once=\facestyletwo] 
			({.5*\b},{1.5*\a})  --
			++(0,{-2*\a})       --
			++(-\a,0)           --
			++(0,\a)            --
			cycle;
		\end{scope}
	}
\end{tikzpicture}'

TEST GIVEN_draw_Penrose_Triangle_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}[scale=1, line join=bevel]

	% \a and \b are two macros defining characteristic
	% dimensions of the Penrose triangle.		
	\pgfmathsetmacro{\a}{2.5}
	\pgfmathsetmacro{\b}{0.9}

	\tikzset{%
	apply style/.code = {\tikzset{#1}},
	triangle_edges/.style = {thick,draw=black}
	}

	\foreach \theta/\facestyle in {%
	0/{triangle_edges, fill = gray!50},
	120/{triangle_edges, fill = gray!25},
	240/{triangle_edges, fill = gray!90}%
	}{
		\begin{scope}[rotate=\theta]
			\draw[apply style/.expand once=\facestyle]
			({-sqrt(3)/2*\a},{-0.5*\a})                     --
			++(-\b,0)                                       --
			({0.5*\b},{\a+3*sqrt(3)/2*\b})                -- % higher point	
			({sqrt(3)/2*\a+2.5*\b},{-.5*\a-sqrt(3)/2*\b}) -- % rightmost point
			++({-.5*\b},-{sqrt(3)/2*\b})                    -- % lower point
			({0.5*\b},{\a+sqrt(3)/2*\b})                  --
			cycle;
		\end{scope}
	}	
\end{tikzpicture}'

TEST GIVEN_draw_Electric_dipole_moment_in_water_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}[>=latex,scale=1.3]
	\shade[ball color=gray!10!] (0,0) coordinate(Hp) circle (.9) ;
	\shade[ball color=gray!10!] (2,-1.53) coordinate(O) circle (1.62) ;
	\shade[ball color=gray!10!] (4,0) coordinate(Hm) circle (.9) ;
	\draw[thick,dashed] (0,0) -- (2,-1.53) -- (4,0) ;
	\draw[thick] (2,.2) -- (2,1.5) node[right]{$\mathbf{p}$} ;
	\draw (2.48,-1.2) arc (33:142:.6)  ;
	\draw (2,-.95) node[above]{$105^{\circ}$} ;
	\draw (0,.2) node[left]{H$^+$} ;
	\draw (4,.2) node[right]{H$^-$} ;
	\draw (2,-1.63) node[below]{O$^{2-}$} ;
	\foreach \point in {O,Hp,Hm}
		\fill [black] (\point) circle (2pt) ;
\end{tikzpicture}'

TEST GIVEN_draw_Parallel_lines_and_related_angles_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
	\draw[fill=yellow] (0,0) -- (60:.75cm) arc (60:180:.75cm);
	\draw(120:0.4cm) node {$\alpha$};

	\draw[fill=green!30] (0,0) -- (right:.75cm) arc (0:60:.75cm);
	\draw(30:0.5cm) node {$\beta$};

	\begin{scope}[shift={(60:2cm)}]
		\draw[fill=green!30] (0,0) -- (180:.75cm) arc (180:240:.75cm);
		\draw (30:-0.5cm) node {$\gamma$};

		\draw[fill=yellow] (0,0) -- (240:.75cm) arc (240:360:.75cm);
		\draw (-60:0.4cm) node {$\delta$};
	\end{scope}

	\begin{scope}[thick]
		\draw (60:-1cm) node[fill=white] {$E$} -- (60:3cm) node[fill=white] {$F$};
		\draw[red]                   (-2,0) node[left] {$A$} -- (3,0) 
											node[right]{$B$};
		\draw[blue,shift={(60:2cm)}] (-3,0) node[left] {$C$} -- (2,0) 
											node[right]{$D$};
		\draw[shift={(60:1cm)},xshift=4cm]
			node [right,text width=6cm,rounded corners,fill=red!20,inner sep=1ex]
			{
				When we assume that $\color{red}AB$ and $\color{blue}CD$ are
				parallel, I.\,e., ${\color{red}AB} \mathbin{\|} \color{blue}CD$,
				then $\alpha = \delta$ and $\beta = \gamma$.
			};
	\end{scope}
\end{tikzpicture}'

TEST GIVEN_draw_Intersection_of_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
        %preamble \usetikzlibrary{arrows}
        [
	scale=5,
	axis/.style={very thick, ->, >=stealth'"'"'},
	important line/.style={thick},
	dashed line/.style={dashed, thin},
	pile/.style={thick, ->, >=stealth'"'"', shorten <=2pt, shorten
	>=2pt},
	every node/.style={color=black}
	]
	% axis
	\draw[axis] (-0.1,0)  -- (1.1,0) node(xline)[right]
		{$G\uparrow/T\downarrow$};
	\draw[axis] (0,-0.1) -- (0,1.1) node(yline)[above] {$E$};
	% Lines
	\draw[important line] (.15,.15) coordinate (A) -- (.85,.85)
		coordinate (B) node[right, text width=5em] {$Y^O$};
	\draw[important line] (.15,.85) coordinate (C) -- (.85,.15)
		coordinate (D) node[right, text width=5em] {$\mathit{NX}=x$};
	% Intersection of lines
	\fill[red] (intersection cs:
		first line={(A) -- (B)},
		second line={(C) -- (D)}) coordinate (E) circle (.4pt)
		node[above,] {$A$};
	% The E point is placed more or less randomly
	\fill[red]  (E) +(-.075cm,-.2cm) coordinate (out) circle (.4pt)
		node[below left] {$B$};
	% Line connecting out and ext balances
	\draw [pile] (out) -- (intersection of A--B and out--[shift={(0:1pt)}]out)
		coordinate (extbal);
	\fill[red] (extbal) circle (.4pt) node[above] {$C$};
	% line connecting out and int balances
	\draw [pile] (out) -- (intersection of C--D and out--[shift={(0:1pt)}]out)
		coordinate (intbal);
	\fill[red] (intbal) circle (.4pt) node[above] {$D$};
	% line between out og all balanced out :)
	\draw[pile] (out) -- (E);
\end{tikzpicture}'

TEST GIVEN_draw_Intersecting_lines_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}[scale=1.5]
	% Draw axes
	\draw [<->,thick] (0,2) node (yaxis) [above] {$y$}
		|- (3,0) node (xaxis) [right] {$x$};
	% Draw two intersecting lines
	\draw (0,0) coordinate (a_1) -- (2,1.8) coordinate (a_2);
	\draw (0,1.5) coordinate (b_1) -- (2.5,0) coordinate (b_2);
	% Calculate the intersection of the lines a_1 -- a_2 and b_1 -- b_2
	% and store the coordinate in c.
	\coordinate (c) at (intersection of a_1--a_2 and b_1--b_2);
	% Draw lines indicating intersection with y and x axis. Here we use
	% the perpendicular coordinate system
	\draw[dashed] (yaxis |- c) node[left] {$y'"'"'$}
		-| (xaxis -| c) node[below] {$x'"'"'$};
	% Draw a dot to indicate intersection point
	\fill[red] (c) circle (2pt);
\end{tikzpicture}'


TEST GIVEN_draw_cd_in_node_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
  \usetikzlibrary{cd}
  \node {
    \begin{tikzcd}
      A \arrow{r}{f} \arrow{d}{\alpha} & B \arrow{d}{\beta} \\
      C \arrow{r}{g} & D
    \end{tikzcd}
  };
\end{tikzpicture}'

TEST GIVEN_draw_karnaugh_map_in_node_WHEN_tikzrendersvg_THEN_example_renders '
\begin{tikzpicture}
  %preamble \usepackage{karnaugh-map}
  \node {
    \begin{karnaugh-map}[4][4][1][$ba$][$dc$]
      \minterms{0,1,2,3,8,10}
      \terms{13}{$X^*$}
      \indeterminants{15}
      \autoterms[0]
      \implicantcorner[0,2]
      \implicant{1}{3}[0,1,2,3]
      \implicantedge{4}{12}{6}{14}[1,3]
      \implicant{13}{15}[0,2]
    \end{karnaugh-map}
  };
\end{tikzpicture}'


# Clean up if we get here
sudo find "$HTML_TIKZ_DIR" -name "test_*" -exec rm {} \;
rm -r out/

