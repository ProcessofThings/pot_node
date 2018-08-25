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
use Data::Dumper;
use Config::IniFiles;

# This action will render a template

  my $ua = Mojo::UserAgent->new;
  my $redis = Mojo::Redis2->new;

sub redirect {
    my $c = shift;
    $c->redirect_to('/main.html');
};

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
