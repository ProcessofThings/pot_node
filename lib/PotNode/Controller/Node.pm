package PotNode::Controller::Node;
use Mojo::Base 'Mojolicious::Controller';
use Config::IniFiles;
use Mojo::UserAgent;
use Mojo::ByteStream 'b';
use Mojo::JSON qw(decode_json encode_json);
# This action will render a template

sub join {
    my $c = shift;
    my $ua  = Mojo::UserAgent->new;
    my $json = $c->req->json;
    
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

sub alive {
    my $c = shift;
    my $redis = Mojo::Redis2->new;
    my $address = $c->tx->remote_address;
    my $myaddress = $c->req->url->to_abs->host;
    if (!$redis->exists("pot_config")){
        $c->app->log->debug("/node/alive - Key Not Found");
        $c->render(json => {'message' => "Alive Request From $address"});
    } else {
        my $pot_config = decode_json($redis->get("pot_config"));
        my $data;
        my $address = $c->tx->remote_address;
        my $myaddress = $c->req->url->to_abs->host;
        
        $c->app->log->debug("Remote Address : $address $myaddress");
        $data->{'message'} = "Alive Request From $address";
        $data->{'address'} = "$pot_config->{'id'}".'@'."$myaddress:$pot_config->{'networkport'}"; 
        $data->{'id'} = $pot_config->{'id'};
        $c->render(json => $data);
    }
};

1;
