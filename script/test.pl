#!/usr/bin/perl

my $pid = fork;
# now two processes are executing

if ($pid == 0) {
  print "Child thread\n";
  sleep 1;
  exit;
}

print "Wating from parent thread child: $pid\n";
waitpid $pid, 0;
print "EXIT\n";