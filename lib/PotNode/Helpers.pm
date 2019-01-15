package PotNode::Helpers;
use base 'Mojolicious::Plugin';
use strict;
use warnings;
use Config::IniFiles;
use PotNode::QRCode;
use UUID::Tiny ':std';
use Data::UUID;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw(b64_decode b64_encode);
use PotNode::Multichain;
use String::HexConvert ':all';
use Encode::Base58::GMP;
use File::Grep qw/ fgrep /;



sub register {

    my ($self, $app) = @_;

    $app->helper(redis =>
	    sub { shift->stash->{redis} ||= Mojo::Redis2->new; });

    $app->helper(merge => sub {
        my ($self,$custData,$custLayout) = @_;
        my $dataOut;
        foreach my $items (@{$custLayout->{'layout'}}) {
                        my ($key,$type,$text,$value) = split(/,/,$items);
                        if ($custData->{$key}) {
                                $dataOut->{$key} = $custData->{$key};
                        } else {
                                $dataOut->{$key} = $value;
                        }
        }

        return $dataOut;
    });


	$app->helper(layout => sub {
        my ($self,$custData,$custLayout) = @_;
         foreach my $items (@{$custLayout}) {
                         my ($key,$type,$text,$value) = split(/,/,$items);
                         $custLayout->{$key} = $value;
                 }
        return $custLayout;
    });

    ## System Check Helper Functions

    $app->helper(pid => \&_pid);
    $app->helper(directory => \&_directory);
    $app->helper(ipfs_status => \&_ipfs_status);
    $app->helper(get_hash => \&_get_hash);
    $app->helper(pot_web => \&_pot_web);

    $app->helper(blockchain_change_state => \&_blockchain_change_state);
    $app->helper(publish_status => \&_publish_status);

    $app->helper(uuid => \&_uuid);
		$app->helper(hex_uuid_to_uuid => \&_hex_uuid_to_uuid);
    $app->helper(mergeHTML => \&_mergeHTML);
    $app->helper(cache_control_no_caching => \&_cache_control_none);
    $app->helper(get_rpc_config => \&_get_rpc_config);
    $app->helper(get_blockchains => \&_get_blockchains);
    $app->helper(load_blockchain_config => \&_load_blockchain_config);
    $app->helper(genqrcode64 => \&_genqrcode64);

		$app->helper(create_stream => \&_create_stream);
		$app->helper(publish_stream => \&_publish_stream);
		$app->helper(delete_stream_item => \&_delete_stream_item);
		$app->helper(get_stream_item => \&_get_stream_item);
		$app->helper(get_all_stream_item => \&_get_all_stream_item);
    $app->helper(mailchimp_subscribe => \&_mailchimp_subscribe);
    $app->helper(create_index => \&_create_index);

}

sub _pid {
	my ($c, $pid) = @_;
	my $pidid = qx/cat $pid/;
	my $system;
	if ($pidid =~ /\n$/) { chop $pidid; };
	$c->app->log->debug("Checking $pid");
	if ($c->redis->hexists('system', 'pid')) {
		my $system = decode_json($c->redis->hget('system', 'pid'));
		$c->app->log->debug("Current PID : $pidid  System PID : $system->{'pid'}");
		if ($system->{'pid'} ne "$pidid") {
			$system->{'pid'} = $pidid;
			$c->redis->hset('system', 'pid', encode_json($system));
			$c->app->log->debug("PID Changed load Precheck");
			return undef;
		}
		$c->app->log->debug("Skipping Precheck");
		return 1;
	}
	$system->{'pid'} = $pidid;
	$c->redis->hset('system','pid',encode_json($system));
	return undef;
}


sub _directory {
	my ($c, $data) = @_;
	my $system;
	$c->app->log->debug("Checking Directories");
	my $dir = $c->config->{'dir'};
	foreach my $directory (@{$data}) {
		my $path = "$dir/$directory";
		mkdir($path) unless(-d $path);
	}
	$system->{'directory'}->{'status'} = 1;
	$c->redis->hset('system', 'directory', encode_json($system));
	return;
}

sub _ipfs_status {
	## This helper function gets the IPFS hash of the directory passed
	my ($c, $command) = @_;
	my $system;
		my $value = qx/$command/;
		my $status;
		$value =~ s/\R//g;
		eval {
			$status = decode_json($value);
		};
		if ($@) {
			die "IPFS not installed invalid responce";
		}
		$system->{'ipfs'}->{'system'} = $status;
		$c->redis->hset('system' , 'ipfs', encode_json($system));
		$c->app->log->debug("IPFS Installed");
		return;
}

sub _get_hash {
	## This helper function gets the IPFS hash of the directory passed
	my ($c, $directory) = @_;
	my $system;
	if (-d $directory) {
		my $command = "ipfs add -r -w -Q $directory";
		my $value = qx/$command/;
		$value =~ s/\R//g;
		$c->app->log->debug("Directory $directory - Hash : $value");
		$system->{'pot'}->{'hash'} = $value;
		$c->redis->hset('system', 'pot_hash',encode_json($system));
		return;
	} else {
		die "directory does not exist";
  }
}

sub _pot_web {
	## This helper function gets the IPFS hash of the directory passed
	my ($c, $directory) = @_;
	my $pid = '/home/node/run/pot_web.pid';
	my $system;
	my $pot_web;
	if (-d $directory) {
	  my $command = "ipfs add -r -w -Q $directory";
		my $value = qx/$command/;
		if (!$c->redis->hexists('system','pot_web')) {
			$c->app->log->debug("PoT Web found saving hash $value");
			$system->{'pot_web'}->{'hash'} = $value;
		} else {
			$system = decode_json($c->redis->hget('system', 'pot_web'));
			if ($system->{'hash'} ne $value) {
					$c->app->log->debug("PoT Web hash has changed - reloading");
					$system->{'hash'} = $value;
					my $command = "/home/node/perl5/perlbrew/perls/perl-5.24.3/bin/hypnotoad $directory/pot_web.pl";
					my $value = qx/$command/;
					$value =~ s/\R//g;
			}
		}

		if (!-f $pid) {
			$command = "/home/node/perl5/perlbrew/perls/perl-5.24.3/bin/hypnotoad $directory/pot_web.pl";
			$c->app->log->debug("Starting PoT Web - $command");
			my $value = qx/$command/;
			$value =~ s/\R//g;
			$c->app->log->debug("Directory $directory - Status : $value");
		} else {
			my $pidid = qx/cat $pid/;
			if ($pidid =~ /\n$/) { chop $pidid; };
			$c->app->log->debug("Checking $pid");
			if ($c->redis->hexists('system', 'pot_web')) {
				$c->app->log->debug("PoT Web Current PID : $pidid  PoT Web PID : $system->{'pid'}");
				if ($system->{'pid'} ne "$pidid") {
					$system->{'pid'} = $pidid;
					$c->redis->hset('system', 'pot_web', encode_json($system));
					$c->app->log->debug("PID Changed load Precheck");
					return undef;
				}
				$c->app->log->debug("Skipping Precheck");
				return 1;
			}
			$system->{'pid'} = $pidid;
		}
		$c->redis->hset('system', 'pot_web',encode_json($system));
		return;
	} else {
		$c->app->log->debug("Skipping PoT Web - directory does not exist");
		return;
  }
}


sub _blockchain_change_state {
	my ($c, $blockchain) = @_;
	my $status;

	## Loads Config if a new blockchain is found
	if (!$c->redis->exists($blockchain."_config")){
		$c->app->log->debug("New Blockchain Found Loading Config");
		$c->load_blockchain_config($blockchain);
	}

	## Gets the PID id from the pid files and removes them if the process is not running
	my $pid = "/home/node/run/$blockchain\.pid";
	my $pidid = qx/cat $pid/;
	if ($pidid =~ /\n$/) { chop $pidid; };
	if (! -d "/proc/$pidid") {
		$status->{'status'} = "Removing Stale PID files $pidid";
		$c->redis->hset('blockchain_status', $blockchain, encode_json($status));
		$c->app->log->debug("Removing Stale PID files $pidid");
		unlink $pid;
	}

	my $delay = Mojo::IOLoop->delay;

	## Check if chain if blockchain is disabled
  if ( -f '/home/node/run/'.$blockchain.'.stop') {
		if ( -f '/home/node/run/'.$blockchain.'.pid') {
			$delay->steps(
				sub {
					$c->app->log->debug("Stopping Blockchain $blockchain");
					my $command = 'multichain-cli '.$blockchain.' stop';
					system($command);
					my $subprocess = Mojo::IOLoop::Subprocess->new;
					$subprocess->run(
						sub {
							my $subprocess = shift;
							$status->{'status'} = "Shutting down";
							$status->{'icon'} = "flight_land";
							$c->redis->hset('blockchain_status', $blockchain, encode_json($status));
							$c->publish_status;
							while (1) {
								$c->app->log->debug("Waiting for PID");
								last if !-e '/home/node/run/'.$blockchain.'.pid';
								sleep 1;
							}
							return;
						},
						sub {
							my ($subprocess, $err, @results) = @_;
							$c->app->log->debug("Subprocess $err") and return if $err;
							$status->{'status'} = "Stopped";
							$status->{'icon'} = "highlight_off";
							$c->redis->hset('blockchain_status', $blockchain, encode_json($status));
							$c->publish_status;
							$c->app->log->debug("Process Stopped");
						}
					);
					$subprocess->ioloop->start unless $subprocess->ioloop->is_running;
					$delay->pass();
				},
				sub {
					my ($delay, $tx) = @_;

					$delay->on(finish => sub{
						my ($delay, @tx) = @_;
						$c->app->log->debug("Process Finished");
					});
				});
				$delay->wait;
		} else {
			$c->app->log->debug("Blockchain .stop located - skipping blockchain");
			$status->{'status'} = "Stopped";
			$status->{'icon'} = "highlight_off";
			$c->redis->hset('blockchain_status', $blockchain, encode_json($status));
		}
	} else {
		## Checks if the pid file exists before trying to start the multichain daemon if it exists express the process id
		if ( -f '/home/node/run/'.$blockchain.'.pid') {
			$c->app->log->debug("Running Process : $blockchain with PID : $pidid");
			$status->{'status'} = "Running";
			$status->{'icon'} = "done";
			$c->redis->hset('blockchain_status', $blockchain, encode_json($status));
		} else {
			$delay->steps(
				sub {
					$c->app->log->debug("Starting Blockchain $blockchain");
					my $command = 'multichaind '.$blockchain.' -daemon -pid=/home/node/run/'.$blockchain.'.pid -walletnotifynew="curl -H \'Content-Type: application/json\' -d %j http://127.0.0.1:9090/system/alertnotify?name=%m\&txid=%s\&hex=%h\&seen=%c\&address=%a\&assets=%e" > /dev/null &';
					system($command);
					my $subprocess = Mojo::IOLoop::Subprocess->new;
					$subprocess->run(
						sub {
							my $subprocess = shift;
							$status->{'status'} = "Starting";
							$status->{'icon'} = "flight_takeoff";
							$c->redis->hset('blockchain_status', $blockchain, encode_json($status));
							$c->publish_status;
							while (1) {
								$c->app->log->debug("Waiting for PID");
								last if -e '/home/node/run/'.$blockchain.'.pid';
								sleep 1;
							}
							return;
						},
						sub {
							my ($subprocess, $err, @results) = @_;
							$c->app->log->debug("Subprocess $err") and return if $err;
							$status->{'status'} = "Running";
							$status->{'icon'} = "done";
							$c->redis->hset('blockchain_status', $blockchain, encode_json($status));
							$c->publish_status;
							$c->app->log->debug("Blockchain Started");
						}
					);
					$subprocess->ioloop->start unless $subprocess->ioloop->is_running;
					$delay->pass();
				},
				sub {
					my ($delay, $tx) = @_;

					$delay->on(finish => sub{
						my ($delay, @tx) = @_;
						$c->app->log->debug("Process Finished");
					});
				});
				$delay->wait;
		}
	}

#	$status = encode_json($status);
#	$redis->set("status" => $status);
#	$redis->publish("status" => $status);

	return;
};

sub _publish_status {
	my $c = shift;
	my @blockchain = $c->get_blockchains;
	my $status;
	foreach my $blockchain (@blockchain) {
		my $blockchain_status = decode_json($c->redis->hget('blockchain_status',$blockchain));
		$c->debug($blockchain_status);
		$status->{$blockchain}->{'id'} = $blockchain;
		$status->{$blockchain}->{'status'} = $blockchain_status->{'status'};
		$status->{$blockchain}->{'icon'} = $blockchain_status->{'icon'};
	}
	$c->debug($status);
	$status = encode_json($status);
	$c->redis->set("status" => $status);
  $c->redis->publish("status" => $status);
	return;
}


sub _uuid {
		## This function returns uuid and hex version of the same UUID

    my $self = shift;
    my $uuid_rand  = uuid_to_string(create_uuid(UUID_RANDOM));
    my $uuid_binary = create_uuid(UUID_SHA1, UUID_NS_DNS, $uuid_rand);
    my $hex;
    $hex =~ tr/-//d;

		## Converts UUID to uppercase string

    my $uuid_string = $hex = uc(uuid_to_string($uuid_binary));

    $hex =~ tr/-//d;

    return ($uuid_string, $hex);
};

sub _hex_uuid_to_uuid {
	my ($self, $hex) = @_;
	my $ug = Data::UUID->new;
	my $uuid = $ug->from_hexstring($hex);
	$uuid = $ug->to_string($uuid);
	return $uuid;
}


sub _cache_control_none {
        my $c = shift;
        $c->res->headers->cache_control('private, max-age=0, no-cache');
};

sub _get_rpc_config {
    my ($self,$blockchain) = @_;
    my $multichain = $self->config->{multichain};
    my $conflocation = $multichain.'/'.$blockchain;
    $self->app->debug($conflocation);
    my $cfg = Config::IniFiles->new(-file => "$conflocation/params.dat",-fallback => "General",-commentchar => '#',-handle_trailing_comment => 1);
    my $rpc = Config::IniFiles->new(-file => "$conflocation/multichain.conf",-fallback => "General",-commentchar => '#',-handle_trailing_comment => 1);
    my $data;
    $data->{'rpcuser'} = $rpc->val("General","rpcuser");
    $data->{'rpcpassword'} = $rpc->val("General","rpcpassword");
    $data->{'rpcport'} = $cfg->val("General","default-rpc-port");
    $cfg->Delete;
    $rpc->Delete;
    $self->redis->set('rpc_'.$blockchain => encode_json($data));
    return $data;
};

sub _get_blockchains {
    my ($self,$blockchain) = @_;
    my $multichain = $self->config->{multichain};
    my @dirList = glob("$multichain/*");
    @dirList = grep(/\w{32}$/, @dirList);
    my @dataOut;
    foreach my $dir (@dirList) {
        $dir =~ /\w{32}$/;
        push @dataOut, $&;
    }
    return @dataOut;
};

sub _load_blockchain_config {
    my ($self,@blockchain) = @_;
    my $multichain = $self->config->{multichain};
    foreach my $id (@blockchain) {
        $self->app->log->debug("Loading config for blockchain $id");
        my $conflocation = $multichain.'/'.$id;
        my $cfg = Config::IniFiles->new(-file => "$conflocation/params.dat",-fallback => "General",-commentchar => '#',-handle_trailing_comment => 1);
        my $data;
        my $name = $cfg->val("General","chain-description");
        $data->{'id'} = $id;
        $data->{'path'} = $conflocation;
        $data->{'name'} = $name;
        $data->{'networkport'} = $cfg->val("General","default-network-port");
        $data->{'rpcport'} = $cfg->val("General","default-rpc-port");
        $cfg->Delete;
        $self->redis->setex($name."_config",3600, encode_json($data));
        $self->redis->setex($id."_config",3600, encode_json($data));
    }
};

sub _mergeHTML {
    my ($self,$custData,$custLayout) = @_;
    my $dataOut;
    foreach my $items (@{$custLayout}) {
                    my ($key,$type,$text,$value) = split(/,/,$items);

                    if ($custData->{$key}) {
                            my @newArray = [$key,$type,$text,$custData->{$key}];
                            push @{$dataOut->{'layout'}}, @newArray;
                    } else {
                            my @newArray = [$key,$type,$text,$value];
                            push @{$dataOut->{'layout'}}, @newArray;
                    }
    }
    return $dataOut;
};

sub _blockchain_api {

};

sub _genqrcode64 {
	 ## Generates QRCode
    ## 38mm Label needs size 3 Version 5 (default)
    ## 62mm With Text size 4 Version 5
    ## 62mm No Text size 5 60mmX60mm Version 5
    my $self = shift;
    my $text = shift;
    my $timestamp = time();
    my $size = shift || 5;
    my $version = shift || 5;
    my $blank = shift || 'no';
    my $data;
    if ($blank eq 'no') {
            $text = 'https://pot.ec/'.$text;
    }
    my $mqr  = PotNode::QRCode->new(
    text   => $text,
    qrcode => {size => $size,margin => 2,version => $version,level => 'H'}
    );
    my $logo = Imager->new(file => "/home/node/pot_node/public/images/potlogoqrtag.png") || die Imager->errstr;
    $mqr->logo($logo);
    $mqr->to_png_base64("/home/node/tmp/qr-$timestamp.png");
	 $data->{'image'} = $mqr->to_png_base64("/home/node/tmp/qr-$timestamp.png");
    return $data;
};

sub _create_stream {
	my ($self, $blockChainId, $streamId) = @_;
	my $config = "rpc_$blockChainId";
	if (!$self->redis->exists($config)) {
			$config = $self->get_rpc_config($blockChainId);
	} else {
			$config = decode_json($self->redis->get($config));
	}

	my $url = "$config->{'rpcuser'}:$config->{'rpcpassword'}\@127.0.0.1:$config->{'rpcport'}";
	
	my $api =  PotNode::Multichain->new( url => $url );
	
	my @params = ["$streamId"];
	my $stream = $api->liststreams( @params );
	$self->app->debug($stream);
	if ($stream =~ /^400.*not\sfound/) {
		@params = ["stream","$streamId",\0];
		my $createstream = $api->create( @params );
		@params = ["$streamId"];
		$api->subscribe( @params );
	}
	
	if (!$stream->{subscribed}) {
		$api->subscribe( @params );
	}
	
	return 1;
};

sub _publish_stream {
	my ($self, $blockChainId, $streamId, $container) = @_;
  my $dataOut;
  my @params;

	$self->app->debug("Publish");
	my $config = "rpc_$blockChainId";
	if (!$self->redis->exists($config)) {
			$config = $self->get_rpc_config($blockChainId);
	} else {
			$config = decode_json($self->redis->get($config));
	}
	
	my $url = "$config->{'rpcuser'}:$config->{'rpcpassword'}\@127.0.0.1:$config->{'rpcport'}";
	my $api =  PotNode::Multichain->new( url => $url );
	
	$self->app->debug($container->{'containerid'});
	
	my $json = encode_json($container);
	$json = ascii_to_hex($json);
	@params = ["$streamId", $container->{'containerid'}, $json];
	
	$self->app->debug(@params);
	
	$dataOut = $api->publish( @params );
	
	return $dataOut;
};

sub _delete_stream_item {
	my ($self, $blockChainId, $streamId, $container) = @_;
  my @params;
  my $dataOut;
	$self->app->debug("Publish");
	my $config = "rpc_$blockChainId";
	if (!$self->redis->exists($config)) {
			$config = $self->get_rpc_config($blockChainId);
	} else {
			$config = decode_json($self->redis->get($config));
	}
	
	my $url = "$config->{'rpcuser'}:$config->{'rpcpassword'}\@127.0.0.1:$config->{'rpcport'}";
	my $api =  PotNode::Multichain->new( url => $url );
	
	@params = ["$streamId", $container->{'containerid'}, "ff"];
	
	$dataOut = $api->publish( @params );
	
	return $dataOut;
};

sub _get_stream_item {
	my ($self, $blockChainId, $streamId, $containerid) = @_;
	my $dataOut;
	$self->app->debug("Stream Item");
	my $config = "rpc_$blockChainId";
	if (!$self->redis->exists($config)) {
			$config = $self->get_rpc_config($blockChainId);
	} else {
			$config = decode_json($self->redis->get($config));
	}
	
	my $url = "$config->{'rpcuser'}:$config->{'rpcpassword'}\@127.0.0.1:$config->{'rpcport'}";
	my $api =  PotNode::Multichain->new( url => $url );

	my @params = ["$streamId", $containerid];
	my $query = $api->liststreamkeyitems( @params );
	foreach my $item (@{$query->{'result'}}) {
		if($item->{'data'} ne 'ff') {
			my $json = hex_to_ascii($item->{'data'});
      $self->app->debug($json);
			$json = decode_json($json);
			$self->app->debug('Stream Item Data');
			$self->app->debug($json);
			if (defined($json->{'cdata'})) {
				$dataOut->{$json->{'containerid'}}->{'containerid'} = $json->{'containerid'};
				$dataOut->{$json->{'containerid'}}->{'cdata'} = $json->{'cdata'};
				$dataOut->{$json->{'containerid'}}->{'attribs'} = $json->{'attribs'} if defined($json->{'attribs'});
			}
		}
		if ($item->{'data'} eq 'ff') {
			$self->app->debug("Item Deleted");
			delete $dataOut->{$item->{'key'}};
		}
	}
	
	$self->app->debug($dataOut);
	
	return $dataOut;
};

sub _get_all_stream_item {
	my ($self, $blockChainId, $streamId, $count, $deleted) = @_;
	my $dataOut;
  my @params;

	$self->app->debug("Get all Stream Item");
	my $config = "rpc_$blockChainId";
	if (!$self->redis->exists($config)) {
			$config = $self->get_rpc_config($blockChainId);
	} else {
			$config = decode_json($self->redis->get($config));
	}
	
	my $url = "$config->{'rpcuser'}:$config->{'rpcpassword'}\@127.0.0.1:$config->{'rpcport'}";
	my $api =  PotNode::Multichain->new( url => $url );
	
	@params = ["$streamId"];
	my $querycount = $api->liststreamkeys( @params );
	
	$dataOut->{'count'} = @{$querycount->{'result'}};
	
	$count = $dataOut->{'count'} + 10;
  $self->app->debug($count);
	
	@params = ["$streamId", "*", \1, 1000];
	my $query = $api->liststreamkeyitems( @params );

	$self->app->debug($query);
	
	if (scalar @{$query->{'result'}} == 0) {
		$dataOut->{'00'}->{'containerid'} = "00";
		$dataOut->{'00'}->{'cdata'}->{'companyName'} = "Empty";
	} else {
		foreach my $item (@{$query->{'result'}}) {
			if($item->{'data'} ne 'ff') {
				my $json = hex_to_ascii($item->{'data'});
        $json = eval { decode_json($json) };
        if ($@)
        {
            $self->app->debug("decode_json failed, invalid json. error:$@ - $item->{'key'}");
            my $container;
            $container->{'containerid'} = $item->{'key'};
            $self->app->delete_stream_item($blockChainId,$streamId,$container);
        }
        $self->app->debug($json);
#				$json = decode_json($json);
	#			$self->app->debug($json);
				if (defined($json->{'cdata'})) {
					$dataOut->{$json->{'containerid'}}->{'containerid'} = $json->{'containerid'};
  				$dataOut->{$json->{'containerid'}}->{'cdata'} = $json->{'cdata'};
				}
			}
#      if ($item->{'data'} eq 'ff') {
#        $self->app->debug("Item Deleted");
#        $self->app->debug($item);
#        @params = [ "$streamId", "$item->{'key'}", \1, 10, -2 ];
#        my $deletedQuery = $api->liststreamkeyitems(@params);
#        $self->app->debug($deletedQuery);
#        foreach my $item (@{$query->{'result'}}) {
#          if ($item->{'data'} ne 'ff') {
#            my $json = hex_to_ascii($item->{'data'});
#            $json = decode_json($json);
#            $self->app->debug($json);
#            if (defined($json->{'cdata'})) {
#              $dataOut->{$json->{'containerid'}}->{'containerid'} = $json->{'containerid'};
#              $json->{'cdata'}->{'deleted'} = "true";
#              $dataOut->{$json->{'containerid'}}->{'cdata'} = $json->{'cdata'};
#            }
#          }
#        }
#      }
#      if (! $deleted) {
        if ($item->{'data'} eq 'ff') {
          $self->app->debug("Item Deleted");
          delete $dataOut->{$item->{'key'}};
        }
 #     }
		}
	}
	
	#$self->app->debug($dataOut);
	
 	return $dataOut;
};

sub _mailchimp_subscribe {
  my ($self, $container) = @_;
  my $mailchimp;
  $mailchimp->{email_address} = $container->{'cdata'}->{'userEmail'};
  $mailchimp->{status} = 'subscribed';
  $mailchimp->{merge_fields}->{FNAME} = $container->{'cdata'}->{'userFirstName'};
  $mailchimp->{merge_fields}->{LNAME} = $container->{'cdata'}->{'userLastName'};
  my $mc_config;
  $mc_config->{apikey} = 'anystring:somekey';
  $mc_config->{listid} = 'somelistid';
  $mc_config->{run} = 'no';
  $mc_config = encode_json($mc_config);
  my $requrl = $self->req->headers->header('X-Url');
  $self->app->debug($requrl);
  if (!$self->redis->exists('mc_config')) {
    $self->redis->set('mc_config', $mc_config);
  } else {
    $mc_config = decode_json($self->redis->get('mc_config'));
  }
  if ($mc_config->{run} eq 'yes') {
    my $key = b64_encode($mc_config->{apikey}, '');
    my $ua = Mojo::UserAgent->new;
    $ua->max_redirects(10);
    $ua->on(start => sub {
      my ($ua, $tx) = @_;
      $tx->req->headers->authorization("Basic $key");
    });
    my $url = Mojo::URL->new("https://us7.api.mailchimp.com/3.0/lists/$mc_config->{listid}/members")->userinfo($mc_config->{apikey});
    my $responce = $ua->post($url => json => $mailchimp)->res->body;
    $self->app->debug('Mailchimp');
    $self->app->debug($responce);
  }
  return 1;
};

sub _create_index {
  my ($c, $streamId, $container) = @_;
  my @array;
  my $message;
	push(@array, "CID$container->{'containerid'}");
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userEmail'}));
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
	my $index = join(' ', @array);
	$c->app->debug("Index : $index");
	my $file = "/home/node/search/$streamId.txt";
	if (not -e $file) {
		$c->app->debug("File Not found adding Index");
    open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
      say $fh $index;
    close $fh;
    $message = {'message' => 'Success', 'status' => 200};
	} else {
		$c->app->debug("Search");
		my $userName = Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'});
		$c->app->debug("$userName");
		my @matches = fgrep { /$userName/ } $file;
		$c->app->debug(@matches[0]);
		$c->app->debug(@matches[0]->{'count'});
		if (@matches[0]->{'count'} < 1) {
			$c->app->debug("Search Entry Not Found");
      open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
      say $fh $index;
      close $fh;
      $message = {'message' => 'Success', 'status' => 200};
		} else {
      $message = {'message' => 'Problem adding to Index', 'status' => 400};
		}
	}
  return $message;
};



1;
