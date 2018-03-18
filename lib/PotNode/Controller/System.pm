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
use Data::Dumper;
use Config::IniFiles;

# This action will render a template

  my $ua = Mojo::UserAgent->new;

sub start {
    my $c = shift;
#    my $ua  = Mojo::UserAgent->new;
    my $url = $c->param('html') || "index";
	$url = 'http://127.0.0.1:8080/ipfs/QmX2We6Gcf9sBVcjLBHqPjUQjQuvA4UhqwSuyqvYSQfuyj/'.$url.'.html';
	$c->app->log->debug("URL : $url");
#	my $html = $ua->get('http://127.0.0.1:8080/ipfs/QmfQMb2jjboKYkk5f1DhmGXyxcwNtnFJzvj92WxLJjJjcS')->res->dom->find('section')->first;

	my $html = $ua->get($url)->res->dom->find('div.container')->first;
	#b('foobarbaz')->b64_encode('')->say;
	my $encodedfile = b($html);
	$c->app->log->debug("Encoded File : $encodedfile");
    $c->stash(import_ref => $encodedfile);
    
    $c->render(template => 'system/start');
};


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
    
    ## TODO : Multichain params (./multichain/DIR/params & RPC info from multichain.conf
    ## TODO : Find chain-description = pot
    ## TODO : Store default-network-port, default-rpc-port, chain-name

    my @dir_list = glob("$path*");
    $c->debug(@dir_list);
    my @dir_list = grep(/\w{32}$/, @dir_list);
    ## TODO : YOU ARE HERE (Hope the party was worth it) Its something to do with the path, good luck
    my $dircount = @dir_list;
    $c->app->log->debug("Directories : $dircount");
    ## Checks the multichain directory for any active blockchains and checks if the daemon is running
    if ($dircount > 0) {
        if (!$redis->exists("potchain")){
            ## This searches each PoT Multichain that is availiable for the one called with chain-description = pot it then offers this to other nodes wanting to connect
            $c->debug(@dir_list);
            foreach my $dir ( @dir_list ) {
                my $config = $dir.'/params.dat';
                my $rpc = $dir.'/multichain.conf';
                @config = qx/grep -E "default-network-port|default-rpc-port|chain-name|chain-description" $config/;
                @rpc = qx/grep -E "rpcuser|rpcpassword" $rpc/;
                
                if (grep(/^.*= pot/, @config)) {
                    if ($dir =~ m/\w{32}$/) {
                        $c->app->log->debug("PoT Blockchain found : $&");
                        my $cfg = Config::IniFiles->new(-file => "$dir/params.dat",-fallback => "General",-commentchar => '#',-handle_trailing_comment => 1);
                        my $data;
                        $data->{'id'} = $&;
                        $data->{'path'} = $dir;
                        $data->{'networkport'} = $cfg->val("General","default-network-port");
                        $data->{'rpcport'} = $cfg->val("General","default-rpc-port");
                        $cfg->Delete;
                        $c->app->log->debug("Data Before writing to Redis");
                        $redis->setex('potchain',1800, encode_json($data));
                    }
                    
                    $c->debug(@config);
                }
            }
        }
        
        opendir( my $DIR, $path );
        while ( my $entry = readdir $DIR ) {
            ## Finds all directories and filters out all directories apart from those that contain HEX 32 chars
            next unless -d $path . '/' . $entry;
            next if $entry eq '.' or $entry eq '..';
            next if $entry !~ m/^\w{32}$/;
            if ( -f '/home/node/run/'.$entry.'.pid') {
                $c->app->log->debug("Running Process : $entry");
            } else {
                ## launched the daemon using > /dev/null & to return control to mojolicious
                $command = 'multichaind '.$entry.' -daemon -pid=/home/node/run/'.$entry.'.pid -walletnotifynew="curl -H \'Content-Type: application/json\' -d %j http://127.0.0.1:9090/system/alertnotify?name=%m\&txid=%s\&hex=%h\&seen=%c\&address=%a\&assets=%e" > /dev/null &';
                system($command);
                $c->app->log->debug("Starting : $entry");
            }
        }
        
        closedir $DIR;
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
    if (!$redis->exists("config")){
        if ($redis->exists("potchain")){
            my $ug = Data::UUID->new;
            ## Get PoTChain basics from the 
            my $potchain = decode_json($redis->get("potchain"));
            my $cfg = Config::IniFiles->new(-file => "$potchain->{'path'}/multichain.conf",-fallback => "General",-commentchar => '#',-handle_trailing_comment => 1);
            my $data;
            $data->{'rpcuser'} = $cfg->val("General","rpcuser");
            $data->{'rpcpassword'} = $cfg->val("General","rpcpassword");
            $data->{'rpcport'} = $potchain->{'rpcport'};
            $cfg->Delete;
            my $URL = Mojo::URL->new("http://127.0.0.1:$data->{'rpcport'}")->userinfo("$data->{'rpcuser'}:$data->{'rpcpassword'}");
            my $ua  = Mojo::UserAgent->new;
            my $uuid = $ug->from_hexstring($potchain->{'id'});
            $uuid = $ug->to_string($uuid);
            my $result = $ua->get($URL => json => {"jsonrpc" => "1.0", "id" => "curltest","method" => "liststreamkeyitems", "params" =>  ["config","$uuid",\0,1,-1]})->result->json;
            $result = $result->{'result'}->[0]->{'data'};
            my ($config) = $c->app->decrypt_aes($result,$potchain->{'id'});
            $redis->setex('config',1800, $config);
            $c->app->log->debug("Blockchain Config Loaded");
        } else {
            $c->app->log->debug("Blockchain not loaded - Skipping Config Retreaval");
        }
    } else {
        $c->app->log->debug("Blockchain Config Loaded - Skipping");
    }
    
    if (!$redis->exists("addpotnode")){
        $command = 'ipfs add -r -w -Q /home/node/pot_node';
        my $cmdreturn = qx/$command/;
        $cmdreturn =~ s/\R//g;
        $c->app->log->debug("Version File checking for $cmdreturn");
        my $filename = '/home/node/version.txt';  
        
        my $count = qx/grep -c "$cmdreturn" $filename/;
        $count =~ s/\R//g;
        if ($count eq '0') {
            $command = "echo \"$cmdreturn\" >> $filename";
            qx/$command/;
        } else {
            $c->app->log->debug("Version Exists $cmdreturn");
        }
  
        if ($redis->exists("config")){
            my $config = $redis->get("config");
            $config = decode_json($config);
            $count = qx/grep -c "$config->{'config'}->{'pot_node'}" $filename/;
            $count =~ s/\R//g;
            if ($count eq '0') {
                $c->app->log->debug("Upgrading pot_node");
                $command = "ipfs pin add $config->{'config'}->{'pot_node'}";
                my $cmdreturn = qx/$command/;
                $c->debug($cmdreturn);
                $command = "ipfs get $config->{'config'}->{'pot_node'}/pot_node";
                my $cmdreturn = qx/$command/;
                $c->debug($cmdreturn);
                $command = "hypnotoad /home/node/pot_node/script/pot_node";
                my $cmdreturn = qx/$command/;
                $c->debug($cmdreturn);
                
            }
        }
        $c->app->log->debug("pot_node Hash : $cmdreturn");
        $redis->setex('addpotnode',30, "yes");
    }

    
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

sub createchain {
    my $c = shift;
 #   my $ua  = Mojo::UserAgent->new;
    
    if ($c->req->method('GET')) {
        $c->render(template => 'system/createchain');
    }
    
    if ($c->req->method('POST')) {
        my $ug = Data::UUID->new;
        my $uuid = $ug->to_string($ug->create());
        $uuid =~ s/-//g;
        my $param = $c->req->params->to_hash;
        say $c->app->dumper($param);
        my @optionlist;
        push (@optionlist,"-chain-description=$param->{'name'}") if $param->{'name'};
        push (@optionlist,"-anyone-can-connect=true") if $param->{'public'};
        push (@optionlist,"-anyone-can-send=true,anyone-can-receive=true") if $param->{'sr'};
        my $options = join(' ', @optionlist);
        $c->app->log->debug("Options : $options");
        ## TODO : Get path using which
        my $command = "/usr/local/bin/multichain-util create $uuid $options";
        my $create = qx/$command/;
        $c->app->log->debug("Create : $create");
        
    }
    
    
};


sub genqrcode {
    ## Generates QRCode
    ## 38mm Label needs size 3 Version 5 (default)
    ## 62mm With Text size 4 Version 5
    ## 62mm No Text size 5 60mmX60mm Version 5
    my $c = shift;
    #my $ua  = Mojo::UserAgent->new;
    my $ug = Data::UUID->new;
    my $uuid = $ug->create();
    $uuid = $ug->to_string( $uuid );
    my $text = $c->param('text') || "container/$uuid";
    my $size = $c->param('s') || 3; 
    my $version = $c->param('v') || 5;
    my $blank = $c->param('b') || 'n';
    print "Text : $text\n";
    if ($blank ne 'y') {
            $text = 'https://pot.ec/'.$text;
    }       
    my $mqr  = Api::QRCode->new(
    text   => $text,
    qrcode => {size => $size,margin => 2,version => $version,level => 'H'}
    );
    my $logo = Imager->new(file => "public/images/potlogoqrtag.png") || die Imager->errstr;
    $mqr->logo($logo);
    $mqr->to_png("public/images/$uuid.png");
    
    if (defined($c->param('hash'))) {
            print "Hash\n";
            my $result = $ua->post('http://127.0.0.1:5001/api/v0/add' => form => {image => {file => "public/images/$uuid.png",'Content-Type' => 'application/octet-stream'}})->result->json;
            unlink "public/images/$uuid.png";
            $c->render(json => $result,status => 200);
    } else {
            print "Text\n";
            my $file = Mojo::Asset::File->new(path => "public/images/$uuid.png");
            $file = $file->slurp;
            unlink "public/images/$uuid.png";
            $c->render(data => $file,format => 'png',status => 200);
    }       
        
};


sub genqrcode64 {
    ## Generates QRCode
    ## 38mm Label needs size 3 Version 5 (default)
    ## 62mm With Text size 4 Version 5
    ## 62mm No Text size 5 60mmX60mm Version 5
    my $c = shift;
    my $text = $c->param('text');
    my $size = $c->param('s') || 3;
    my $version = $c->param('v') || 5;
    my $blank = $c->param('b') || 'no';
    if ($blank eq 'no') {
            $text = 'https://pot.ec/'.$text;
    }
    my $mqr  = Api::QRCode->new(
    text   => $text,
    qrcode => {size => $size,margin => 2,version => $version,level => 'H'}
    );
    my $logo = Imager->new(file => "public/appimages/potlogolarge.png") || die Imager->errstr;
    $mqr->logo($logo);
    $mqr->to_png_base64("public/images/test.png");

    $c->render(json => {'message' => 'Ok','image' => $mqr->to_png_base64("public/images/test.png")},status => 200);
}


sub start_urls {
    my ($ua, $queue, $cb) = @_;

    
    # Limit parallel connections to 4
    state $idle = 4;
    state $delay = Mojo::IOLoop->delay(
        sub{
            say @$queue ? "Loop ended before queue depleated" : "Finished"
        }
    );

  while ( $idle and my $url = shift @$queue ) {
    $idle--;
    
    $ua->app->log->debug("Starting $url, $idle idle");
    
    $delay->begin;

    $ua->get($url => sub{
      $idle++;
      $ua->app->log->debug("Got $url, $idle idle");
      $cb->(@_, $queue);

      # refresh worker pool
      start_urls($ua, $queue, $cb);
      $delay->wait;
    });

  }

  # Start event loop if necessary
  $delay->wait unless $delay->ioloop->is_running;
}

sub get_callback {
    my ($ua, $tx, $queue) = @_;

    # Parse only OK HTML responses

    return unless
        $tx->res->is_success;

    # Request URL
    my $url = $tx->req->url;
    say "Processing $url";
    parse_html($url, $tx, $queue);
}

sub parse_html {
    my ($url, $tx, $queue) = @_;

    print Dumper($tx);

    say '';

    return;
}


1;
