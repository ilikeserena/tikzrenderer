#! /usr/bin/perl

use strict;
use warnings;

use CGI;
use File::Copy qw(copy move);
use Time::HiRes qw(gettimeofday);
use POSIX qw(strftime);
use Digest::MD5 qw(md5 md5_hex md5_base64);

my $XAMPP_DIR = "/opt/lampp";
my $OUT_DIR = "$XAMPP_DIR/htdocs/tikz";
my $TMP_DIR = "$OUT_DIR/tmp";

my $cgi = new CGI;
my $tikz = $cgi->param( 'tikz' ) || '';

my ($s,$us) = gettimeofday();
my $tikzForMd5 = $tikz;
$tikzForMd5 =~ s#%[^\n]*##gm;
$tikzForMd5 =~ s#[\s\r\n]+# #gm;
$tikzForMd5 =~ s#^\s*(.*?)\s*$#$1#;
my $document = "tikztest_" . md5_hex($tikzForMd5);
print "DOC: $document\n";
my $tmptexfile = "$TMP_DIR/$document.tex";
my $tmppdffile = "$TMP_DIR/$document.pdf";
my $tmp_pdflatex_stderr = "$TMP_DIR/$document.pdflatex.stderr";
my $tmp_pdf2svg_stderr = "$TMP_DIR/$document.pdf2svg.stderr";
my $tmp_convert_stderr = "$TMP_DIR/$document.convert.stderr";
my $tmppngfile = "$TMP_DIR/$document.png";
my $tmpsvgfile = "$TMP_DIR/$document.svg";
my $pngfile = "$OUT_DIR/$document.png";
my $svgfile = "$OUT_DIR/$document.svg";


#print "Last-Modified: Wed, 20 May 1998 14:59:42 GMT\n";
#print "ETag: \"$document\"\n";
print "Content-Type: text/html\n\n";


my $initial_png_file = "/tikz/rendering.png";
$initial_png_file = "/tikz/placeholder.png" if ($tikz !~ m#\S#m);

print <<EOF;
<html>
<body>
<form action="/cgi-bin/tikztest.pl" method="post">
  <p>svg:<br/><img id="svg" src="$initial_png_file"></img></p>
  <p>png:<br/><img id="png" src="$initial_png_file"></img></p>
  <p>rendersvg:<br/><img id="rendersvg" src="$initial_png_file"></img></p>
  <p>tikz:<br/><textarea name="tikz" cols="120" rows="16">
$tikz
  </textarea></p>
  <p><input type="submit" value="Submit"></p>
</form>
EOF

if ($tikz =~ m#\S#m)
{
my $success = 1;

print <<EOF;
  <p>log:<br/><textarea id="log" cols="120" rows="16">
EOF

if (-f $pngfile and -f $svgfile)
{
	# Nothing to do
	print "'$pngfile' already exists\n";
	print "'$svgfile' already exists\n";
	print "Skipping generation\n";
}
else
{

# Remove previous files if left behind
unlink $pngfile;
unlink $svgfile;
unlink $tmppngfile;
unlink $tmpsvgfile;
unlink $tmp_pdflatex_stderr;
unlink $tmp_convert_stderr;

if (!open(FH, ">$tmptexfile"))
{
	$success = 0;
	print("Cannot write to '$tmptexfile': $!\n");
}
else
{
	($s,$us) = gettimeofday();
	my $time_start = $s + $us / 1e6;
	printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;

print FH <<EOF;
\\documentclass[border=10pt,tikz,x11names]{standalone}
\\usepackage{amsmath}
\\usepackage{sansmath} %for the sans serif font
\\usepackage{tikz}
\\usepackage{pgfplots}
\\pgfplotsset{compat=1.13}
\\usepackage[outline]{contour}
\\usetikzlibrary{arrows,automata,positioning,shadows}
\\begin{document}

$tikz

\\end{document}
EOF
	close FH;

	$success = executeCmd("unset LD_LIBRARY_PATH ; pdflatex --shell-escape -file-line-error -interaction=nonstopmode -output-directory $TMP_DIR $tmptexfile"
			, $tmp_pdflatex_stderr);

	$success = executeCmd("unset LD_LIBRARY_PATH ; pdf2svg $tmppdffile $tmpsvgfile"
				, $tmp_pdf2svg_stderr) if $success;

	$success = executeCmd("unset LD_LIBRARY_PATH ; convert -density 150 $tmppdffile -trim -quality 90 $tmppngfile"
				, $tmp_convert_stderr) if $success;

	if ($success)
	{
		print "move($tmpsvgfile, $svgfile)\n";
		move($tmpsvgfile, $svgfile) or ($success = 0, print("Could not move file: $!\n"));
		print "\n";

		print "move($tmppngfile, $pngfile)\n";
		move($tmppngfile, $pngfile) or ($success = 0, print("Could not move file: $!\n"));
		print "\n";
	}

	($s,$us) = gettimeofday();
	my $time_stop = $s + $us / 1e6;
	printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;
	printf "Total rendering time=%.4f s\n", ($time_stop - $time_start);
}
}

print <<EOF;
</textarea></p>
EOF

if ($success)
{
print <<EOF;
<script>
  var svgImg = document.getElementById('svg');
  svgImg.src = "/tikz/$document.svg";
  var pngImg = document.getElementById('png');
  pngImg.src = "/tikz/$document.png";
</script>
EOF
}
else
{
print <<EOF;
<script>
  var svgImg = document.getElementById('svg');
  svgImg.src = "/tikz/error.png";
  var pngImg = document.getElementById('png');
  pngImg.src = "/tikz/error.png";
</script>
EOF
}
}

my $tikzArg = $tikz;
$tikzArg =~ s#[\s\r\n]+# #g;
$tikzArg =~ s#\\#\\\\#g;
$tikzArg =~ s#'#\\'#g;
print <<EOF;
<script>
  var text = encodeURIComponent('$tikzArg');
  var rendersvgImg = document.getElementById('rendersvg');
  rendersvgImg.src = 'http://94.208.84.50:3080/cgi-bin/tikzrendersvg.work.pl?context=work&tikz=' + text;
</script>
EOF


print <<EOF;
</body>
<script>
  var logTextArea = document.getElementById('log');
  logTextArea.scrollTop = logTextArea.scrollHeight;
</script>
</html>
EOF

sub executeCmd
{
    my $cmd = shift;
    my $stderr_file = shift;

    unlink $stderr_file;
    $cmd = "$cmd 2>$stderr_file" if $stderr_file;
    print "$cmd\n";
    print `$cmd`;
    my $exitcode = $?;
    print "STDERR: ", `cat $stderr_file` if -s $stderr_file;
 
    if ($exitcode == -1)
    {
        print "EXITSTATUS: failed to execute: $!\n";
    }
    elsif ($exitcode & 127)
    {
        printf "EXITSTATUS: command died with signal %d, %s coredump\n",
            ($exitcode & 127),  ($exitcode & 128) ? 'with' : 'without';
    }
    else
    {
        printf "EXITSTATUS: command exited with value %d\n", $exitcode >> 8;
    }

    print "Failure due to output on STDERR\n" if ($exitcode == 0) and -s $stderr_file;

    my ($s,$us) = gettimeofday();
    printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;
    print "\n";

    return ($exitcode == 0) and not -s $stderr_file;
}

