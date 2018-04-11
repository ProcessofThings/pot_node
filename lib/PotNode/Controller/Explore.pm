package PotNode::Controller::Explore;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::QRCode;
use Mojo::URL;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Data::UUID;
use Config::IniFiles;
use PotNode::Multichain;

# This action will render a template

## UserAgent Called Module wide for nonblocking
my $ua = Mojo::UserAgent->new;
my $redis = Mojo::Redis2->new;

sub redirect {
    my $c = shift;
    $c->redirect_to('/explore/index.html');
};

sub load {
    my $c = shift;
    my $sessionUuid;
    my $eventHash;
    my $eventConfig;
    my $pot_config = decode_json($redis->get('config'));
    $c->debug($pot_config);
    my $page = $c->req->param('page') || "index";
    my $blockchain = $c->req->param('chain') || "none";
    my $allparams = $c->req->params->to_hash;
    my $id;
    
    foreach my $item (@{$pot_config->{'config'}->{'9090_layout'}}) {
        if($item->{'name'} eq 'explore') {
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
    if ($page ne "index") {
        if ($c->session('blockchain') eq 'none') {
            $c->redirect_to('/explore/index.html');
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
    my $configurl = "http://127.0.0.1:8080/ipfs/$id/config.json";
    $c->debug($configurl);
    my $config = $ua->get($configurl)->result->body;
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

#    while( my( $key, $value ) = each %{$config->{'component'}}){
#        my $url = 'http://127.0.0.1:8080/ipfs/'.$id.'/'.$value;
#        my $html = $ua->get($url)->res->dom->find('div.template')->first;
#        my $encodedfile = b($html);
#        my $importref = "import_$key";
#        $c->stash($importref => $encodedfile);
#    };
    
    $c->render(template => $config->{'template'});
};

sub set {
    my $c = shift;
    my $id = $c->param('id');
    $redis->setex('html_explore',1800, $id);
    $c->redirect_to('/explore/index.html');
};

sub blockchain {
    my $c = shift;
    my $dataIn;
    my $dataOut;
    my $config;
    my $url;
    my $api;
    my $custLayout;
    my $eventHash;
    my $eventConfig;
    my $blockchain;
    my $page;
        
##    $eventHash = $c->param('eventHash');
##    $c->app->log->debug("Event Hash : $eventHash");
##    $eventConfig = decode_json($redis->get($eventHash));
##    $blockchain = $eventConfig->{'blockchain'};
    $page = $eventConfig->{'page'};
    my @blockchain = $c->get_blockchains;
    foreach my $blockchain (@blockchain) {
        if (!$redis->exists($blockchain.'_config')) {
                $c->load_blockchain_config;
        }
        push @{$dataIn}, decode_json($redis->get($blockchain.'_config'));
    }
    $c->debug($dataIn);
#    foreach my $item (@{$eventConfig->{'config'}->{$page}}) {
        my $custData;
#        my $layout = $item->{'layout'};
#        my $dom = $item->{'dom'};
#        my $rawOut->{$dom} = $dataIn;
#        push @{$dataOut->{'raw'}}, $rawOut;
			my @array;
        foreach my $arrayitem (@{$dataIn}) {
                $c->debug($arrayitem);
#                my $mergeData = $c->app->mergeHTML($arrayitem,$layout);
 #               $c->debug($custData);
#                $c->app->log->debug("DataIn ARRAY");
				my $mergeData;
				$mergeData->{'value'} = $arrayitem->{'id'};
				$mergeData->{'text'} = $arrayitem->{'name'};
				push @{$custData->{'blockchains'}}, $mergeData;
        }
#        push @{$dataOut->{'html'}}, $custData;
#    }
    $c->debug($custData);
    $c->render(json => $custData, status => 200);
};

sub api {
    my $c = shift;
    my $dataIn;
    my $dataOut;
    my $config;
    my $url;
    my $api;
    my $custLayout;
    my $eventHash;
    my $eventConfig;
    my $blockchain;
    my $page;
    my @config;
    
    $eventHash = $c->param('eventHash');
    $c->app->log->debug("Event Hash : $eventHash");
    $eventConfig = decode_json($redis->get($eventHash));
    
    $blockchain = $eventConfig->{'blockchain'};
    $config = "rpc_$blockchain";
    if (!$redis->exists($config)) {
        $config = $c->get_rpc_config($blockchain);
    } else {
        $config = decode_json($redis->get($config));
    }
    $url = "$config->{'rpcuser'}:$config->{'rpcpassword'}\@127.0.0.1:$config->{'rpcport'}";
    $api =  PotNode::Multichain->new( url => $url );
    $page = $eventConfig->{'page'};
    $c->debug($eventConfig);
    ## Allow custom api requests
    $c->app->log->debug("Loading Custom Config");
    if ($c->param('custom')) {
        @config = decode_json($c->param('custom'));
        $c->debug(@config);
    } else {
        @config = @{$eventConfig->{'config'}->{$page}};
        $c->debug(@config);
    }
     
    my $count = @config;
    $c->app->log->debug("Processing Config $count");
    foreach my $item (@config) {
        $c->app->log->debug("Processing Custom Layout");
        my $method = $item->{'method'};
        my @params = $item->{'params'};
        my $layout = $item->{'layout'};
        my $dom = $item->{'dom'};
        my $custData;
        $c->app->log->debug("Method : $method");
        $c->app->log->debug("Layout : $layout");
        $dataIn = $api->$method( @params );
        $dataIn = $dataIn->{'result'};
        $c->app->log->debug("Results DataIn");
        $c->debug($dataIn);
        my $rawOut->{$dom} = $dataIn;
        push @{$dataOut->{'raw'}}, $rawOut;
        ## IF array process this data
        if ($layout ne "raw") {
            $c->app->log->debug("Array") if (ref($dataIn) eq "ARRAY");
            $c->app->log->debug("Scalar") if (ref($dataIn) eq "SCALAR");
            $c->app->log->debug("Hash") if (ref($dataIn) eq "HASH");
            if (ref($dataIn) eq "ARRAY") {
                foreach my $arrayitem (@{$dataIn}) {
                    $custData->{$dom} = $c->app->mergeHTML($arrayitem,$layout);
                    $c->app->log->debug("DataIn ARRAY");
                }
            } elsif (ref($dataIn) eq "HASH") {
                $custData->{$dom} = $c->app->mergeHTML($dataIn,$layout);
                $c->app->log->debug("DataIn HASH");
            }
            push @{$dataOut->{'html'}}, $custData;
            $c->app->log->debug("DataArray $method");
        }
    }
    
    $c->debug($dataOut);
    $c->render(json => $dataOut, status => 200);
};

1;
