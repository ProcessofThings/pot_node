package PotNode::Controller::Developer;
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
    $c->redirect_to('/developer/index.html');
};

sub load {
    my $c = shift;
    my $sessionUuid;
    my $eventHash;
    my $eventConfig;
    my $pot_config = decode_json($redis->get('config'));
    my $import_nav;
    my $id;
    my $appid;
    my $page = $c->req->param('page') || "index";
    my $id = $pot_config->{'config'}->{'9090_layout'}->{'developer'};
    my $blockchain = $c->req->param('chain') || "none";
    my $allparams = $c->req->params->to_hash;
    
    if ($redis->exists('html_developer')) {
        $c->redirect_to('/developer/app/index.html');
    }
    
    if ($blockchain eq "none") {
        if ($c->session('blockchain') ne 'none') {
            $blockchain = $c->session('blockchain');
        }
    }
    if ($page ne "index") {
        if ($c->session('blockchain') eq 'none') {
            $c->redirect_to('/developer/index.html');
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

    ## GET config file
    my $config = $ua->get('http://127.0.0.1:8080/ipfs/'.$id.'/config.json')->result->body;
    if ($config =~ /\n$/) { chop $config; };
    $config = decode_json($config);
    $c->debug($config);
    $c->app->log->debug("Blockchain : $blockchain");
    $eventConfig->{'blockchain'} = $blockchain;
    $eventConfig->{'page'} = $page;
    $eventConfig->{'config'} = $config;
    $eventConfig->{'allparams'} = $allparams;
    $redis->setex($eventHash,1800, encode_json($eventConfig));
    
	my $url = 'http://127.0.0.1:8080/ipfs/'.$id.'/'.$page.'.html';
	$c->app->log->debug("URL : $url");
#	$c->url_for('page', page => 'index.html')->to_abs;
#	my $html = $ua->get('http://127.0.0.1:8080/ipfs/QmfQMb2jjboKYkk5f1DhmGXyxcwNtnFJzvj92WxLJjJjcS')->res->dom->find('section')->first;
    my $html = $ua->get($url)->res->dom->find('div.template')->first;
    my $encodedfile = b($html);
    $c->stash(import_template => $encodedfile);

    if ($config->{'component'}) {
        while( my( $key, $value ) = each %{$config->{'component'}}){
            my $url = 'http://127.0.0.1:8080/ipfs/'.$id.'/'.$value;
            my $html = $ua->get($url)->res->dom->find('div.template')->first;
            my $encodedfile = b($html);
            my $importref = "import_$key";
            $c->stash($importref => $encodedfile);
        };
    }
    
    $c->render(template => $config->{'template'});
};

sub loadApp {
    my $c = shift;
    my $sessionUuid;
    my $eventHash;
    my $eventConfig;
    my $pot_config = decode_json($redis->get('config'));
    my $import_nav;
    my $id;
    my $appid;
    my $page = $c->req->param('page') || "index";
    my $id = $redis->get('html_developer');
    my $blockchain = $c->req->param('chain') || "none";
    my $allparams = $c->req->params->to_hash;
    
    if ($blockchain eq "none") {
        if ($c->session('blockchain') ne 'none') {
            $blockchain = $c->session('blockchain');
        }
    }
    if ($page ne "index") {
        if ($c->session('blockchain') eq 'none') {
            $c->redirect_to('/developer/index.html');
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

    ## GET config file
    my $config = $ua->get('http://127.0.0.1:8080/ipfs/'.$id.'/config.json')->result->body;
    if ($config =~ /\n$/) { chop $config; };
    $config = decode_json($config);
    $c->debug($config);
    $c->app->log->debug("Blockchain : $blockchain");
    $eventConfig->{'blockchain'} = $blockchain;
    $eventConfig->{'page'} = $page;
    $eventConfig->{'config'} = $config;
    $eventConfig->{'allparams'} = $allparams;
    $redis->setex($eventHash,1800, encode_json($eventConfig));
    
	my $url = 'http://127.0.0.1:8080/ipfs/'.$id.'/'.$page.'.html';
	$c->app->log->debug("URL : $url");
#	$c->url_for('page', page => 'index.html')->to_abs;
#	my $html = $ua->get('http://127.0.0.1:8080/ipfs/QmfQMb2jjboKYkk5f1DhmGXyxcwNtnFJzvj92WxLJjJjcS')->res->dom->find('section')->first;
    my $html = $ua->get($url)->res->dom->find('div.template')->first;
    my $encodedfile = b($html);
    $c->stash(import_template => $encodedfile);

    if ($config->{'component'}) {
        while( my( $key, $value ) = each %{$config->{'component'}}){
            my $url = 'http://127.0.0.1:8080/ipfs/'.$id.'/'.$value;
            my $html = $ua->get($url)->res->dom->find('div.template')->first;
            my $encodedfile = b($html);
            my $importref = "import_$key";
            $c->stash($importref => $encodedfile);
        };
    }
    
    $c->render(template => $config->{'template'});
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

sub set {
    my $c = shift;
    my $id = $c->param('id');
    $c->app->log->debug("Set APP Hash : $id");
    $redis->setex('html_developer',1800, $id);
    $c->redirect_to('/developer/app/index.html');
};


sub createApp{
	my $c = shift;
	my $sessionUuid;
	my $eventHash;
	my $eventConfig;
	my $pot_config = decode_json($redis->get('config'));
	my $jsonParams = $c->req->json;
	my $ug = Data::UUID->new;
	my $api;
	my $url;

	my ($uuid, $hex) = $c->app->uuid();

	$jsonParams->{'containerid'} = $uuid;
	
	$c->debug($uuid);
	
	$c->debug($jsonParams);
	
	my @optionlist;
	push (@optionlist,"-chain-description=$jsonParams->{'appName'}") if $jsonParams->{'appName'};
	push (@optionlist,"-anyone-can-connect=true") if $jsonParams->{'appConnect'};
	push (@optionlist,"-anyone-can-send=true") if $jsonParams->{'appSending'};
	push (@optionlist,"-anyone-can-receive=true") if $jsonParams->{'appReceive'};
	my $options = join(' ', @optionlist);
	$c->debug("Options : $options");
	## TODO : Get path using which
	my $command = "/usr/local/bin/multichain-util create $hex $options";
	my $create = qx/$command/;
	$c->debug("Create : $create");
	$c->blockchain_change_state($hex);
	$c->publish_status;
	$c->render(text => "OK", status => 200);
    
};

sub deleteApp{
	my $c = shift;
	my $jsonParams = $c->req->json;
	if ($redis->exists("$jsonParams->{'blockChainId'}_config")) {
		my $config = decode_json($redis->get("$jsonParams->{'blockChainId'}_config"));
		my $run = "/home/node/run/$jsonParams->{'blockChainId'}";
		my $path = "$config->{'path'}";
		if (-f "$run.stop") {
			if (-f "$run.pid") {
				$c->app->debug("Waiting for blockchain to stop");
			} else {
				my $command = "/bin/mv $path /home/node/archieve/";
				$c->app->debug("Command : $command");
				qx/$command/;
				$command = "/bin/rm $run.stop";
				qx/$command/;
			}
		}
	}
	
	$c->render(text => "OK", status => 200);
	$c->publish_status;
};

sub changeAppState {
	my $c = shift;
	my $pot_config = decode_json($redis->get('config'));
	my $jsonParams = $c->req->json;
	my $run = "/home/node/run/$jsonParams->{'blockChainId'}";
	$c->app->debug($run);
	if (-f "$run.stop") {
		if (-f "$run.pid") {
			$c->app->debug("Waiting for blockchain to stop");
		} else {
			$c->app->debug("Stopped");
			unlink "$run.stop"
		}
	} else {
		if (-f "$run.pid") {
			$c->app->debug("Blockchain Running");
			my $command = "/bin/cp $run.pid $run.stop";
			qx/$command/;
		}
	}
	$c->blockchain_change_state($jsonParams->{'blockChainId'});
	$c->publish_status;
	$c->render(text => "OK", status => 200);
};

sub inviteMobile {
	my $c = shift;
	my $jsonParams = $c->req->json;
	my $data = $c->genqrcode64("test");
	$c->render(json => $data, status => 200)
	
};

sub genQrcode64 {
	my $c = shift;
	my $jsonParams = $c->req->json;
	my $data = $c->genqrcode64($jsonParams->{'text'});
	$c->render(json => $data, status => 200)
};

sub static {
	my $c = shift;
	my $file = $c->param('file');
	$file = $c->config->{dev}.'/'.$file;
	$c->res->content->asset(Mojo::Asset::File->new(path => $file));
  $c->rendered(200);
};
1;
