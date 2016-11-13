#! /usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Carp qw( fatalsToBrowser );
use File::Copy qw(copy move);
use Time::HiRes qw(gettimeofday);
use POSIX qw(strftime);
use Digest::MD5 qw(md5_hex);

my $XAMPP_DIR = "/opt/lampp";
my $OUT_DIR = "$XAMPP_DIR/htdocs/tikz";
my $CGI_DIR = "$XAMPP_DIR/cgi-bin";
my $TMP_DIR = "$OUT_DIR/tmp";

my $PREAMBLE = <<'EOF';
\documentclass[border=10pt,tikz,x11names]{standalone}
\usepackage{amsmath}
\usepackage{sansmath}
\usepackage{tikz}
\usepackage{pgfplots}
\pgfplotsset{compat=1.13}
\usepackage[outline]{contour}
\usetikzlibrary{arrows,automata,positioning,shadows,patterns}

% Protect pdflatex from hanging when we have a pending '[' after begin{tikzpicture}
% See: http://tex.stackexchange.com/questions/338869/pdflatex-hangs-on-a-pending
\makeatletter
\protected\def\tikz@signal@path{\tikz@signal@path}%
\makeatother

\begin{document}
EOF
my $POSTAMBLE = <<'EOF';

\end{document}
EOF

my $cgi = new CGI;
my $tikz = $cgi->param('tikz') || '';
my $context = $cgi->param('context') || '';

my ($s,$us) = gettimeofday();
$tikz =~ s#\r##gm;
$tikz =~ s#^\s*(.*?)\s*\z#$1#m;
my $document = md5_hex($tikz);
$document = "${context}_${document}" if $context;

my $logfile = "$TMP_DIR/$document.cgi.log";
my $texfile = "$OUT_DIR/$document.tex";
my $svgfile = "$OUT_DIR/$document.svg";

open my $LOG, ">$logfile" or die "Cannot open '$logfile' for writing: $!";
*OLD_STDOUT = *STDOUT;
*OLD_STDERR = *STDERR;
*STDOUT = $LOG;
*STDERR = $LOG;

print "DOC: $document\n";

print "TIKZ: $tikz\n";

my $success = 1;
if (-f $svgfile)
{
    print "Already rendered. Skipping generation\n";
}
else
{
    $success = renderTikz();
}

# done, restore STDOUT/STDERR
*STDOUT = *OLD_STDOUT;
*STDERR = *OLD_STDERR;
close $LOG;

if ($success)
{
    print "Content-Type: image/svg+xml\n\n";
    open(IMG, $svgfile) or die "Cannot read from '$svgfile': $!";
    print while <IMG>;
    close(IMG);
}
else
{
    print "Content-Type: text/png\n\n";
    open(IMG, "$CGI_DIR/error.png") or die "Cannot read from '$CGI_DIR/error.png': $!";
    print while <IMG>;
    close(IMG);
}


sub executeCmd
{
    my $cmd = shift;
    my $stderr_file = shift;

    unlink $stderr_file;
    $cmd = "$cmd </dev/null";
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

    return (($exitcode == 0) and not -s $stderr_file);
}


sub generateLatexError
    {
        my $document = shift;
        my $error_file = shift;
        my $error_texfile = "$OUT_DIR/$document.error.tex";
        my $success = 1;
        print "Writing '$error_texfile' with contents of '$error_file' to render the given errors\n";
	if (!open(my $FH, '>:encoding(UTF-8)', $error_texfile))
	{
	    $success = 0;
	    print("Cannot write to '$error_texfile': $!\n");
	}
	else
	{
	    print $FH "\\documentclass[border=10pt, preview]{standalone}\n";
	    print $FH "\\begin{document}\n";
	    open (ERRFH, '<:encoding(UTF-8)', $error_file)
		or ($success = 0, print("Could not read file: $!\n"));
            my $lines_preamble = ($PREAMBLE =~ tr#\n##) + 1;
            my $found_error = 0;
	    while (<ERRFH>)
	    {
		$found_error = 1 if s/^".*?", line (\d+):/"line ".($1 - $lines_preamble).":"/e;
		$found_error = 1 if s/^.*?$document.*?:(\d+):/"line ".($1 - $lines_preamble).":"/e;
                next if not $found_error;

		last if /Here is how much of TeX's memory you used/;

		s/\\/\\textbackslash /g;
		s/~/\\textasciitilde /g;
		s/\^/\\textasciicircum /g;
		s/</\\textless /g;
		s/>/\\textgreater /g;
		s/([\$&%#_{}])/\\$1/g;
		s/(\[)/{$1}/g;	# Handle \\ followed by [ optional length construction
		s/(\n)/\\\\$1/;

		print $FH $_;
	    }
	    close ERRFH;
	    print $FH "\\end{document}\n";
	    close $FH;

            print "Could not find line with error\n" if not $found_error;
            $success = 0 if not $found_error;
            $success = renderLatex("$document.error", $error_texfile) if $success;
	}
        return $success;
    }


sub renderLatex
{
        my $document = shift;
        my $texfile = shift;

        my $success = 1;
        my $tmp_pdflatex_stderr = "$TMP_DIR/$document.pdflatex.stderr";
        my $tmp_pdf2svg_stderr = "$TMP_DIR/$document.pdf2svg.stderr";
        my $tmp_pdffile = "$TMP_DIR/$document.pdf";
        my $tmp_svgfile = "$TMP_DIR/$document.svg";
        unlink $tmp_pdflatex_stderr;
        unlink $tmp_pdf2svg_stderr;
        unlink $tmp_pdffile;
        unlink $tmp_svgfile;
        $success = executeCmd("unset LD_LIBRARY_PATH ; pdflatex -no-shell-escape -halt-on-error -file-line-error -output-directory $TMP_DIR $texfile"
            , $tmp_pdflatex_stderr) if $success;

        $success = executeCmd("unset LD_LIBRARY_PATH ; pdf2svg $tmp_pdffile $tmp_svgfile"
                , $tmp_pdf2svg_stderr) if $success;

        if ($success)
        {
            print "move($tmp_svgfile, $svgfile)\n";
            move($tmp_svgfile, $svgfile) or ($success = 0, print("Could not move file: $!\n"));

            print "\n";
        }
        return $success;
}


sub renderTikz
{
    my $success = 1;

    # Remove previous files if left behind
    unlink $svgfile;
 
    if (!open(my $FH, '>:encoding(UTF-8)', $texfile))
    {
        $success = 0;
        print("Cannot write to '$texfile': $!\n");
    }
    else
    {
        ($s,$us) = gettimeofday();
        my $time_start = $s + $us / 1e6;
        printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;

    print $FH <<EOF;
$PREAMBLE
$tikz
$POSTAMBLE
EOF
        close $FH;

	my $tmp_lacheck_stderr = "$TMP_DIR/$document.lacheck.stderr";
	unlink $tmp_lacheck_stderr;
	if ($success)
	{
	    my $cmd = "unset LD_LIBRARY_PATH ; lacheck $texfile >$tmp_lacheck_stderr 2>&1";
	    print "$cmd\n";
	    print `$cmd`;
	    $success = (($? == 0) and not -s $tmp_lacheck_stderr);
	    print `cat $tmp_lacheck_stderr`;
	    my ($s,$us) = gettimeofday();
	    printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;
	    print "\n";
	}

        if (-s $tmp_lacheck_stderr)
	{
	    $success = generateLatexError($document, $tmp_lacheck_stderr);
 	}
        elsif ($success)
        {
            $success = renderLatex($document, $texfile);
            if (!$success && -s "$TMP_DIR/$document.log")
	    {
	        $success = generateLatexError($document, "$TMP_DIR/$document.log");
 	    }
        }

        ($s,$us) = gettimeofday();
        my $time_stop = $s + $us / 1e6;
        printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;
        printf "Total rendering time=%.4f s\n", ($time_stop - $time_start);
    }

    return $success;
}

