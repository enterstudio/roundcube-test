#!/usr/local/pkg/perl-5.8/current/bin/perl-5.8 -w

BEGIN {
  push @INC, '/home/hunter/src/RoundCubeTest/lib';
}

use RoundCube::Test;
my @cmdLnOpts = (
  ["newsession|N" => "Do not re-use an already existing login session"],
);

my $test = RoundCube::Test->new(\@cmdLnOpts);

foreach (%{ $test->{testConfiguration}{'platform'} }) {
	next if (ref $_);
  my %authH;
	$authH{sHost} = $test->{serverData}{$_}{$test->{testConfiguration}{platform}{$_}{version}}{host};
	$authH{sPort} = $test->{serverData}{$_}{$test->{testConfiguration}{platform}{$_}{version}}{port};
	$authH{sBrowser} = $test->{testConfiguration}{platform}{$_}{browser};
	$authH{tURL} = $test->{testConfiguration}{authentication_url};
  $authH{username} = $test->{testConfiguration}{pobox_username};
  $authH{password} = $test->{testConfiguration}{pobox_password};

  my $status = $test->authenticate( \%authH, $test->{opts}{newsession} );
  print "Login Success.\n" if ($status);
  #print $test->{serverData}{$_}{ $test->{testConfiguration}{platform}{$_}{version} }{host}, "\n";

  print $test->{testConfiguration}{webmail_server},"\n";
  my $webMail = $test->initNewTestDomain($authH{sHost}, $authH{sPort}, $authH{sBrowser}, $test->{testConfiguration}{webmail_server});
  if ($webMail->is_element_present('mailboxlist-container')) {  # mailboxlist-container is the DIV we test for to determine login success
    print ('woot!\n');
  }
}

