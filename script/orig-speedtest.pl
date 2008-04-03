#!/usr/local/pkg/perl-5.8/current/bin/perl-5.8 -w

use strict;
use warnings;
use URI;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep );
use ICG::CLI;
use YAML::Syck;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep );
use Test::WWW::Selenium tests=>5;
use Test::Simple qw(no_plan);
use Test::Exception;

our $VERSION = 1.0;

my ($opts, $usage) = describe_options(
  "got: usage: got %o [ file1 file2 ... ]",
  [ "server_config|sc=s" => "selenium server configuration file" ],
  [ "test_config|tc=s" => "test configuration file" ],
  [ "pobox_username|pu=s" => "pobox user to authenticate with" ],
  [ "pobox_password|pw=s" => "pobox user password to authenticate with" ],
  [ "webmail_server|ws=s" => "webmail server URL to use" ],
  [ "timer|t" => "turn timing on" ],
);

# Establish server Config Data
my @serverList = (".selenium_servers.yaml", "~/.selenium_servers.yaml", "/etc/selenium_servers.yaml");
@serverList = ($opts->{server_config}) if $opts->{server_config};
my $serverConfig;
my $serverData;

# Establish test data
my @testConfigList = (".selenium_test.yaml", "~/.selenium_test.yaml");
@testConfigList = ($opts->{test_config}) if $opts->{test_config};
my $testConfig;
my %poboxAuthentication;
my $testConfiguration;

## Begin loading test data
foreach(@testConfigList) {
  stat($_);
  next unless -e _;
  $testConfig = $_;
  print "using the test configuration file $testConfig\n\n";
  $testConfiguration = LoadFile($testConfig);
  last;
}
$testConfiguration->{webmail_server} = "webmail.pobox.com" unless $testConfiguration->{webmail_server}; # define default pobox webmail server
$testConfiguration->{webmail_server} = $opts->{webmail_server} if $opts->{webmail_server};
$testConfiguration->{pobox_username} = $opts->{pobox_username} if $opts->{pobox_username};
$testConfiguration->{pobox_password} = $opts->{pobox_password} if $opts->{pobox_password};
$testConfiguration->{timer} = 1 if $opts->{timer};
## End loading test data 

#print "testTest: ",$testConfiguration->{platform}{Windows}{version},"\n\n";

## Begin loading server configs
foreach(@serverList) {
  stat($_);
  next unless -e _;
  $serverConfig = $_;
  print "using the server configuration file $serverConfig\n\n";
  $serverData = LoadFile($serverConfig);
  last;
}
## End loading server configs

## Begin Authenticate and login seperately
foreach (%{$testConfiguration->{'platform'}}) {
  next if (ref $_);
  my $host = $serverData->{$_}{$testConfiguration->{platform}{$_}{version}}{host};
  my $port = $serverData->{$_}{$testConfiguration->{platform}{$_}{version}}{port};
  my $browser = $testConfiguration->{platform}{$_}{browser};
  #if ($serverData->{$_}{$testConfiguration->{platform}{$_}{version}}{browser}($testConfiguration->{platform}{$_}{browser}));
  my $url = $testConfiguration->{authentication_url};
  print "current:  $host, $port, $browser, $url\n";
  my $t0 = [gettimeofday];
  my $authenticate = &initializeTest( $host, $port, $browser, $url );
  $authenticate->wait_for_page_to_load_ok("3000");
  print "initial login page Load Time: ", tv_interval( $t0, [gettimeofday]), "\n\n";
  my $t1 = [gettimeofday];
  if ($authenticate->is_element_present('username')) {
    print "have to log you in\n";
    $authenticate->type_ok("username",$testConfiguration->{pobox_username});
    $authenticate->type_ok("password",$testConfiguration->{pobox_password});
    $authenticate->click_ok("submit");
    $authenticate->wait_for_page_to_load_ok("3000");
  } else {
    print "you're already logged in!\n";
  }

  if ($authenticate->is_element_present('xsnazzy')) {
    print "Process Login Time: ", tv_interval( $t1, [gettimeofday]), "\n\n";
  } else {
    print "login failed. Aborting execution.\n\n";
    exit();
  }

  $url = $testConfiguration->{webmail_server};
  my @timers;
  my $numTests = $testConfiguration->{number_of_tests} || 1;
  for (my $i=0; $i<$numTests; $i++) {
    print "\n\n-------TEST-".$i."-----------\n";
	  my $t3 = [gettimeofday];
	  my $webmail = &initializeTest( $host, $port, $browser, $url );
	  $webmail->wait_for_page_to_load_ok("120000");
    $timers[$i] = tv_interval( $t3, [gettimeofday] );
	  if ($webmail->is_element_present('header') && $webmail->is_element_present('taskbar')) {
	    print "Webmail Load Time: ", $timers[$i], "\n\n";
	    print "PAGETITLE:  ",$webmail->get_title(), "\n";
	  } else {
	    print "Webmail Load Failed? (did not detect IDs): ", $timers[$i], "\n\n";
	    print "PAGETITLE:  ",$webmail->get_title(), "\n";
	  }
  }
  print "\n\n-----------------------\n";
  my $tmpTotal = 0;
  my $high = 0; 
  my $low = 0;
  foreach (@timers)  { 
    $high = $_ if $high < $_;
    $low = $_ if $low > $_ || $low == 0;
    $tmpTotal += $_; 
  }
  print "Avg Time of RC page load ". $tmpTotal/$numTests ." for ".$numTests." tests.\n";
  print "Highest RC page load time ". $high ."\n";
  print "Lowest RC page load time ". $low ."\n";
}
## End Authenticate and login seperately

### Initialize the test subroutine
sub initializeTest {
  my($seleniumHost, $seleniumPort, $seleniumBrowser, $origURL) = @_;
  $origURL = "http://".$origURL unless $origURL =~ /^\w{3,5}:\/\//;
  my $uri = URI->new($origURL);
  $uri->host($origURL) unless $uri->host;
  $uri->scheme("http") unless $uri->scheme;
  $uri->path("/") unless $uri->path;
  my $domain = $uri->scheme . "://" . $uri->host;
  $domain = $domain . ":".$uri->port if $uri->port;
  my $url = $uri->path;

  #my($domain, $url) = split(/\//, $authenticationURL);
  #$domain = 'http://'.$domain if $domain !~ /http(s)*:\/\//;
  #$url = "/" unless $url;
  #print "blah: $domain :: $url\n\n";
  my $iniTest = Test::WWW::Selenium->new(
    host => $seleniumHost,
    port => $seleniumPort,
    browser => $seleniumBrowser,
    browser_url => $domain,
    default_names => 1,
  );
  $iniTest->open_ok($url, $domain.$url);
  return $iniTest;
}

#my $yaml = Dump($serverData);
#print "host: ",$serverData->{'OSX'}{'Leopard'}{'host'},"\n";
#print "webmail: ".$testConfiguration->{webmail_server},"\n";
