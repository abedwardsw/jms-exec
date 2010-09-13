#!/usr/bin/perl
# forker.pl: Forks new processes based on data retrieved via JMS
#
# Copyright (C) 2010 Adam Edwards
#
# Authors: Adam Edwards <abedwardsw@gmail.com>
#
use strict;
use warnings;
use POSIX;
use Cwd 'abs_path';
use Getopt::Long;

# Main vars
my $numArgs = $#ARGV + 1;
my $arg_command;
my $messageId;
my $try;
my ($start,$stop,$status);
my $logdir="/tmp";
my $prog_path=abs_path($0);

# Global vars
our ($logfile);
our ($forked);

###
# MAIN
###
&ParseCommandArgs();

#
# Check if we we're called from the server to run the actual command
#
if ($forked) {

  # Check Command Line Arguments are correct
  unless ($forked && $arg_command && $messageId) { &printUsage(); }

  # Spawn actual command and wait
  spawn_process("$arg_command 1>>$logfile 2>&1");

  # Send Completion Message

  # always exit 0, no one is listening.., process has run in the background
  exit(0);
} 

#
# Otherwise, we are the server
#
print "forker Server is starting";
# while (getJob()) {
while (1) {
  $messageId=12345;
  $try=1;
  $logfile=$logdir . "/" . $messageId . ".log";
  unless(spawn_process("$prog_path -f -m \"$messageId\" -c \"/home/adam/scripts/sleeper.sh 60\" -l $logfile &")) {
    warn "Failed to spawn subprocess...somethings up";
  }
  sleep(1);
}

print "Exiting server application\n";
exit(0);

#######
#
# SUBROUTINES
#
######
sub spawn_process { 

   my $command=shift; 
   my $childwaitrc = -88;
   my $childrc     = -88;

   # Attempt to fork subprocess
   my $pid = fork();

   if (not defined $pid) {
       warn "failed to fork subprocess, resources may not be available. $?\n";
       return undef;
   #
   # Here we are in the forked process
   #
   } elsif ($pid == 0) {
       unless(exec("$command")) {
        exit(-1);
       }
       exit(0);
   #
   # Here we are the parent process  
   #
   } else {
      print "[$pid] Forked process id for execution of $command\n";
      $childwaitrc = waitpid($pid,0);
      $childrc = $?;

      if (! WIFEXITED($?)) {
         warn "[$pid] Child process WIFEXITED unsuccessful: $?";
         return undef;
      } 
      elsif ($childwaitrc <= 0) 
      {
         warn "[$pid] Child pid incorrect: $?";
         return undef;
      }
      else
      {
         my $msg = "[$pid] finished executing process successfuly with rc: " . WEXITSTATUS($childrc) . "\n";
         print $msg;
         #if($forked && open(MLOG, ">>$logfile")) {
         #   print MLOG $msg;
         #   close MLOG;
         #}
      }
   }
   return 1;
}

sub printUsage() {

print <<EOF;

Usage: 

$0 (-s|-f)
   As Server (-s)
   ---------

   As Forked Process (-f)
   -----------------
   -c "Command to run"
   -m "Message Id/Unique ID"
   -l "Logfile" 

EOF

 exit(2);
}

sub ParseCommandArgs() {
###
# command line processing
###
GetOptions ('f'   => \$forked
           ,'c=s' => \$arg_command
           ,'m=s' => \$messageId
           ,'l=s' => \$logfile
           ,'start'  => \$start
           ,'stop'   => \$stop
           ,'status' => \$status
           );
}
