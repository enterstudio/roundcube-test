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
}

sub initNewTestDomain {
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
