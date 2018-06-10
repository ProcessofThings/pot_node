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
my $clients = {};


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
	 my $dir = $c->config->{dir};
        
##    $eventHash = $c->param('eventHash');
##    $c->app->log->debug("Event Hash : $eventHash");
##    $eventConfig = decode_json($redis->get($eventHash));
##    $blockchain = $eventConfig->{'blockchain'};
##    $page = $eventConfig->{'page'};
    my @blockchain = $c->get_blockchains;
    foreach my $blockchain (@blockchain) {
		my $pid = "$dir/run/$blockchain\.pid";
		if (-f $pid) {
        if (!$redis->exists($blockchain.'_config')) {
                $c->load_blockchain_config;
        }
        push @{$dataIn}, decode_json($redis->get($blockchain.'_config'));
		} else {
			$c->debug("Blockchain $blockchain Not Yet Started - Skipping");
		}
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

sub wsapi {
    my $c = shift;
    
#    $c->kept_alive;
    $c->inactivity_timeout(60);
    $c->app->log->debug("Open Websocket");
    $c->app->log->debug(sprintf 'Client connected: %s', $c->tx);
    my $id = sprintf "%s", $c->tx;
    $clients->{$id} = $c->tx;

    $c->on(message => sub {
		my ($self, $msg) = @_;

		if ($msg eq '__ping__') {
			$c->app->log->debug("Ping");
			my $wsconid = $c->tx->handshake->{'connection'};
#			$c->debug("WSCon".$wsconid);
			$self->send({json => {
				channel => "pong",
				data => {
					msg => "__pong__"
				}
			}});
			return undef;
		}
		
#		$msg = decode_json($msg);
#		$c->debug($msg);
		
		
		my $rsub = $self->redis->subscribe(['status']);
	
		my $data;
	
		$rsub->on(message => sub {
			my ($rsub, $message, $channel) = @_;
			$c->app->log->debug("Subscribe Message");
			$message = decode_json($message);
			$data->{'channel'} = $channel;
			$data->{'data'} = $message;
			$self->send({json => $data});
			
		});
	});
    
	$c->on(finish => sub {
		$c->app->log->debug('Client disconnected');
		my $wsconid = $c->tx->handshake->{'connection'};
		$c->app->log->debug("Get connection id : $wsconid");

#        if ($cache->get("wscon_".$wsconid)) {
#                my $sessionid = $cache->get("wscon_".$wsconid);
#                $cache->delete("wscon_".$wsconid);
#                my $ua  = Mojo::UserAgent->new;
#                $ua->get("http://papi.apicomms.com/wsunreg/$sessionid");
#                print "Closing WS tidying up cache\n";
#        } else {
#                print "No Active Websocket connection\n";
#        }
		delete $clients->{$id};
	});

	}


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
    my $hash = $c->req->params->to_hash;
    
    my $input = $c->validation->output;
    $c->debug($input);
    my @params;
    my @array;
    if ($spec->{'x-order'}) {
		foreach my $item (@{$spec->{'x-order'}}) {
			push @array, $input->{$item};
		}
		push @params, \@array;
    }
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
