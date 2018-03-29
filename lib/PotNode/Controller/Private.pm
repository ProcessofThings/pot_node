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
    my $id = $pot_config->{'config'}->{'9090_layout'}->{$page};
    my $blockchain = $c->req->param('chain') || "none";
    my $allparams = $c->req->params->to_hash;
    
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

    while( my( $key, $value ) = each %{$config->{'component'}}){
        my $url = 'http://127.0.0.1:8080/ipfs/'.$id.'/'.$value;
        my $html = $ua->get($url)->res->dom->find('div.template')->first;
        my $encodedfile = b($html);
        my $importref = "import_$key";
        $c->stash($importref => $encodedfile);
    };
    
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

  
1;
