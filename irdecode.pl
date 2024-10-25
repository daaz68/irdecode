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
        ) or die("error in command line arguments");

}


#**
# @function main
# @brief
# @params command line parameters for script
# @retval
#
sub main(@) {
    print_ok("----------------------------------------------------------\n");
    print "       ";
    # print color('bright_blue') . "BOLD Linux" . color('reset');
    print colored("BOLD Target",'bright_blue');
    print " Flash & Run Utility v0.1\n";
    print_ok("----------------------------------------------------------\n");

    # get cmd line parameters
    cmdline(@_);

    my ($hex)=unpack('h*',"asdfasdfasdfasdf");
    say Dumper($hex) . "\n";
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

#**
# @function check_command()
# @brief
# @params command name to run
# @retval returns the full path of the command given
#
sub check_command($) {
    my $command=shift;
    my $res;

    if(!defined $command){
        log_error("cannot find '$command'");
        die "empty command received for execution";
    }

    $res=qx{which $command};

    $res =~ s/\n//;
    if(!defined($res) || length($res) == 0){
        log_error("cannot find '$command'");
        die "cannot find '$command', exit";
    }
    log_ok("using '$res' for '$command'");
    return $res;
}

#**
# @function print_debug()
# @brief prints message in debug color
# @params string to be printed
# @retval
#
sub print_debug($){
    my $msg=shift;

    print Term::ANSIColor::color('ansi28') . $msg . Term::ANSIColor::color('reset');
}

#==============================================================
# logging functions
#==============================================================

#**
# @function log_generic()
# @brief displays a generic message using the give tag and
#        display function
# @params function used to display message
#         tag to print before message
#         the message
# @retval
#
sub log_generic($$$) {
    my $func=shift;
    my $tag=shift;
    my $msg=shift;

    $func->($tag . ": ");
    print $msg . "\n";
}

#**
# @function log_info()
# @brief displays a info message
# @params
# @retval
#
sub log_info($) {
    my $msg=shift;
    log_generic(\&Print::Colored::print_info," info",$msg);
}

#**
# @function log_error()
# @brief displays an error message
# @params
# @retval
#
sub log_error($) {
    my $msg=shift;
    log_generic(\&Print::Colored::print_error,"error",$msg);
}

#**
# @function
# @brief
# @params
# @retval
#
sub log_warn($) {
    my $msg=shift;
    log_generic(\&Print::Colored::print_warn," warn",$msg);
}

#**
# @function log_ok()
# @brief displays an ok message
# @params
# @retval
#
sub log_ok($) {
    my $msg=shift;
    log_generic(\&Print::Colored::print_ok,"   ok",$msg);
}

#**
# @function log_ok()
# @brief displays an ok message
# @params
# @retval
#
sub log_debug($) {
    my $msg=shift;
    log_generic(\&print_debug,"  dbg",$msg);
}

#**
# @function string_fill
# @brief prints at begining and end of a string of length
#        and fills with space or given char
# @params final length
#         string to align left
#         string to align right
#         fill char, default ' '
# @retval stat  Return value from the functions
#
sub string_fill($$$$){
    my $len=shift;
    my $left=shift;
    my $right=shift;
    my $char=shift;

    #    my $missing = $len - length($left) - length($right);
    my $missing = $len - length($left);
    $char=' ' unless defined($char);

    for(my $i=0;$i<$missing;$i++){
        $left .= $char;
    }
    $left .= $right;
    return $left;
}

#**
# @function die_signal_handler
# @brief __DIE__ signal handler for the script
# @params signo Incoming signal number
# @retval stat  Return value from the functions
#
sub die_signal_handler {
    my $msg=shift;
    my $line;

    $msg =~ /line.*?([0-9]+)\.$/;
    $line=$1;

    $msg =~ s/ at .*?$//;
    $msg =~ s/\n//;
    log_error("$msg (line $line)\n");

    exit( $! || ( $? >> 8 ) || 255 );   # Emulate die().
}

#**
# @function signal_handler
# @brief General signal handler for the script
# @params signo Incoming signal number
# @retval stat  Return value from the functions
#
sub signal_handler {
    die "caught signal: $!";
}

#**
# @function program_entry_point
# @brief
# @params
# @retval
#=== entry point
main(@_);

########################################################################
BEGIN {
    $SIG{__DIE__}=\&die_signal_handler;
    $SIG{INT}  = \&signal_handler;
    $SIG{TERM} = \&signal_handler;
    $SIG{QUIT} = \&signal_handler;

    my $name=$0;
    $name = readlink($name) if( -l $name );

    $scriptname=File::Basename::basename($name);
    $scriptpath=Cwd::abs_path(File::Basename::dirname($name));
}

END {
}
