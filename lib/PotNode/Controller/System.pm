package PotNode::Controller::System;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::QRCode;

# This action will render a template

sub start {
    use Mojo::UserAgent;
    use Mojo::ByteStream 'b';
    
    my $c = shift;
    my $ua  = Mojo::UserAgent->new;
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

sub upload {
    use Mojo::UserAgent;
    use Mojo::ByteStream 'b';

    my $c = shift;
    my $ua  = Mojo::UserAgent->new;
#       my $html = $ua->get('http://127.0.0.1:8080/ipfs/QmfQMb2jjboKYkk5f1DhmGXyxcwNtnFJzvj92WxLJjJjcS')->res->dom->find('section')->first;
        my $html = $ua->get('http://127.0.0.1:8080/ipfs/Qmbb28sUkFdGz3YxquVkXbE2CrWBFBceJyKYa1ms1W48do')->res->body;
        #b('foobarbaz')->b64_encode('')->say;
        my $encodedfile = b($html);
        $c->app->log->debug("Encoded File : $encodedfile");
    $c->stash(import_ref => $encodedfile);

    $c->render(template => 'system/start');
};


sub genqrcode {
    ## Generates QRCode
    ## 38mm Label needs size 3 Version 5 (default)
    ## 62mm With Text size 4 Version 5
    ## 62mm No Text size 5 60mmX60mm Version 5
    my $c = shift;
    my $ua  = Mojo::UserAgent->new;
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
    my $c = shift;
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

1;
