package PotNode::Helpers;
use base 'Mojolicious::Plugin';
use Data::UUID;
use Config::IniFiles;
use PotNode::QRCode;
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
    
    $app->helper(uuid => \&_uuid);
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
					$command = "/home/node/perl5/perlbrew/perls/perl-5.24.3/bin/hypnotoad $directory/pot_web.pl";
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


sub _uuid {
    my $self = shift;
    my $ug = Data::UUID->new;
    my $uuid = $ug->create();
    return $ug->to_string( $uuid );
};


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
