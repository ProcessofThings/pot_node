package PotNode::Controller::Private;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::QRCode;
use Mojo::URL;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Data::UUID;
use Data::Dumper;
use Config::IniFiles;

# This action will render a template

  my $ua = Mojo::UserAgent->new;
  my $redis = Mojo::Redis2->new;

sub redirect {
    my $c = shift;
    $c->redirect_to('/main.html');
};

sub load {
    my $c = shift;
    my $sessionUuid;
    my $eventHash;
    my $eventConfig;
    my $pot_config = decode_json($redis->get('config'));
    my $page = $c->req->param('page') || "main";
    my $id;
    my $blockchain = $c->req->param('chain') || "none";
    my $allparams = $c->req->params->to_hash;
    my $template;
		my $static = Mojolicious::Static->new;
		push @{$static->paths}, '/home/node/dev';
    
    foreach my $item (@{$pot_config->{'config'}->{'9090_layout'}}) {
        if($item->{'name'} eq $page) {
            $id = $item->{'ipfs'};
        } else {
            $c->app->log->debug("Error Page name not found");
        }
    }
    
    if ($blockchain eq "none") {
        if ($c->session('blockchain') ne 'none') {
            $blockchain = $c->session('blockchain');
        }
    }
    if ($page ne "main") {
        if ($c->session('blockchain') eq 'none') {
            $c->redirect_to('/main.html');
        }
    }
        
    if ($c->req->param('chain')) {
        $c->session(blockchain => $blockchain);
    }
    ## Setup Session UUID and Event UUID
    ## These are combined to link and hashed to provide a uniquid that is used to link page config to data processing
    
    my $uuid = $c->app->uuid();
    if (!$c->session('uuid')) {
        $c->app->log->debug("Session Set : $uuid");
        $sessionUuid = $uuid;
        $c->session(uuid => $sessionUuid);
    } else {
        $sessionUuid = $c->session('uuid');
        $c->app->log->debug("Session UUID Exists : $sessionUuid");
    }
    
    ## Create Event Hash
    $eventHash = $c->sha256_hex("$sessionUuid-$uuid");
    $c->app->log->debug("Event Hash : $eventHash");

    my $htmldata = "<div id=\"data\" data-eventHash=\"$eventHash\">";
    my $encodedfile = b($htmldata);
    $c->stash(importData => $encodedfile);
    $c->debug($encodedfile);

    ## GET config file
    $c->debug($id);
    my $config = $ua->get('http://127.0.0.1:8080/ipfs/'.$id.'/config.json')->result->body;
    if ($config =~ /\n$/) { chop $config; };
    $config = decode_json($config);
    $c->app->log->debug("Blockchain : $blockchain");
    $eventConfig->{'blockchain'} = $blockchain;
    $eventConfig->{'page'} = $page;
    $eventConfig->{'config'} = $config;
    $eventConfig->{'allparams'} = $allparams;
    $redis->setex($eventHash,1800, encode_json($eventConfig));
    
	my $url = 'http://127.0.0.1:8080/ipfs/'.$id.'/'.$page.'.vue';
	$c->app->log->debug("URL : $url");
	$c->stash(import_url => $url);

	my @components;
	my $list;
	
	if ($redis->exists("config")) {
		my @ipfsHash;
		$c->app->log->debug("Checking for HTML changes 9090");
		my $config = decode_json($redis->get("config"));
		foreach my $item (@{$config->{'config'}->{'9090_layout'}}) {
			$c->debug($item);
			push @ipfsHash, $item->{'ipfs'};
		}
		my @navitems;
		foreach my $ipfsHash (@ipfsHash) {
			my $component;
			my $status = $ua->get("http://127.0.0.1:5001/api/v0/pin/ls?arg=$ipfsHash")->result->json;
			if ($status->{'Keys'}->{$ipfsHash}->{'Type'} ne "recursive") {
					$c->app->log->debug("Pinning App");
					$ua->get("http://127.0.0.1:5001/api/v0/pin/add?arg=$ipfsHash");
			}
			$c->app->log->debug("Getting $ipfsHash/config.json");
			my $config = $ua->get('http://127.0.0.1:8080/ipfs/'.$ipfsHash.'/config.json')->result->body;
			if ($config =~ /\n$/) { chop $config; };
			$config = decode_json($config);
			$component = 'mainPage: httpVueLoader( "/ipfs/'.$ipfsHash.'/main.vue" )';
			push @components, $component;
			if ($config->{'navitems'}) {
					foreach my $item (@{$config->{'navitems'}}) {
						foreach my $option (@{$item->{'navitems'}}) {
							if ($option->{'href'}) {
									$option->{'ipfs'} = $ipfsHash;
									## To override loading vue files from ipfs add the array bellow
									my $devdirectory = $c->config->{dev}.'/'.$ipfsHash;
									$c->app->log->debug($devdirectory);
									if (-d $devdirectory) {
										$c->app->log->debug("Developer Tool - Detected local copy");
										$component = $option->{'href'}.': httpVueLoader( "/dev/'.$ipfsHash.'/'.$option->{'href'}.'.vue" )';
									} else {
										$component = $option->{'href'}.': httpVueLoader( "/ipfs/'.$ipfsHash.'/'.$option->{'href'}.'.vue" )';
									}
									$c->config($component);
									push @components, $component;
							}
						}
						$c->debug($item);
						push @navitems, $item;
					}
					
			}
			my $dataOut->{'navitems'} = \@navitems;
			$c->debug(@components);
#			$redis->set(index => encode_json($dataOut));
		}
	}

	$list = join(',',@components);
	
	$c->debug($list);
	
	$c->stash(import_components => $list);

	$c->debug("Load Config");
	$c->debug($config);
	
	if (!$config->{'template'}) {
		$template = 'system/start';
	} else {
		$template = $config->{'template'};
	}
	
	$c->render(template => $template);
};
sub video {
	my $c = shift;
	$c->render(template => 'system/video');
};
sub assets {
    my $c = shift;
    my $url = $c->req->url->to_string;
    $c->debug($url);
    if ($url =~ /\/developer\/assets/) {
        $url =~ s/\/developer\/assets//g;
    } else {
        $url =~ s/\/developer//g;
    }
    my $id = $redis->get('html_developer');
    my $myaddress = $c->req->url->to_abs->host;
    my $base = "http://127.0.0.1:8080/ipfs/$id/assets".$url;
    $c->app->log->debug("URL : $base myaddress : $myaddress");
#    $c->redirect_to($base);
    $c->render_later;
    $ua->get($base => sub {;
        my ($ua, $tx) = @_;
#        $c->debug($tx);
        my $content = $tx->res->headers->content_type;
        $c->debug($content);
        my $file = $tx->res->body;
        
        $c->render(data => $file, format => $content);
    });
};

sub ipfs {
    my $c = shift;
    my $url = $c->req->url->to_string;
    my $id = $c->param('id');
    my $file = $c->param('file');
    my $base = "http://127.0.0.1:8080/ipfs/$id/$file";
    $c->proxy_to($base);
};

sub api {
    my $c = shift;
    $c->res->headers->header('Access-Control-Allow-Origin' => '*');
    $c->res->headers->header('Access-Control-Allow-Credentials' => 'true');
    $c->res->headers->header('Pragma' => 'no-cache');
    $c->res->headers->header('Cache-Control' => 'no-cache');
    my $data = decode_json($redis->get('index'));
    $c->render(json => $data);
};
  
1;
