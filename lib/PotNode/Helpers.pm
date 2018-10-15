package PotNode::Helpers;
use base 'Mojolicious::Plugin';
use Config::IniFiles;
use PotNode::QRCode;
use UUID::Tiny ':std';
use Data::UUID;
use Mojo::JSON qw(decode_json encode_json);



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
    $app->helper(cache_control.no_caching => \&_cache_control_none);
    $app->helper(get_rpc_config => \&_get_rpc_config);
    $app->helper(get_blockchains => \&_get_blockchains);
    $app->helper(load_blockchain_config => \&_load_blockchain_config);
    $app->helper(genqrcode64 => \&_genqrcode64);
    

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
		$command = "ipfs add -r -w -Q $directory";
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
	  $command = "ipfs add -r -w -Q $directory";
		my $value = qx/$command/;
		if (!$c->redis->hexists('system','pot_web')) {
			$c->app->log->debug("PoT Web found saving hash $value");
			$system->{'pot_web'}->{'hash'} = $value;
		} else {
			$system = decode_json($c->redis->hget('system', 'pot_web'));
			if ($system->{'hash'} ne $value) {
					$c->app->log->debug("PoT Web hash has changed - reloading");
					$system->{'hash'} = $value;
					$command = "/home/node/perl5/perlbrew/perls/perl-5.24.3/bin/hypnotoad $directory/script/pot_web.pl";
					my $value = qx/$command/;
					$value =~ s/\R//g;
			}
		}
		
		if (!-f $pid) {
			$command = "/home/node/perl5/perlbrew/perls/perl-5.24.3/bin/hypnotoad $directory/script/pot_web.pl";
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
					$command = 'multichain-cli '.$blockchain.' stop';
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
				$delay-wait;
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
					$command = 'multichaind '.$blockchain.' -daemon -pid=/home/node/run/'.$blockchain.'.pid -walletnotifynew="curl -H \'Content-Type: application/json\' -d %j http://127.0.0.1:9090/system/alertnotify?name=%m\&txid=%s\&hex=%h\&seen=%c\&address=%a\&assets=%e" > /dev/null &';
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
				$delay-wait;
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
    my @dirList = grep(/\w{32}$/, @dirList);
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
    my ($self,$text) = @_;
    my $timestamp = time();
    my $size = 5;
    my $version = 5;
    my $blank = 'no';
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

1;
