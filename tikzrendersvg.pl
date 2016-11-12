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

my $cgi = new CGI;
my $tikz = $cgi->param('tikz') || '';
my $context = $cgi->param('context') || '';

my ($s,$us) = gettimeofday();
my $tikzForMd5 = $tikz;
$tikzForMd5 =~ s#%[^\n]*##gm;
$tikzForMd5 =~ s#[\s\r\n]+# #gm;
$tikzForMd5 =~ s#^\s*(.*?)\s*$#$1#;
my $document = md5_hex($tikzForMd5);
$document = "${context}_${document}" if $context;

my $logfile = "$TMP_DIR/$document.cgi.log";
my $tmptexfile = "$TMP_DIR/$document.tex";
my $tmppdffile = "$TMP_DIR/$document.pdf";
my $tmp_lacheck_stderr = "$TMP_DIR/$document.lacheck.stderr";
my $tmp_pdflatex_stderr = "$TMP_DIR/$document.pdflatex.stderr";
my $tmp_pdf2svg_stderr = "$TMP_DIR/$document.pdf2svg.stderr";
my $tmp_convert_stderr = "$TMP_DIR/$document.convert.stderr";
my $tmppngfile = "$TMP_DIR/$document.png";
my $tmpsvgfile = "$TMP_DIR/$document.svg";
my $pngfile = "$OUT_DIR/$document.png";
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

sub renderTikz
{
    my $success = 1;

    # Remove previous files if left behind
    unlink $pngfile;
    unlink $svgfile;
    unlink $tmppngfile;
    unlink $tmpsvgfile;
    unlink $tmp_pdflatex_stderr;
    unlink $tmp_convert_stderr;

    if (!open(my $FH, '>:encoding(UTF-8)', $tmptexfile))
    {
        $success = 0;
        print("Cannot write to '$tmptexfile': $!\n");
    }
    else
    {
        ($s,$us) = gettimeofday();
        my $time_start = $s + $us / 1e6;
        printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;

    print $FH <<EOF;
\\documentclass[border=10pt,tikz,x11names]{standalone}
\\usepackage{amsmath}
\\usepackage{sansmath}
\\usepackage{tikz}
\\usepackage{pgfplots}
\\pgfplotsset{compat=1.13}
\\usepackage[outline]{contour}
\\usetikzlibrary{arrows,automata,positioning,shadows,patterns}
\\begin{document}

$tikz

\\end{document}
EOF
        close $FH;

	if ($success)
	{
	    my $cmd = "unset LD_LIBRARY_PATH ; lacheck $tmptexfile >$tmp_lacheck_stderr 2>&1";
	    print "$cmd\n";
	    print `$cmd`;
	    $success = (($? == 0) and not -s $tmp_lacheck_stderr);
	    print `cat $tmp_lacheck_stderr`;
	    if (0)
	    {
	        print "Replacing content in '$tmptexfile' by '$tmp_lacheck_stderr' to render the given errors\n";
		if (!open(my $FH, '>:encoding(UTF-8)', $tmptexfile))
		{
		    $success = 0;
		    print("Cannot write to '$tmptexfile': $!\n");
		}
		else
		{
		    print $FH "\\documentclass[border=10pt, preview]{standalone}\n";
		    print $FH "\\begin{document}\n";
		    open (ERRFH, '<:encoding(UTF-8)', $tmp_lacheck_stderr)
			or ($success = 0, print("Could not read file: $!\n"));
		    while (<ERRFH>)
		    {
			# TODO: Subtract nr lines preamble properly
			s/^".*?", line (\d+)/"line ".($1 - 10)/e;
			s/\\/\\textbackslash /g;
			s/~/\\textasciitilde /g;
			s/\^/\\textasciicircum /g;
			s/</\\textless /g;
			s/>/\\textgreater /g;
			s/([\$&%#_{}])/\\$1/g;
			s/(\n)/\\\\$1/;
			print $FH $_;
		    }
		    close ERRFH;
		    print $FH "\\end{document}\n";
        	    close $FH;
		}
	    }
	    my ($s,$us) = gettimeofday();
	    printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;
	    print "\n";
	}

        $success = executeCmd("unset LD_LIBRARY_PATH ; pdflatex -no-shell-escape -output-directory $TMP_DIR $tmptexfile"
            , $tmp_pdflatex_stderr) if $success;

        $success = executeCmd("unset LD_LIBRARY_PATH ; pdf2svg $tmppdffile $tmpsvgfile"
                , $tmp_pdf2svg_stderr) if $success;

        if ($success)
        {
            print "move($tmpsvgfile, $svgfile)\n";
            move($tmpsvgfile, $svgfile) or ($success = 0, print("Could not move file: $!\n"));

            print "\n";
        }

        ($s,$us) = gettimeofday();
        my $time_stop = $s + $us / 1e6;
        printf "%s.%06d\n", strftime("%H:%M:%S", localtime($s)), $us;
        printf "Total rendering time=%.4f s\n", ($time_stop - $time_start);
    }

    return $success;
}

