package PotNode::Controller::Api;
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
##    $page = $eventConfig->{'page'};
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
    $c->render(openapi => $custData);
};


sub multichain {
	 my $c = shift->openapi->valid_input or return;
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
    
    my $spec = $c->openapi->spec;
    $c->debug($spec);
    
    my $input = $c->validation->output;
    $c->debug($input);
    my @params = [];
    $blockchain = $input->{'blockchainId'};
    $config = "rpc_$blockchain";
    if (!$redis->exists($config)) {
        $config = $c->get_rpc_config($blockchain);
    } else {
        $config = decode_json($redis->get($config));
    }
    $url = "$config->{'rpcuser'}:$config->{'rpcpassword'}\@127.0.0.1:$config->{'rpcport'}";
    $api =  PotNode::Multichain->new( url => $url );
    
    my $method = $spec->{'x-mojo-name'};
    
    $dataOut = $api->$method( @params );
    
    $c->debug($dataOut);
    $c->render(openapi => $dataOut);
};
1;
