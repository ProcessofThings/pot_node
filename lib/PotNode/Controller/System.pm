package PotNode::Controller::System;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::QRCode;
use Mojo::URL;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Data::UUID;
#use Data::Dumper;
use Config::IniFiles;
use PotNode::InviteService;
# This action will render a template

my $ua = Mojo::UserAgent->new;

# sub start {
#     my $c = shift;
# #    my $ua  = Mojo::UserAgent->new;
#     my $url = $c->param('html') || "index";
# 	$url = 'http://127.0.0.1:8080/ipfs/QmX2We6Gcf9sBVcjLBHqPjUQjQuvA4UhqwSuyqvYSQfuyj/'.$url.'.html';
# 	$c->app->log->debug("URL : $url");
# #	my $html = $ua->get('http://127.0.0.1:8080/ipfs/QmfQMb2jjboKYkk5f1DhmGXyxcwNtnFJzvj92WxLJjJjcS')->res->dom->find('section')->first;
# 
# 	my $html = $ua->get($url)->res->dom->find('div.container')->first;
# 	#b('foobarbaz')->b64_encode('')->say;
# 	my $encodedfile = b($html);
# 	$c->app->log->debug("Encoded File : $encodedfile");
#     $c->stash(import_ref => $encodedfile);
#     
#     $c->render(template => 'system/start');
# };


sub check {
    my $redis = Mojo::Redis2->new;
    my $c = shift;
    my $path = "/home/node/.multichain/";
    my $process_chk_command;
    my $command;
    $c->app->log->debug("Recurring : Checking");
    my @config;
    my @rpc;
    my $sconfig;
    my $home = $c->config->{home};
    my $dir = $c->config->{dir};
    my $status;
    my $system;
    
    ## TODO : Multichain params (./multichain/DIR/params & RPC info from multichain.conf
    ## TODO : Find chain-description = pot
    ## TODO : Store default-network-port, default-rpc-port, chain-name
    
    # Clear expired generated uuids
    $c->app->log->debug("Clearing expired generated UUIDs.");
    PotNode::InviteService->new->clear_expired_uuids;

		eval{
			$c->redis->exists('system');
		};
		if ($@) {
			die "Redis Not Responding";
		}
	
		if (!$c->pid($c->config->{'hypnotoad'}->{'pid_file'})) {
			my $checkconfig = $c->config->{'precheck'};
			foreach my $function (@{$checkconfig}) {
				my $call = $function->{'function'};
				$c->$call($function->{'data'});
			}
#			if ($redis->hexists('system')) {
#				$system = $redis->get('system');
#				$redis->publish("system",$system);
#			}
		} else {
			my $checkconfig = $c->config->{'check'};
			foreach my $function (@{$checkconfig}) {
				my $call = $function->{'function'};
				$c->$call($function->{'data'});
			}
		}
    
    my @dir_list = glob("$path*");
    $c->debug(@dir_list);
    my @dir_list = grep(/\w{32}$/, @dir_list);
    ## TODO : YOU ARE HERE (Hope the party was worth it) Its something to do with the path, good luck
    my $dircount = @dir_list;
    $c->app->log->debug("Directories : $dircount");
    ## Checks the multichain directory for any active blockchains and checks if the daemon is running
    if ($dircount > 0) {
        my @blockchain = $c->get_blockchains;
        ## New Install or Restart Look for pot_config ( PoT is the Genisis Blockchain for the PoT Network all nodes require this )
        if (!$redis->exists("pot_config")){
            $c->app->log->debug("Loading Configs");
            $c->load_blockchain_config(@blockchain);
        }
        
        foreach my $entry (@blockchain) {
					$c->app->log->debug("Checking Blockchain $entry");
					$c->blockchain_change_state($entry);
        }
        
        $c->publish_status;

    } else {
        $command = 'ipfs add -r -w -Q /home/node/pot_node';
        my $value = qx/$command/;
        $value =~ s/\R//g;
        $c->app->log->debug("No Directories - Hash : $value");
        my $idinfo = $ua->get("http://127.0.0.1:5001/api/v0/id")->result->json;
        my @scanNetwork;
        my $network;
        $c->render_later;
        my $delay = Mojo::IOLoop->delay;
        $delay->steps(
            sub {
                my $delay = shift;
                $c->app->log->debug("Starting");
                ## IPFS : Find all peers providing the same hash as the pot_node application
                ## New Nodes will only find nodes running the same version of PoT Node
                ## TODO : New Version Checking after join the blockchain
                $ua->get("http://127.0.0.1:5001/api/v0/dht/findprovs?arg=$value&num-providers=3" => $delay->begin);
            },
            sub {
                my ($delay, $tx) = @_;
                $c->app->log->debug("Processing Data");
                $network = $tx->result->body;          
                my @ans = split(/\n/, $network);
                ## TODO IFPF: Create Test to check IPFS Format
                @ans = grep(/"Type":4/, @ans);
                my $count =  @ans;
                $c->app->log->debug("Items : $count");
                if ($count > 1) {
                    foreach my $line ( @ans ) {
                            my $data = decode_json($line);
                            if ($data->{'Type'} eq '4') {
                                    ## TODO IFPF: Create Test to check IPFS Format (Responce only ever contains a single array element ->[0]
                                    my $values = $data->{'Responses'}->[0];
                                    if ($values->{'ID'} ne $idinfo->{'ID'}) {
                                            foreach my $address ( @{$values->{'Addrs'}} ) {
                                                    my ($junk,$proto,$address,$trans,$port) = split('/', $address);
                                                    ## TODO : Add Support for IPv6
                                                    if ($proto eq 'ip4') {
                                                            if ($address ne '127.0.0.1') {
                                                                    ## Only Add $address to Array if grep cannot find the address in the array
                                                                    $address = "http://$address:9080/node/alive";
                                                                    $c->app->log->debug("Adding Address : $address");
                                                                    push(@scanNetwork, $address) if ( ! grep(/^$address$/, @scanNetwork));
                                                            }
                                                    }

                                            }
                                    }
                            }
                    }
                }
                $delay->pass();
            },
            sub {
                my ($delay, $tx) = @_;
                $c->app->log->debug("Testing URLs");
                $c->debug(@scanNetwork);

                $delay->on(finish => sub{
                    my ($delay, @tx) = @_;
                    $c->app->log->debug("Scan Finished");
                    foreach my $tx (@tx) {
                        if ($tx->res->is_success) {
                            ##TODO : on success then get pot port and join
                            $c->app->log->debug("Success");
                            my $responce = decode_json($tx->res->body);
                            $c->debug($responce);
                            my $command = "multichaind $responce->{'address'} -daemon -pid=/home/node/run/$responce->{'id'}.pid > /dev/null &";
                            system($command);
                        }
                    }
                });
                $ua->get( $_ => json => {'url' => $_} => $delay->begin ) for @scanNetwork;
            }
#             )->catch(
#                 sub {
#                     my ($delay, $err) = @_;
#                     warn $err; # parsing errors
#                     $delay->emit(finish => 'failed to get records');
#                 }
#             )->on(finish =>
#                 sub {
#                     my ($delay, @err) = @_;
#                     if (!@err) {
#                         process_records(@records);
#                     }
#                 }
        );
        
        $delay->wait;
        
    }
    
    ## Loads PoT Default Config from the Blockchain
    if (!$redis->exists("config_hash")){
        if ($redis->exists("pot_config")){
            ## Get PoTChain basics from the 
            my $pot_config = decode_json($redis->get("pot_config"));
            ## Waits for the blochchain to begin

            my $pid = "$dir/run/$pot_config->{'id'}\.pid";
#            my $pidid = qx/cat $pid/;
#            if (! -e "/proc/$pidid") {
#                $c->app->log->debug("Removing Stale PID files");
#                unlink $pid;
#            }
            
            if (-f $pid) {
                ## Check if config Retreaval is underway to prevent second attempt (10mins)
                if (!$redis->exists("setupconfig")){
                    ## Set setupconfig to prevent additional requests
                    $redis->setex('setupconfig',120, "started");
                    my $data = $c->get_rpc_config($pot_config->{'id'});
                    my $URL = Mojo::URL->new("http://127.0.0.1:$data->{'rpcport'}")->userinfo("$data->{'rpcuser'}:$data->{'rpcpassword'}");
                    ## Recurring ID holder for the recurring event.
                    my $recurringId;
                    ## Begin Non-Blocking Sequencial
                    $c->render_later;
                    my $delay = Mojo::IOLoop->delay;
                    $delay->steps(
                        sub {
                            ## Subscribe to config
                            my $delay = shift;
                            $c->app->log->debug("Setting Up Global Config");
                            $ua->get($URL => json => {"jsonrpc" => "1.0", "id" => "curltest","method" => "subscribe", "params" =>  ["config"]} => $delay->begin);
                        },
                        sub {
                            my $delay = shift;
                            $c->app->log->debug("Retreaving Config From Blockchain");
                            ## Converts UUID HEX back to standard UUID format with -
                            ## TODO : Blockchain ID using UUID cannot have the - maybe alter blockchain to allow this later date.
                            my $uuid = $c->hex_uuid_to_uuid($pot_config->{'id'});
                            ## Recurring Loop returns to $end when finished passing $result to be passed onto the next step
                            my $end = $delay->begin;
                            $recurringId = Mojo::IOLoop->recurring(
                                30 => sub {
                                    $c->app->log->debug("Checking for Config for $uuid");
                                    my $result = $ua->get($URL => json => {"jsonrpc" => "1.0", "id" => "curltest","method" => "liststreamkeyitems", "params" =>  ["config","$uuid",\0,1,-1]})->result->json;
                                    $result = $result->{'result'}->[0]->{'data'};
                                    if (defined($result)) {
                                        $c->app->log->debug("Data Found");
                                        ## First argument is left out unless you pass a 0 to $delay->begin, this is because most non-blocking methods will pass their object as the first parameter.
                                        $end->(0,$result);
                                    }
                                }
                            );
                        },
                        sub {
                            my ($delay, $result) = @_;
                            ## Recurring loop finished remove loop
                            Mojo::IOLoop->remove($recurringId);
                            $c->app->log->debug("Decrypting Data");
                            $redis->set('config_hash',$result);
                            my ($config) = $c->app->decrypt_aes($result,$pot_config->{'id'});
                            $redis->set('config',$config);
                            ## Remove setupconfig once complete
                            $redis->del('setupconfig');
                            $c->app->log->debug("Blockchain Config Loaded");
                        }
                    )->wait;
                } else {
                    $c->app->log->debug("Config Retreaval Already Started...");
                }
            } else {
                $c->app->log->debug("Waiting for Blockchain to start...");
            }
        } else {
            $c->app->log->debug("Blockchain not loaded - Skipping Config Retreaval");
        }
    } else {
		## Only reload config if the config hash in the blockchain has changed
		$c->app->log->debug("Blockchain Config Loaded - looking for changes");
		my $pot_config = decode_json($redis->get("pot_config"));
		my $data = $c->get_rpc_config($pot_config->{'id'});
		my $URL = Mojo::URL->new("http://127.0.0.1:$data->{'rpcport'}")->userinfo("$data->{'rpcuser'}:$data->{'rpcpassword'}");
		my $uuid = $c->hex_uuid_to_uuid($pot_config->{'id'});
		my $result = $ua->get($URL => json => {"jsonrpc" => "1.0", "id" => "curltest","method" => "liststreamkeyitems", "params" =>  ["config","$uuid",\0,1,-1]})->result->json;
		$result = $result->{'result'}->[0]->{'data'};
		my $config_hash = $redis->get('config_hash');
		if ($config_hash != $result) {
			$c->app->log->debug("Change in blockchain config detected");
			$redis->del('config_hash');
		} else {
			$c->app->log->debug("No change to Blockchain Config - Skipping");
		}
    }
    
    if (!$redis->exists("addpotnode")){
        $command = "ipfs add -r -w -Q $home";
        my $cmdreturn = qx/$command/;
        $cmdreturn =~ s/\R//g;
        my $currentversion = $cmdreturn;
        $c->app->log->debug("Version File checking for $cmdreturn");
        my $filename = "$dir/version.txt";  
        
        my $count = qx/grep -c "$cmdreturn" $filename/;
        $count =~ s/\R//g;
        if ($count eq '0') {
            $command = "echo \"$cmdreturn\" >> $filename";
            qx/$command/;
        } else {
            $c->app->log->debug("Version Exists $cmdreturn");
        }
  
        if ($redis->exists("config")) {
            my $config = $redis->get("config");
            $config = decode_json($config);
            $count = qx/grep -c "$config->{'config'}->{'pot_node'}" $filename/;
            $count =~ s/\R//g;
            if ($count eq '0') {
                $c->app->log->debug("Upgrading pot_node");
                $command = "ipfs pin add $config->{'config'}->{'pot_node'}";
                my $cmdreturn = qx/$command/;
                $c->debug($cmdreturn);
                ## TODO : Time Stamp Backup
                $command = "cp -r $home $dir/backup/$currentversion";
                my $cmdreturn = qx/$command/;
                ## TODO : Which Hypnotoad remove static path
                $command = "rm -rf $home;ipfs get -o=$home $config->{'config'}->{'pot_node'}/pot_node;/home/node/perl5/perlbrew/perls/perl-5.24.3/bin/hypnotoad $home/script/pot_node";
                $c->app->log->debug("Command : $command");
                my @cmdreturn = qx/$command/;
                $c->debug(@cmdreturn);             
            }
        }
        $c->app->log->debug("pot_node Hash : $cmdreturn");
        $redis->setex('addpotnode',30, "yes");
    }

    ## Load 9090_layout
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
            my $status = $ua->get("http://127.0.0.1:5001/api/v0/pin/ls?arg=$ipfsHash")->result->json;
            if ($status->{'Keys'}->{$ipfsHash}->{'Type'} ne "recursive") {
                $c->app->log->debug("Pinning App");
                $ua->get("http://127.0.0.1:5001/api/v0/pin/add?arg=$ipfsHash");
            }
            $c->app->log->debug("Getting $ipfsHash/config.json");
            my $config = $ua->get('http://127.0.0.1:8080/ipfs/'.$ipfsHash.'/config.json')->result->body;
            if ($config =~ /\n$/) { chop $config; };
            $config = decode_json($config);
            if ($config->{'navitems'}) {
                foreach my $item (@{$config->{'navitems'}}) {
                    foreach my $option (@{$item->{'navitems'}}) {
                        if ($option->{'href'}) {
#                            $option->{'href'} = $ipfsHash.$option->{'href'};
									$option->{'ipfs'} = $ipfsHash;
                        }
                    }
#                    $c->debug($item);
                    push @navitems, $item;
                }
                
            }
            my $dataOut->{'navitems'} = \@navitems;
            $redis->set(index => encode_json($dataOut));
        }
    };
    
    
    
    if (!$redis->exists("myipfsid")){
        my $idinfo = $ua->get("http://127.0.0.1:5001/api/v0/id")->result->json;
        $c->app->log->debug("IPFS ID : $idinfo->{ID}");
        $redis->set(myipfsid => encode_json($idinfo));
    }
    $c->render(text => 'Ok', status => 200);
};


sub alertnotify {
    my $c = shift;
    my $params = $c->req->params->to_hash;
    my $json = $c->req->json;
    $c->debug($params);
    $c->debug($json);
    $c->render(text => 'Ok', status => 200);
};

sub blocknotify {
    my $c = shift;
    $c->debug($c);
    $c->render(text => 'Ok', status => 200);
};

sub walletnotify {
    my $c = shift;
    $c->debug($c);
    $c->render(text => 'Ok', status => 200);
};

sub upload {
    my $c = shift;
    my $html = $ua->get('http://127.0.0.1:8080/ipfs/Qmbb28sUkFdGz3YxquVkXbE2CrWBFBceJyKYa1ms1W48do')->res->body;
    #b('foobarbaz')->b64_encode('')->say;
    my $encodedfile = b($html);
    $c->app->log->debug("Encoded File : $encodedfile");
    $c->stash(import_ref => $encodedfile);

    $c->render(template => 'system/start');
};

1;
