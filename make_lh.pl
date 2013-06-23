#!/usr/bin/env perl
# File:    make_lh.pl
# Brief:   Script to add/remove/modify license headers on project files.
# Author:  Anton Kozhemyachenko (gmerzu@gmail.com)
# Version: 1.1
# Created: June 21, 2013

use v5.10; # I like say "say"
use strict;
use warnings;

use Getopt::Long qw(:config no_ignore_case);
use Term::ANSIColor qw(:constants);
use Cwd 'abs_path';
use File::Find;

no warnings 'File::Find';


my $VERSION = "1.1";


$ENV{PATH} = "/bin:/usr/bin";
my $RC_DIR = "$ENV{HOME}/.lh_maker";
my $RC_FILE = "$RC_DIR/rc";
my $TEMPLATE_DIR = "$RC_DIR/templates";


sub print_help()
{
	say "Version: $VERSION";
	say "USE: $0 [options] [dir|file]...";
	say "     options:";
	say "       -h|--help               this help";
	say "       -c|--color              make output in color";
	say "       -i|--interactive        work interactively";
	say "       -I|--noninteractive     work non-interactively (default)";
	say "       -f|--force              force add header when it seems to be present";
	say "       -r|--remove             remove headers from the files";
	say "       -R|--onlyremove         remove headers without adding new ones";
	say "       -m|--replace            replace headers";
	say "       -w|--reset              ask for all fields if needed";
	say "       -t|--template=<file>    use this template for all files";
	say "       -n|--newtemplate=<file> use this template for replaced headers";
	say "       -v|--vars=<file>        use this template for templates vars";
	say "       -e|--ext=<extension>    treat all files as they have this extension";
	say "       -p|--preserveall        preserve everything (implies -pva && -paa)";
	say "       -pv|--preservevar=<var> preserve this variables from templates, can be passed multiple times";
	say "       -pva|--preserveallvar   preserve all template variables";
	say "       -pa|--preservearg=<arg> preserve this args from templates, can be passed multiple times";
	say "       -paa|--preserveallarg   preserve all template arguments";
	say "       -a|--arg=<name=value>   replace the name with the value in templates if present,";
	say "                               parameter can't be passed multiple times";
}

sub min($$)
{
	$_[$_[0] > $_[1]];
}


my %opts = (help => 0,
			color => 0,
			interactive => 0,
			force => 0,
			template => "",
			newtemplate => "",
			vars => "",
			ext => "",
			remove => 0,
			onlyremove => 0,
			replace => 0,
			reset => 0,
			present => 0,
			preserveallvar => 0,
			preserveallarg => 0,
			path => "",
			aggressive_replace_add => 5,
			types => "",
		);


my %templates = ();
my %ext = ();

if (-r $RC_FILE)
{
	open my $FH, $RC_FILE || die "Can't open rc file";
	while (<$FH>)
	{
		chomp;
		/^#/ || /^\s*$/ and next;
		s/^\s*//;
		s/\s*$//;
		my ($n, $v) = split /\s*=\s*/, $_, 2;
		if ($n =~ s/^\$//)
		{
			$opts{$n} = $v;
			next;
		}
		my @vs = split /\s+/, $v;
		for my $e (@vs)
		{
			my @a = ($e);
			if ($e =~ s/^@//)
			{
				@a = ();
				push @a, @{$templates{$e}} if $templates{$e};
				push @a, @{$templates{'@'.$e}} if $templates{'@'.$e};
			}
			push @{$templates{$n}}, @a;
		}
	}
	close $FH;
}

foreach my $k (keys %templates)
{
	foreach my $e (@{$templates{$k}})
	{
		push @{$ext{$e}}, $k;
	}
}

foreach my $e (keys %ext)
{
	@{$ext{$e}} = sort { ($a =~ /^@/) <=> ($b =~ /^@/) } @{$ext{$e}};
}

sub is_in_group
{
	my $g = '@'.shift;
	my $e = shift;
	return 0 unless $templates{$g};
	foreach (@{$templates{$g}})
	{
		return 1 if $e eq $_;
	}
	return 0;
}

sub get_exts
{
	my $g = '@'.shift;
	my @res = ();
	return @res unless $templates{$g};
	foreach (@{$templates{$g}})
	{
		push @res, $_;
	}
	return (@res);
}

sub get_groups
{
	my $e = shift;
	my @res = ();
	return @res unless $ext{$e};
	foreach (@{$ext{$e}})
	{
		my $g = $_;
		push @res, $g if $g =~ s/^@//;
	}
	return (@res);
}


sub get_date
{
	my @months = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my @t = localtime(time);
	my ($month, $mday, $year) = ($months[$t[4]], $t[3], $t[5] + 1900);
	return "$month $mday, $year";
}



my @types = ();

if ($opts{types})
{
	@types = split /\s*,\s*/, $opts{types};
	my @tmp = ();
	foreach my $t (@types)
	{
		push @tmp, @{$templates{$t}} if $templates{$t};
	}
	my %types_count = ();
	@types = grep { $_ if !$types_count{$_}++ } @tmp;
}



my @args_params = ();
my %args = ();
my @preserve_vars = ();
my @preserve_args = ();

GetOptions(\%opts,
		"arg|a=s" => \@args_params,
		"help|h",
		"color|c",
		"interactive|i",
		"noninteractive|I" => sub { $opts{interactive} = 0 },
		"force|f",
		"template|t=s",
		"newtemplate|n=s",
		"vars|v=s",
		"ext|e=s",
		"remove|r",
		"onlyremove|R",
		"replace|m",
		"reset|w",
		"preserveall|p" => sub { $opts{preserveallvar} = 1; $opts{preserveallarg} = 1 },
		"preservevar|pv=s" => \@preserve_vars,
		"preserveallvar|pva",
		"preservearg|pa=s" => \@preserve_args,
		"preserveallarg|paa",
	) or die "Invalid arguments supplied (try -h to see all available options)";



sub DEFAULT { ($opts{color} and RESET) || "" };
sub INFO { ($opts{color} and GREEN) || "" };
sub INFO2 { ($opts{color} and BLUE) || "" };
sub INFO3 { ($opts{color} and BOLD . BLUE) || "" };
sub NOTICE { ($opts{color} and MAGENTA) || "" };
sub WARNING{ ($opts{color} and YELLOW) || "" };
sub ERROR { ($opts{color} and RED) || "" };





$opts{help} and print_help and exit 0;

die ERROR . "!! vars is not set" . DEFAULT unless $opts{vars};

$ENV{PATH} = $opts{path}.":".$ENV{PATH} if $opts{path};


foreach (@args_params)
{
	my ($k, $v) = split /=/, $_, 2;
	$args{$k} = $v if $k && $v;
}


my %vars = ();
my $to_shift_argv = 0;

$opts{vars} =~ s/^~/$ENV{HOME}/;
open my $VARS_FH, $opts{vars} or die ERROR . "!! Can't open $opts{vars}" . DEFAULT;
while (<$VARS_FH>)
{
	chomp;
	next if !$_;
	my ($k, $v) = split /\s*=\s*/, $_, 2;
	my $tmp = "";
	$v =~ s/\$(\d+)/$tmp = ($ARGV[$1-1] || "") and $to_shift_argv++; $tmp/ge;
	$v =~ s/\$\(([^\)]+)\)/qx($1)/ge;
	chomp $v;
	$vars{$k} = $v;
}
close $VARS_FH;

shift while ($to_shift_argv--);

my @files = ();
my @dirs = map { abs_path($_) } @ARGV;

find(sub { push @files, $File::Find::name if -f $File::Find::name },
	@dirs) if @dirs;

my %files_uniq = ();
@files = grep { $_ if !$files_uniq{$_}++ } @files;


my %saved_vars = ();
my %preserved_vars = ();
my %preserved_args = ();


say INFO . ">> Using vars file: $opts{vars}" . DEFAULT;
say INFO . ">> Using template file: $opts{template}" . DEFAULT if $opts{template};
say INFO . ">> Using alternative template file: $opts{newtemplate}" . DEFAULT if $opts{newtemplate};
say "";


$opts{remove} = 1 if $opts{replace};
$opts{remove} = 1 if $opts{onlyremove};
$opts{replace} = 0 if $opts{onlyremove};
#$opts{interactive} = 0 if $opts{replace};


say INFO2 . ">> Work interactively" . DEFAULT if $opts{interactive};
say INFO2 . ">> Force is enabled" . DEFAULT if $opts{force};
say "" if $opts{interactive} || $opts{force};

say INFO2 . ">> REPLACE MODE ENABLED" . DEFAULT if $opts{replace};
say INFO2 . ">> REMOVE MODE ENABLED" . DEFAULT if $opts{remove} || $opts{onlyremove};
say "" if $opts{replace} || $opts{remove} || $opts{onlyremove};



sub filter_files
{
	my $f = shift;
	my $fext = "";
	return $f unless @types;

	$fext = lc "$1" if $f =~ /^.+\.([^.]+)$/;
	return "" unless $fext;

	return $f if grep { $_ eq $f } @dirs;
	return "" unless grep { $_ eq $fext } @types;

	return $f;
}


@files = grep filter_files($_), @files;



if (!@files)
{
	say WARNING . "!! No input files found" . DEFAULT;
}

#map { say "to process: $_" } @files;


foreach my $f (@files)
{
	my $f_short = $f;
	$f_short = $1 if $f =~ /^.+\/(.+)$/;
	my $f_short_origin = $f_short;
	my $fext = "";
	$fext = "$1" if $f =~ /^.+\.([^.]+)$/;
	my $f_noext = $f;
	$f_noext = "$1" if $f =~ /^(.+)\.[^.]+$/;
	my $f_short_noext = $f_short;
	$f_short_noext = "$1" if $f_short =~ /^(.+)\.[^.]+$/;

	$fext = lc $fext;
	$f_short = lc $f_short;
	$f_short_noext = lc $f_short_noext;

	$fext = $opts{ext} if $opts{ext};

	my $f_with_header_firstly = 0;

	my @gs = get_groups($fext);
	my @exts = map { get_exts($_) } @gs;

	my $template = $opts{template};
	if (!$template)
	{
		my $fext_tmp = $opts{ext} || $fext;
		foreach my $t (@{$ext{$fext_tmp}})
		{
			$t =~ s/^@//;
			if (-r $TEMPLATE_DIR."/".$t)
			{
				$template = $TEMPLATE_DIR."/".$t;
				last;
			}
		}
		if (!$template && -r $TEMPLATE_DIR."/default")
		{
			$template = $TEMPLATE_DIR."/default";
		}
	}
	my $template_short = $template;
	$template_short = $1 if $template =~ /^.+\/(.+)$/;



	if ($opts{replace})
	{
		say INFO . ">> Replace header in $f ..." . DEFAULT;
		if (!$template)
		{
			say WARNING . "!! No template for $f, skip" . DEFAULT;
			next;
		}

		open my $TFH, $template or die ERROR . "!! Can't open tempalte $template" . DEFAULT;
		my @template_content = <$TFH>;
		close $TFH;
		@template_content = map { chomp; $_ } grep { !/^\s*$/ } @template_content;

		open my $FH, $f or die ERROR . "!! Can't open $f" . DEFAULT;
		my @content = <$FH>;
		close $FH;
		@content = map { chomp; $_ } grep { !/^\s*$/ } @content;

		@content = @content[0 .. min(@template_content - 1 + $opts{aggressive_replace_add},
									@content - 1)];

		if (is_in_group('shell', $fext) && $content[0] =~ /^#!/)
		{
			@content = @content[1 .. @content - 1];
		}


#		say foreach @template_content;
#		say "==========";
#		say foreach @content;

		foreach my $l (@content)
		{
			foreach my $t (@template_content)
			{
				my $t = $t;
				my @pv = ();
				while ($t =~ s/(?:\@\w+\@)|(?:\@\$ASK\[\w+\]\@)|(?:\@\$ARG\[\w+\]\@)/__MARKER_TO_REPLACE__/)
				{
					my $a = $&;
					if ($a =~ /\@\$ASK\[(\w+)\]\@/)
					{
						push @pv, { t => "ask", v => $1 };
					}
					elsif ($a =~ /\@\$ARG\[(\w+)\]\@/)
					{
						push @pv, { t => "arg", v => $1 };
					}
					elsif ($a =~ /\@(\w+)\@/)
					{
						push @pv, { t => "var", v => $1 };
					}
				}
				next unless @pv;
				#$t =~ s/([()\[\]^\$])/\\$1/g;
				$t = quotemeta $t;
				my $rnum = 0;
				$t =~ s/__MARKER_TO_REPLACE__/'(?<r' . (++$rnum) . '>.+)'/ge;
#				say "===========+: $t";
				my $r = qr{^$t$};
				if ($l =~ /$r/)
				{
					$f_with_header_firstly = 1;

					foreach my $i (0 .. @pv - 1)
					{
						my $rval = '$+{r' . ($i + 1) . '}';
						$rval = eval $rval;
						my $h = $pv[$i];
						my $v = $h->{v};
						my $found = $rval;
						if ($h->{t} eq "ask")
						{
							say INFO3 . "-- Found $v: $found ... saving for all group files" . DEFAULT;
							$saved_vars{$f}{$v} = $found;
							$saved_vars{$f_short}{$v} = $found;
							$saved_vars{$f_short_noext.".".$_}{$v} = $found foreach @exts;
						}
						elsif ($h->{t} eq "var")
						{
							print INFO3 . "-- Found $v: $found ... ";
							if ($opts{preserveallvar} || grep { $_ eq $v } @preserve_vars)
							{
								$preserved_vars{$f}{$v} = $found;
								say "preserving" . DEFAULT;
							}
							else
							{
								say "not preserving" . DEFAULT;
							}
						}
						elsif ($h->{t} eq "arg")
						{
							print INFO3 . "-- Found $v: $found ... ";
							if ($opts{preserveallarg} || grep { $_ eq $v } @preserve_args)
							{
								$preserved_args{$f}{$v} = $found;
								say "preserving" . DEFAULT;
							}
							else
							{
								say "not preserving" . DEFAULT;
							}
						}
					}
				}
			}
		}
	}


	if ($opts{remove})
	{
		say INFO . ">> Remove header from $f ..." . DEFAULT;

		open my $FH, $f or die ERROR . "!! Can't open $f" . DEFAULT;
		my @content = <$FH>;
		close $FH;

		open $FH, ">", $f or die ERROR . "!! Can't open $f for writing" . DEFAULT;
		my $remove_mode = 1;
		my $read_lines = 0;
		my $count_removed = 0;

		foreach my $line (@content)
		{
			print $FH $line and next unless $remove_mode;
			$read_lines++;

			my $to_remove = 0;

			if ($read_lines == 1 && is_in_group('shell', $fext) && $line =~ /^#!/)
			{
				print $FH $line;
				next;
			}
			elsif ($line =~ /^\s*$/)
			{
				$to_remove = 1;
			}
			elsif (is_in_group('cpp', $fext) && $line =~ /^\s*[\/*]/)
			{
				$to_remove = 1;
			}
			elsif (is_in_group('shell', $fext) && $line =~ /^\s*[#]/)
			{
				$to_remove = 1;
			}

			if ($to_remove)
			{
				$count_removed++;
				next;
			}
			else
			{
				print $FH $line;
				$remove_mode = 0;
			}
		}

		close $FH;

		if ($count_removed)
		{
			say NOTICE . "-- Something has been removed ($count_removed lines)" . DEFAULT;
		}
		else
		{
			say NOTICE . "** No any comment has been removed " . DEFAULT;
		}

		next if $opts{onlyremove};
	}


	if (!$template)
	{
		say WARNING . "!! No template for $f, skip" . DEFAULT;
		next;
	}

	if ($opts{replace} && $opts{newtemplate})
	{
		if (-r $opts{newtemplate})
		{
			$template = $opts{newtemplate};
			$template_short = $template;
			$template_short = $1 if $template =~ /^.+\/(.+)$/;
		}
		else
		{
			say WARNING . "!! New template is not readable" . DEFAULT;
		}
	}

	if ($opts{replace})
	{
		say INFO .">> Add header to $f using $template_short template ..." . DEFAULT;
	}
	else
	{
		say INFO . ">> Process $f with $template_short template ..." . DEFAULT;
	}


	my @content = ();
	open my $FH, $f or die ERROR . "!! Can't open $f" . DEFAULT;
	@content = <$FH>;
	close $FH;


	my $f_with_header = 0;
	my $check_header_str = join "", @content[0 .. min(4 + $opts{aggressive_replace_add},
									@content - 1)];
	if ($check_header_str =~ /$f_short_origin/g)
	{
		print NOTICE . "** File $f seems to be with license, ";
		$f_with_header = 1;
		say "skip" . DEFAULT and next unless $opts{interactive} || $opts{force};
		say "process anyway" . DEFAULT;
	}

	if ($opts{interactive} && ($f_with_header || !$f_with_header_firstly || $opts{reset}))
	{
		INTERACTIVE:
		print INFO2 . "-- 1-process, 2-skip, 3-exit : " . DEFAULT;
		my $ans = <STDIN>;
		chomp $ans;
		if ($ans =~ /^1$/)
		{
			# ok, process
		}
		elsif ($ans =~ /^2$/)
		{
			say INFO2 . "-- Skip $f" . DEFAULT;
			next;
		}
		elsif ($ans =~ /^3$/)
		{
			say INFO . "-- Exit" . DEFAULT;
			exit 0;
		}
		else
		{
			say WARNING . "!! Invalid choice" . DEFAULT;
			goto INTERACTIVE;
		}
	}

	open my $TFH, $template or die ERROR . "!! Can't open tempalte $template" . DEFAULT;
	my $template_content = "";
	$template_content .= $_ while (<$TFH>);
	close $TFH;

	my %script_vars = (
			FILE => $f, FILE_SHORT => $f_short_origin,
			DATE => get_date(),
			);

	sub read_ans
	{
		my $f = shift;
		my $f_short = shift;
		my $f_short_noext = shift;
		my $exts_tmp = shift;
		my @exts = @$exts_tmp;
		my $var = shift;

		return $saved_vars{$f}{$var} if $saved_vars{$f}{$var} && $opts{replace} && !$opts{reset};
		return $saved_vars{$f_short}{$var} if $saved_vars{$f_short}{$var} && $opts{replace} && !$opts{reset};
		print INFO2 . "-- Write data for $var: ";
		my $ans_default = "TODO: write $var";
		$ans_default = $saved_vars{$f_short}{$var} if $saved_vars{$f_short}{$var};
		$ans_default = $saved_vars{$f}{$var} if $saved_vars{$f}{$var};
		print "[$ans_default] " . DEFAULT;
		my $ans = <STDIN>;
		chomp $ans;
		if ($ans)
		{
			$saved_vars{$f_short}{$var} = $ans;
			$saved_vars{$f_short_noext.".".$_}{$var} = $ans foreach @exts;
		}
		return $ans || $ans_default;
	}

	$template_content =~ s/\@(\w+)\@/$preserved_vars{$f}{$1} || $vars{$1} || ""/ge;
	$template_content =~ s/\@\$(\w+)\@/$script_vars{$1} || ""/ge;
	$template_content =~ s/\@\$ARG\[(\w+)\]\@/$preserved_args{$f}{$1} || $args{$1} || ""/ge;
	$template_content =~ s/\@\$ASK\[(\w+)\]\@/&read_ans($f, $f_short, $f_short_noext, \@exts, $1 || "")/ge;
#	say $template_content;


	my $content_pre = "";
	if (is_in_group('shell', $fext) && $content[0] =~ /^#!/)
	{
		$content_pre = shift @content;
		shift @content if $content[0] =~ /^\s*$/;
	}
	my $content_str = $content_pre . $template_content . join("", @content);

	open my $OFH, ">", $f or die ERROR . "!! Can't open $f for writing" . DEFAULT;
	print $OFH $content_str;
	close $OFH;
}

say INFO . ">> Exit" . DEFAULT;
exit 0;
