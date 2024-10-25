#!/usr/bin/perl -w
#
use strict;
use warnings;
use feature 'state';
use feature 'say';
use Module::Load::Conditional qw(check_install);
use Term::ANSIColor;
use Print::Colored qw(:print);
use Getopt::Long qw(:config pass_through);
use Cwd;
use Data::Dumper;
use AppConfig ':expand';
use AppConfig::State;
use AppConfig::File;
use File::Basename;
use IO::Pty;
use IO::Stty;
use List::MoreUtils qw(uniq);
use File::Path;
use File::Copy;
use File::Slurp;
use File::Basename;
use Carp;
use Module::Load::Conditional;
use lib dirname(
    sub {
        return readlink(__FILE__) if ( -l __FILE__);
        return __FILE__;
    }->()
);

#--- global variables
my $config;
my $scriptname;
my $scriptpath;
my $filename;
my $count;
my @digdata;

#**
# @function cmdline()
# @brief parses and sets the arguments from the command line
# @params
# @retval
#
sub cmdline(@) {
    my $debug;
    $config=AppConfig->new();

    $config->define('log!');
    $config->define('logfile=s');

	Getopt::Long::GetOptions(
			"h|help" => sub { do_help() ; exit 0; },
		    "f|file=s" => \$filename,
	) or die("error in command line arguments");

	die "Missing input file (--file <filename>)" unless length($filename);
}

#**
# @function main
# @brief
# @params command line parameters for script
# @retval
#
sub main(@) {
	my @data;
	my $start;
	my $handle;
	my @lines;

    print_ok("----------------------------------------------------------\n");
    print "       ";
    print colored("IR Decoder Utility",'bright_blue');
    print "                   v0.1\n";
    print_ok("----------------------------------------------------------\n");

    # get cmd line parameters
    cmdline(@_);

	# read from file to array
	unless (open $handle, "<:encoding(utf8)",$filename) {
		print STDERR "Could not open file '$filename': $!\n";
		return undef;
	}
	chomp(@lines=<$handle>);
	unless (close $handle){
		print STDERR "Could not open file '$filename': $!\n";
	}

	# remove table head (first line)
	splice @lines,0,1;

	# build @data array
	$count = 0;
	for ( my $i=0; $i<=$#lines; $i++){
		my @temp;
		print $lines[$i];
		@temp=split /\,/,$lines[$i];

		# convert to numbers
		$temp[0]=$temp[0]+0;
		$temp[1]=$temp[1]+0;

		push @data, \@temp;
		$count++;
	}
	say "Number of original samples: $count $#data";
    print Dumper(@data);
}

#**
# @function userscansudo
# @brief checks if current user is sudoer
# @params
# @retval
#
sub usercansudo() {
    my $grp=`groups`;
    if($grp =~ /sudo/){
        return 1;
    }else{
        return 0;
    }
}

#**
# @function do_help()
# @brief displays the help on -h
# @params
# @retval
#
sub do_help() {
    print "Usage: $scriptname [short options]|[long options]\n";
    print "   Options:\n";
    print "       -h|--help    - show this help\n";
    print "\n";
}

#**
# @function check_file()
# @brief checks if a folder exists in the filesystem
# @params
# @retval  1 if file exists
#          0 if does not exists
#
sub check_file($) {
    my $tfile=shift;

    if (-e $tfile) {
        # exists but is not a directory
        return 1;
    }
    return 0;
}

#**
# @function check_folder()
# @brief checks if a folder exists in the filesystem
# @params
# @retval 1 if folder exists, 2 if given path
#         0 is a file or -1 if does not exists
#
sub check_folder($) {
    my $tdir=shift;

    if (-d $tdir) {
        # directory exists
        return 1;
    }
    elsif (-e $tdir) {
        # exists but is not a directory
        return 2;
    }
    return 0;
}

main();
