#clean automatically converted pdfs, subdir is hardcoded here
$clean_ext = 'graphics/*-eps-converted-to.pdf';
#clean files generated by custom dependencies
$cleanup_includes_cusdep_generated = 1;
#clean files generated by latex
$cleanup_includes_generated = 1;
#use evince as viewer
$pdf_previewer = "evince";
#use recorder feature to list input files
$recorder = 1;

use File::Basename;

$pdflatex = 'pdflatex --shell-escape -interaction=batchmode -synctex=1 %O %S';
$latex = 'latex --shell-escape -interaction=batchmode -synctex=1 %O %S';

#add synctex extensions so they are cleaned
push @generated_exts, 'synctex', 'synctex.gz';

# detects an outdated pdf-image, and triggers a pdflatex-run
add_cus_dep( 'eps', 'pdf', 0, 'cus_dep_require_primary_run' );

#custom file dependencies
add_cus_dep('glo', 'gls', 0, 'run_makeglossaries');
add_cus_dep('acn', 'acr', 0, 'run_makeglossaries');

sub run_makeglossaries {
  if ( $silent ) {
    system "makeglossaries -q '$_[0]'";
  }
  else {
    system "makeglossaries '$_[0]'";
  };
}

#add generated extensions so they are cleaned correctly
push @generated_exts, 'glo', 'gls', 'glg';
push @generated_exts, 'acn', 'acr', 'alg';
$clean_ext .= ' %R.ist %R.xdy';

add_cus_dep('ai', 'eps', 0, 'ai2eps');
sub ai2eps {
	return system("pdftops -paper match \"$_[0].ai\" - | ps2eps -q --ignoreBB -l > \"$_[0].eps\" ");
}

add_cus_dep('asy', 'eps', 0, 'asy2eps');
sub asy2eps {
	return system("asy -f eps -o \"$_[0].eps\" \"$_[0].asy\"");
}

add_cus_dep('asy', 'pdf', 0, 'asy2pdf');
sub asy2pdf {
	return system("asy -f pdf -o \"$_[0].pdf\" \"$_[0].asy\"");
}

add_cus_dep('dia', 'eps', 0, 'dia2eps');
sub dia2eps {
	return system("dia -t eps -e \"$_[0].eps\" \"$_[0].dia\"");
}

add_cus_dep('fig', 'eps', 0, 'fig2eps');
sub fig2eps {
	return system("fig2dev -L eps \"$_[0].fig\" \"$_[0].eps\"");
}

add_cus_dep('gif', 'eps', 0, 'gif2eps');
sub gif2eps {
	return system("convert \"$_[0].gif\" \"$_[0].eps\"");
}

add_cus_dep('jpg', 'eps', 0, 'jpg2eps');
sub jpg2eps {
	return system("convert \"$_[0].jpg\" \"$_[0].eps\"");
}

add_cus_dep('png', 'eps', 0, 'png2eps');
sub png2eps {
	return system("convert \"$_[0].png\" \"$_[0].eps\"");
}

add_cus_dep('svg', 'eps', 0, 'svg2eps');
sub svg2eps {
	return system("inkscape --export-area-drawing --export-text-to-path --export-eps=\"$_[0].eps\" \"$_[0].svg\"");
}

add_cus_dep('svg', 'pdf_tex', 0, 'svg2pdf_tex');
sub svg2pdf_tex {
        return system("inkscape --export-area-drawing --export-latex --export-pdf=\"$_[0].pdf\" \"$_[0].svg\"");
}

add_cus_dep('svg', 'eps_tex', 0, 'svg2eps_tex');
sub svg2eps_tex {
        return system("inkscape --export-area-drawing --export-latex --export-eps=\"$_[0].eps\" \"$_[0].svg\"");
}

add_cus_dep('gp', 'eps', 0, 'gp2eps');
sub gp2eps {
	#scan for these extensions as dependencies for gnuplot
	my @extensions = ("dat", "csv");
	$extensionRegExp =  "(?:" . (join "|", map quotemeta, @extensions) . ")";
	open FILE, "$_[0].gp";
	while ($line=<FILE>){
		if (my @matches = $line=~/"([[:alnum:]]+\.$extensionRegExp)"/g){
			#add matches to dependency list			
			foreach (@matches) {
 				 rdb_ensure_file( $rule, $_ );
			}
		}
	}
	return system("gnuplot -e \"cd '" . dirname("$_[0].gp") . "'\" -e \"set output \\\"gnuplot.eps\\\"\" -e \"set terminal postscript enhanced color eps\" " . basename("$_[0].gp"));
}

add_cus_dep('cir', 'eps', 0, 'cir2eps');

sub cir2eps {
	open(my $fh, '>', "$_[0].tex"); 
	print $fh "\\\\\\documentclass{article}\n\\usepackage{pstricks,pst-eps,boxdims,graphicx,pst-grad,amsmath$(CM_ADDON_PACKAGES)}\n\\pagestyle{empty}\n\\\thispagestyle{empty}\n$(CM_ADDON_COMMANDS)\n\\\\begin{document}\n\\\newbox\\graph\n\\\begin{TeXtoEPS}\n";
	system ("m4 -I $(CIRCUIT_MACROS_PATH) pstricks.m4 libcct.m4 \"$_[0].cir\" | $(DPIC_PATH)dpic -p > \"$_[0].tex\"");
	print $fh "\n\\\\\\box\n\\\\\\graph\n\\\\\\end{TeXtoEPS}\n\\\\\\end{document}\n";
	close $fh; 
	system("TEXINPUTS=\"$(CIRCUIT_MACROS_PATH):$$TEXINPUTS:\" latex \"$_[0].tex\" && rm -f \"$_[0].aux\" \"$_[0].log\" \"$_[0].tex\"");
	system("dvips -Ppdf -G0 -E $_[0].dvi -o $_[0].eps && rm -f $_[0].dvi"); 
}

# To allow more general pattern in $clean_ext instead of just an
# extension or something containing %R.
# This is done by overriding latexmk's cleanup1 subroutine.
# Here is an example of a useful application:
#$clean_ext = "*-eps-converted-to.pdf";
sub cleanup1 {
    # Usage: cleanup1( directory, pattern_or_ext_without_period, ... )
    #
    # The directory is a fixed name, so I must escape any glob metacharacters
    #   in it:
    print "========= MODIFIED cleanup1 cw latexmk v. 4.39 and earlier\n";
    my $dir = ( shift );

    # Change extensions to glob patterns
    foreach (@_) { 
        # If specified pattern is pure extension, without period,
        #   wildcard character (?, *) or %R,
        # then prepend it with directory/root_filename and period to
        #   make a full file specification
        # Else leave the pattern as is, to be used by glob.
        # New feature: pattern is unchanged if it contains ., *, ?
        (my $name = (/%R/ || /[\*\.\?]/) ? $_ : "%R.$_") =~ s/%R/$dir$root_filename/;
        unlink_or_move( glob( "$name" ) );
    }
} #END cleanup1



