package RoundCube::Test;

use strict;
use URI;
require ICG::CLI;
use YAML::Syck;
use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep );
use Test::WWW::Selenium;
use Test::Simple qw(no_plan);
use Test::Exception;

our $VERSION = 0.01;

sub new {
  #my () = @_;
  
  my $class = shift;
  my $passedOpts = shift;
  my $self = { debug => 1 };
  bless $self, $class;

  my @options = (
    "got: usage: got %o [ file1 file2 ... ]",
		[ "server_config|sc=s" => "selenium server configuration file" ],
		[ "test_config|tc=s" => "test configuration file" ],
		[ "pobox_username|pu=s" => "pobox user to authenticate with" ],
		[ "pobox_password|pw=s" => "pobox user password to authenticate with" ],
		[ "webmail_server|ws=s" => "webmail server URL to use" ],
		[ "timer|t" => "turn timing on" ],
  );
  #push @options, [ "zag|z" => "Zahn!" ];
  push @options, @$passedOpts if $passedOpts;

	($self->{opts}, $self->{usage}) = ICG::CLI::describe_options(@options);

  # Establish server Config Data
  my @serverList = (".selenium_servers.yaml", "~/.selenium_servers.yaml", "/etc/selenium_servers.yaml");
  @serverList = ($self->{opts}{server_config}) if $self->{opts}{server_config};

  ## Begin loading server configs
	foreach(@serverList) {
		stat($_);
		next unless -e _;
		$self->{serverConfig} = $_;
		print "Using the server configuration file $self->{serverConfig}\n\n" if $self->{debug} > 0;;
		$self->{serverData} = LoadFile($self->{serverConfig});
		last;
	}
  die "No Server Data Loaded" unless $self->{serverData};
  ## End loading server configs
  
	## Establish test data
	my @testConfigList = (".selenium_test.yaml", "~/.selenium_test.yaml");
	@testConfigList = ($self->{opts}{test_config}) if $self->{opts}{test_config};
	#my $testConfig;
	my %poboxAuthentication;
	my $testConfiguration;
	
	## Begin loading test data
	foreach(@testConfigList) {
		stat($_);
		next unless -e _;
		$self->{testConfig} = $_;
		print "Using the test configuration file $self->{testConfig}\n\n" if $self->{debug} > 0;
		$self->{testConfiguration} = LoadFile($self->{testConfig});
		last;
	}
  die "No Test Configuration Loaded" unless $self->{testConfiguration};

	$self->{testConfiguration}{webmail_server} = "webmail.pobox.com" unless $self->{testConfiguration}{webmail_server}; # define default pobox webmail server
	$self->{testConfiguration}{webmail_server} = $self->{opts}{webmail_server} if $self->{opts}{webmail_server};
	$self->{testConfiguration}{pobox_username} = $self->{opts}{pobox_username} if $self->{opts}{pobox_username};
	$self->{testConfiguration}{pobox_password} = $self->{opts}{pobox_password} if $self->{opts}{pobox_password};
	$self->{testConfiguration}{timer} = 1 if $self->{opts}{timer};
	## End loading test data

  return $self;
}

sub authenticate {
  my $self = shift;
  my $authRef = shift;    # %$authRef = sHost, sPort, sBrowser, tURL, username, password
  my $newSession = shift;


  if ($self->{debug} > 0) { foreach (keys %$authRef) { print "Using ".$_.": ".$authRef->{$_}."\n"; } }
  $authRef->{tURL} .= "/logout" if ($newSession);
  print "First we logout, then we login.\n" if ($newSession && $self->{debug} > 0);

  my $authenticate = &initNewTestDomain( $authRef->{sHost}, $authRef->{sPort}, $authRef->{sBrowser}, $authRef->{tURL} );
  $authenticate->wait_for_page_to_load_ok("3000");
  if ($authenticate->is_element_present('username')) {
    print "have to log you in\n";
    $authenticate->type_ok("username",$authRef->{username});
    $authenticate->type_ok("password",$authRef->{password});
    $authenticate->click_ok("submit");
    $authenticate->wait_for_page_to_load_ok("3000");
  } else {
    print "you're already logged in!\n" if ($self->{debug} > 0); 
  }

  if ($authenticate->is_element_present('xsnazzy')) {  # xsnazzy is the DIV we test for to determine login success
    return 1;
  } else {
    return 0;
  }
}

sub initNewTestDomain {
  my $self = shift;
  my $seleniumHost;
  if (ref($self)) {
    $seleniumHost = shift;
  } else {
    $seleniumHost = $self;
  }
	my($seleniumPort, $seleniumBrowser, $origURL) = @_;

	$origURL = "http://".$origURL unless $origURL =~ /^\w{3,5}:\/\//;
  print $origURL,"\n";
	my $uri = URI->new($origURL);
	$uri->host($origURL) unless $uri->host;
  #print $uri->host,"\n";
	$uri->scheme("http") unless $uri->scheme;
  #print $uri->scheme,"\n";
	$uri->path("/") unless $uri->path;
  #print $uri->path,"\n";
	my $domain = $uri->scheme . "://" . $uri->host;
	$domain = $domain . ":".$uri->port if $uri->port;
  print $domain," -domain\n";
	my $url = $uri->path;
  print $url," -url\n";
	
	#my($domain, $url) = split(/\//, $authenticationURL);
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
