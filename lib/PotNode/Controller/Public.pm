package PotNode::Controller::Public;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::QRCode;
use Mojo::URL;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Data::UUID;
use PotNode::Encryption::Helpers;
use Data::Dumper;
use PotNode::Multichain;
use Config::IniFiles;
use DBM::Deep;
use Devel::Size qw(total_size);
use Encode::Base58::GMP;
use File::Grep qw/ fgrep /;


# This action will render a template
  my $ua = Mojo::UserAgent->new;
  my $redis = Mojo::Redis2->new;
  
  

sub redirect {
    my $c = shift;
    $c->redirect_to('/main.html');
};


sub test {
	my $c = shift;
	$c->debug($c->req);
	$c->render(text => "ok", status => 200);
}
sub load {
    my $c = shift;
    my $id = $c->req->param('ipfs');
    my $myaddress = $c->req->url->to_abs->host;
    my $base = "http://127.0.0.1:8080/ipfs/$id";
    $c->plugin('Mojolicious::Plugin::ReverseProxy',{
        # mandatory
        destination_url => $base,
        # optional#
        mount_point => '/', # default
        req_processor   => sub {
            my $ctrl = shift;
            my $req  = shift;
            my $opt  = shift;
            $ctrl->render(text => $req->url->to_string);
        },
    });
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
    $ua->get($base => sub {
        my ($ua, $tx) = @_;
#        $c->debug($tx);
        my $content = $tx->res->headers->content_type;
        $c->debug($content);
        my $file = $tx->res->body;
        
        $c->render(data => $file, format => $content);
    });
};


sub authUser {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $jsonParams = $c->req->json;
	my $blockChainId = $c->param('blockchainId');
	my $hash = $c->req->params->to_hash;
	my $input = $c->validation->output;
	$c->debug($blockChainId);
	$c->render(text => "Ok", status => 200);
};

sub registerUser {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	my ($containerid,undef) = $c->uuid();
	

	## build container
	$container->{'containerid'} = $containerid;
	$container->{'cdata'} = $hash;
	
	my @array;
	push(@array, "CID$containerid");
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userEmail'}));
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
	my $index = join(' ', @array);
	$c->debug("Index : $index");
	my $file = "/home/node/search/$streamId.txt";
	if (not -e $file) {
		$c->debug("File Not found adding Index");
		open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
			say $fh $index;
		close $fh;
		$c->debug("Publish to Stream");
		$c->publish_stream($blockChainId, $streamId, $container);
	} else {
		$c->debug("Search");
		my $userName = Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'});
		my $userEmail = Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userEmail'});
		$c->debug("$userName");
		my @matches = fgrep { /$userName/ } $file;
		$c->debug(@matches[0]);
		$c->debug(@matches[0]->{'count'});
		if (@matches[0]->{'count'} < 1) {
			$c->debug("Search Entry Not Found");
			$c->publish_stream($blockChainId, $streamId, $container);
			open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
				say $fh $index;
			close $fh;
		} else {
			$c->render(text => "User Exists", status => 400);
		}
	}
$c->render(text => "Ok", status => 200);
};

sub loginUser {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	my $file = "/home/node/search/$streamId.txt";
	my $sessionid;
	
	$c->debug($hash);
	
	my $userName = Encode::Base58::GMP::md5_base58($hash->{'userName'});
	my ($sessionid,undef) = $c->uuid();
	$sessionid = Encode::Base58::GMP::md5_base58($sessionid);
	
	$c->debug($userName);
	
	my @matches = fgrep { /$userName/ } $file;
	$c->debug(@matches[0]);
	if (@matches[0]->{'count'} < 1) {
		$c->debug("Search Entry Not Found");
		$c->render(json => {'error' => "Username and Password did not match"}, status => 404);
	} else {
		$c->render(json => {'sessionid' => $sessionid}, status => 200);
	}
	#$c->render(text => "Ok", status => 200);
};


sub createCustomer {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $json = $c->req->json;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	my ($containerid,undef) = $c->uuid();

	## build container
	
	$json->{'containerid'} = $containerid;
	$json->{'cdata'}->{'slots'}->{$containerid} = {'title' => "Empty"};
	
	$c->publish_stream($blockChainId, $streamId, $json);
	$c->render(text => "Ok", status => 200);
};

sub updateCustomer {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $json = $c->req->json;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	
	$c->debug($json);
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	$c->publish_stream($blockChainId, $streamId, $json);
	$c->render(text => "Ok", status => 200);
};


sub deleteCustomer {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	## build container
	$container->{'containerid'} = $hash->{'containerid'};

	$c->delete_stream_item($blockChainId, $streamId, $container);
	$c->render(text => "Ok", status => 200);
};


sub getCustomers {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);
	
	my $outData = $c->get_all_stream_item($blockChainId, $streamId);
	
	$c->debug($outData);

	$c->render(json => $outData, status => 200);
};

sub createSlot {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);
	
	my ($containerid,undef) = $c->uuid();

	## build container
	my $container = $c->get_stream_item($blockChainId, $streamId, $hash->{'containerId'});
	$container->{'slots'}->{$containerid}->{'title'} = 'Empty';

	$c->debug($container);
#	$c->publish_stream($blockChainId, $streamId, $container);
	$c->render(text => "Ok", status => 200);
};

sub deleteSlot {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);
	
	## build container
	my $container = $c->get_stream_item($blockChainId, $streamId, $hash->{'containerId'});
	delete $container->{'slots'}->{$hash->{'slotId'}};
	
	$c->debug($container);
#	$c->publish_stream($blockChainId, $streamId, $container);
	$c->render(text => "Ok", status => 200);
};


sub api {
    my $c = shift;
    $c->res->headers->header('Access-Control-Allow-Origin' => '*');
    $c->res->headers->header('Access-Control-Allow-Credentials' => 'true');
    $c->res->headers->header('Pragma' => 'no-cache');
    $c->res->headers->header('Cache-Control' => 'no-cache');
    my $data = decode_json($redis->get('index'));
    $c->render(json => $data);
};
  
1;
