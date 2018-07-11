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


    $app->helper(uuid => \&_uuid);
    $app->helper(mergeHTML => \&_mergeHTML);
    $app->helper(cache_control.no_caching => \&_cache_control_none);
    $app->helper(get_rpc_config => \&_get_rpc_config);
    $app->helper(get_blockchains => \&_get_blockchains);
    $app->helper(load_blockchain_config => \&_load_blockchain_config);
    $app->helper(genqrcode64 => \&_genqrcode64);


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
    my $size = 10;
    my $version = 1;
    my $blank = 'yes';
    my $data;
    if ($blank eq 'no') {
            $text = 'https://pot.ec/'.$text;
    }
    my $mqr  = PotNode::QRCode->new(
    text   => $text,
    qrcode => {size => $size,margin => 2,version => $version,level => 'H'}
    );
    my $logo = Imager->new(file => "/home/node/pot_node/public/images/potlogoqrtag.png") || die Imager->errstr;
    # $mqr->logo($logo);
    $mqr->to_png_base64("/home/node/tmp/test.png");
	 $data->{'image'} = $mqr->to_png_base64("/home/node/tmp/test.png");
    return $data;
};

1;
