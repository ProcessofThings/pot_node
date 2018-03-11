package PotNode::Controller::Node;
use Mojo::Base 'Mojolicious::Controller';

# This action will render a template

sub join {
    use Mojo::UserAgent;
    use Mojo::ByteStream 'b';
    
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
    my $address = $c->tx->remote_address;
    $c->app->log->debug("Remote Address : $address");
    $c->render(json => {'message' => "Alive Request From $address"});
};

1;
