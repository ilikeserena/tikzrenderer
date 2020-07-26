#! /usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Digest::MD5 qw(md5_hex);
use File::Copy qw(copy move);
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);

undef $/;

my $PDFLATEX_TIMEOUT = 10;
my $HTML_DIR = "/var/www/html/tikz";
my $OUT_DIR = "$HTML_DIR";
my $TMP_DIR = "$OUT_DIR/tmp";

my $PREAMBLE = <<'EOF';
\documentclass[border=10pt]{standalone}
\usepackage{tikz}

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

my $cgi = new CGI();
my $tikz = $cgi->param('tikz') || '';
my $context = $cgi->param('context') || 'nocontext';

$tikz = trim($tikz);
my $document = md5_hex($tikz);
$document = "${context}_${document}" if $context;

my $logfile = "$TMP_DIR/$document.cgi.log";
my $texfile = "$OUT_DIR/$document.tex";
my $svgfile = "$OUT_DIR/$document.svg";
my $svgzfile = "$OUT_DIR/$document.svgz";

my $gzip_ok = 0;
my $accept_encoding = $ENV{HTTP_ACCEPT_ENCODING};
if ($accept_encoding && $accept_encoding =~ /\bgzip\b/) {
    $gzip_ok = 1;
}

open my $LOG, ">$logfile" or die "Cannot open '$logfile' for writing: $!";
*OLD_STDOUT = *STDOUT;
*OLD_STDERR = *STDERR;
*STDOUT = $LOG;
*STDERR = $LOG;

#map { print "$_=$ENV{$_}\n" } sort keys %ENV;

print "CGI: ";
$cgi->save(*STDOUT);

print "DOC: $document\n";

print "TIKZ: $tikz\n";

my $success = 1;
if (-f $svgzfile)
{
    print "Already rendered. Skipping generation\n";
}
else
{
    if ($tikz =~ m#\\documentclass#)
    {
        $PREAMBLE = undef;
        $success = renderDocument($tikz);
    }
    else
    {
        $PREAMBLE = getPreamble($tikz);
        $success = renderTikz();
    }
}

# done, restore STDOUT/STDERR
*STDOUT = *OLD_STDOUT;
*STDERR = *OLD_STDERR;
close $LOG;

if ($success)
{
    print "Content-Type: image/svg+xml\n";
    if ($gzip_ok)
    {
        print "Content-Encoding: gzip\n";
    }
    print "\n";
 
    if ($gzip_ok)
    {
        open(IMG, $svgzfile) or die "Cannot read from '$svgzfile': $!";
        print while <IMG>;
        close(IMG);
    }
    else
    {
        open(IMG, $svgfile) or die "Cannot read from '$svgfile': $!";
        print while <IMG>;
        close(IMG);
    }
}
else
{
    print "Content-Type: text/png\n\n";
    open(IMG, "$HTML_DIR/error.png") or die "Cannot read from '$HTML_DIR/error.png': $!";
    print while <IMG>;
    close(IMG);
}


sub executeCmd
{
    my $cmd = shift;
    my $stderr_file = shift;

    unlink $stderr_file if $stderr_file;
    $cmd = "$cmd </dev/null";
    $cmd = "$cmd 2>$stderr_file" if $stderr_file;
    print "$cmd\n";
    print `$cmd`;
    my $exitcode = $?;
    print "STDERR: ", `cat $stderr_file` if $stderr_file and -s $stderr_file;
 
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

    print "Failure due to output on STDERR\n" if ($exitcode == 0) and $stderr_file and -s $stderr_file;

    printTimestamp();

    return (($exitcode == 0) and (not $stderr_file or not -s $stderr_file));
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
        my $lines_preamble = 0;
        $lines_preamble = ($PREAMBLE =~ tr#\n##) + 1 if $PREAMBLE;
        my $content = <ERRFH>;
        close ERRFH;

        # Remove pdflatex's preamble up to \n)\n
        $content =~ s#^[\S\s]+\n\)\n+##;    
        # Remove pdflatex's postamble
        $content =~ s#\s*Here is how much of TeX's memory you used[\S\s]*#\n#m;
        # Undo pdflatex's hard line wrapping
        $content =~ s#(^[^\n]{79})\n#$1#gm;

        # Suppress pdflatex's pgfplots compatibility warning
        $content =~ s#^Package pgfplots Warning: running in backwards compatibility mode.*?into your preamble.\n on input line \d+\.\n+##;    
        # Suppress pdflatex's redundant errors
        $content =~ s#^<to be read again>\s*\\par\s*l\.\d+\n##m;
        $content =~ s#^Type  H <return>  for immediate help.\n \.\.\. *\n##m; 

        print "\nERR: $content\n";

        my $found_error = 0;
        while ($content =~ s#^(.*\n)##)
        {
            $_ = $1;
            $found_error = 1 if s/^".*?", line (\d+):/"line ".($1 - $lines_preamble).":"/e;     # lacheck
            $found_error = 1 if s/^.*?$document.*?:(\d+):/"line ".($1 - $lines_preamble).":"/e; # pdflatex
            s/^l\.(\d+) /"l.".($1 - $lines_preamble) /e;                    # Later repetition of pdflatex

            s/\\/\\textbackslash /g;
            s/~/\\textasciitilde /g;
            s/\^/\\textasciicircum /g;
            s/</\\textless /g;
            s/>/\\textgreater /g;
            s/([\$&%#_{}])/\\$1/g;
            s/(\[)/{$1}/g;        # Handle \\ followed by [ optional length construction
            s/(\n)/\\\\$1/;

            print $FH $_;
        }
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
    $success = executeCmd("timeout $PDFLATEX_TIMEOUT pdflatex -no-shell-escape -halt-on-error -file-line-error -output-directory $TMP_DIR $texfile"
        , $tmp_pdflatex_stderr) if $success;

    $success = executeCmd("pdf2svg $tmp_pdffile $tmp_svgfile"
            , $tmp_pdf2svg_stderr) if $success;

    if ($success)
    {
        print "move($tmp_svgfile, $svgfile)\n";
        move($tmp_svgfile, $svgfile) or ($success = 0, print("Could not move file: $!\n"));

        print "\n";
    }

    $success = executeCmd("gzip -c $svgfile > $svgzfile"
            , "$svgzfile.stderr") if $success;

    return $success;
}


sub printTimestamp
{
    my ($s,$us) = gettimeofday();
    printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;
    print "\n";
}


sub trim
{
    my $content = shift;
    $content =~ s#\r##gm;
    $content =~ s#^\s*(.*?)\s*\z#$1#m;
    return $content;
}


sub getPreamble
{
    my $content = shift;
    my $preamble = "";
    while ($content =~ s#^(.*\n)##)
    {
       my $line = $1;
       if ($line =~ m#^\s*%preamble\s+(.*\n)#)
       {
           $preamble .= $1;
       }
    }
    if ($preamble)
    {
        return <<EOF;
\\documentclass[border=10pt]{standalone}
\\usepackage{tikz}

$preamble

% Protect pdflatex from hanging when we have a pending '[' after begin{tikzpicture}
% See: http://tex.stackexchange.com/questions/338869/pdflatex-hangs-on-a-pending
\\makeatletter
\\protected\\def\\tikz\@signal\@path{\\tikz\@signal\@path}%
\\makeatother

\\begin{document}
EOF
    }
    else
    {
        return $PREAMBLE;
    }
}


sub renderTikz
{
    my $latex = <<EOF;
$PREAMBLE
$tikz
$POSTAMBLE
EOF
    return renderDocument($latex);
}

sub renderDocument
{
    my $latex = shift;
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
        my ($s,$us) = gettimeofday();
        my $time_start = $s + $us / 1e6;
        printTimestamp();

        print $FH $latex;
        close $FH;

        my $tmp_lacheck_stderr = "$TMP_DIR/$document.lacheck.stderr";
        $success = executeCmd("unset LD_LIBRARY_PATH ; lacheck $texfile 2>$tmp_lacheck_stderr 1>&2") if $success;
        $success = 0 if -s $tmp_lacheck_stderr;
        if (not $success and -s $tmp_lacheck_stderr)
        {
            print "Checking '$tmp_lacheck_stderr' with size ".(-s $tmp_lacheck_stderr)."\n";
            # Filter out false positives
            open(my $fh, "<:encoding(UTF-8)", $tmp_lacheck_stderr)
                 or die "Can't open '$tmp_lacheck_stderr' for reading: $!";
            my $content = <$fh>;
            close $fh;
            if ($content =~ s#^(.*Dots should be \\ldots.*)\n##gm)
            {
                print "Found false positive: $1\n\n";
                $success = 1;
            }
            if ($content =~ s#^(.*possible unwanted space at "\{".*)\n##gm)
            {
                print "Found false positive: $1\n\n";
                $success = 1;
            }
            open($fh, ">:encoding(UTF-8)", $tmp_lacheck_stderr)
                 or die "Can't open '$tmp_lacheck_stderr' for writing: $!";
            print $fh $content;
            close $fh;
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
        printTimestamp();
        printf "Total rendering time=%.4f s\n", ($time_stop - $time_start);
    }

    return $success;
}

