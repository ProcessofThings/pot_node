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
use Mojo::Util qw(b64_decode);
use Image::Scale;
use PotNode::VectorSpace;


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
	$json->{'cdata'}->{'slots'} = [$containerid];
	
	$c->publish_stream($blockChainId, $streamId, $json);
	
	my $slot;
	$slot->{'containerid'} = $containerid;
	$slot->{'cdata'}->{'title'} = "Empty";
	
	$c->create_stream($blockChainId, 'slotsh');
	
	$c->publish_stream($blockChainId, 'slotsh', $slot);
	
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
	
	
# 	$c->debug($json);
	
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
#	$streamId = 'test12314';
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);
	
	my $outData = $c->get_all_stream_item($blockChainId, $streamId);

	$c->debug('getcustomers');
 	$c->debug($outData);

	$c->render(json => $outData, status => 200);
};

sub getSubAds {
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
	
# 	$c->debug($outData);

	$c->render(json => $outData, status => 200);
};

sub getSlots {

	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	my $outData = {};
	
# 	$c->debug("GetSlots");
# 	$c->debug($json);

	foreach my $item (@{$json}) {
		$c->app->log->debug("$item");
		my $slot  = $c->get_stream_item($blockChainId, 'slotsh', $item);

		foreach ( keys%{ $slot } ){
      $outData->{ $_ } = $slot->{ $_ } ; 
		}
	}
 
 	$c->render(json => $outData, status => 200);
};

sub getSections {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	$json->{'containerid'} = "config";
	
	my $sections  = $c->get_stream_item($blockChainId, 'sections', 'config');
	
# 	$c->debug("Sections");
# 	$c->debug($sections);
	
	$c->render(json => $sections, status => 200);
};

sub updateSections {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	
	$json->{'containerid'} = "config";
# 	$c->debug($json);
	
	$c->create_stream($blockChainId, 'sections');
	
	$c->publish_stream($blockChainId, 'sections', $json);
	
	$c->render(json => {'message' => 'Ok'}, status => 200);
};

sub updateSlot {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	my $db = DBM::Deep->new( 
		file => "/home/node/search/$blockChainId-$streamId.db",
		type => DBM::Deep->TYPE_ARRAY
	);
	
	my @array = @$db;
	
	## Gets the Index of the any matching search container
	my ($index) = grep { $array[$_] =~ /$json->{'containerid'}/ }  0..$#array;
	
		my $towns = join(' ', @{$json->{'cdata'}->{'towns'}});
		$c->debug('towns');
		$c->debug($towns);
	

	## Update Existing Index position or push into array
	if (defined($index)) {
		$db->put($index, "$json->{'containerid'} $json->{'cdata'}->{'sections'} $towns");
	} else {
		push(@$db, "$json->{'containerid'} $json->{'cdata'}->{'sections'} $towns");
	}
	
	## Image Management and Image Resizing images are uploaded using javascript base64
	
	my ($dataimage,$image) = split(/,/,$json->{'cdata'}->{'image'});
	if ($dataimage =~ /^data:image/) {
		my $image = b64_decode $image;
		
		my ($containerid,undef) = $c->uuid();

		my $path = "/tmp/$containerid";
		mkdir $path;
		$c->debug($path);
		my $file = "$path/upload.jpg";
		
		## Store base64 image to file
		open my $fh, '>', $file or die $!;
		binmode $fh;
		print $fh $image;
		close $fh;
		
		## Resize images into heights
		my @sizes = (720,500,300,200,100);
		foreach my $size (@sizes) { 
			$c->debug($size);
			my $resize = "$path/$size.jpg";
			$c->debug($resize);
			my $img = Image::Scale->new($file) || die "Invalid JPEG file";
			$img->resize_gd_fixed_point( { height => $size, keep_aspect => 1 } );
			$img->save_jpeg($resize);
		}
		
		## Save Images to IPFS network
		my $command = "ipfs add -r -Q $path";
		my $value = qx/$command/;
		$value =~ s/\R//g;
			
		$c->debug($value);
		
		$json->{'cdata'}->{'image'} = "./ipfs/$value";
		
		## clean up folder remove temp files
		my $command = "rm -rf $path";
		qx/$command/;
	}
	
	my ($logoimage,$image) = split(/,/,$json->{'cdata'}->{'logo'});
	if ($logoimage =~ /^data:image/) {
		my $image = b64_decode $image;
		
		my ($containerid,undef) = $c->uuid();
		

		my $path = "/tmp/$containerid";
		mkdir $path;
		my $file = "$path/logo.jpg";
		
		## Store base64 image to file
		open my $fh, '>', $file or die $!;
		binmode $fh;
		print $fh $image;
		close $fh;
		
		## Resize images into heights
		my @sizes = (175,150,125,100);
		foreach my $size (@sizes) { 
			$c->debug($size);
			my $resize = "$path/$size.jpg";
			$c->debug($resize);
			my $img = Image::Scale->new($file) || die "Invalid JPEG file";
			$img->resize_gd_fixed_point( { height => $size, keep_aspect => 1 } );
			$img->save_jpeg($resize);
		}
		
		
		## Save Images to IPFS network
		my $command = "ipfs add -r -Q $path";
		my $value = qx/$command/;
		$value =~ s/\R//g;

		$json->{'cdata'}->{'logo'} = "./ipfs/$value";
		
		## clean up folder remove temp files
		my $command = "rm -rf $path";
		qx/$command/;
	}
	
	$c->create_stream($blockChainId, 'subad');
	
	if ($json->{'attribs'}->{'sub'}) {
		$c->publish_stream($blockChainId, 'subad', $json);
	} else {
		$c->delete_stream_item($blockChainId, 'subad', $json);
	}
	
	$c->create_stream($blockChainId, 'slotsh');
	
 	$c->publish_stream($blockChainId, 'slotsh', $json);

	$c->render(json => {'message' => 'Ok'}, status => 200);
};

sub createSlot {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, "custh");
	
	my $container = $c->get_stream_item($blockChainId, "custh", $json->{'containerid'});
	
	my ($containerid,undef) = $c->uuid();
	
# 	$c->debug("Get Container");
# 	$c->debug($container);
	
	## update container
	push(@{$container->{$json->{'containerid'}}->{'cdata'}->{'slots'}}, $containerid);
	
# 	$c->debug($container);
	
	my $slots = $container->{$json->{'containerid'}}->{'cdata'}->{'slots'};
	
# 	$c->debug("slots");
# 	$c->debug($slots);
	
	$c->publish_stream($blockChainId, 'custh', $container->{$json->{'containerid'}});

	## build slot
	my $slot;
	$slot->{'containerid'} = $containerid;
	$slot->{'cdata'}->{'title'} = "Empty";
	
	$c->create_stream($blockChainId, 'slotsh');
	
# 	$c->debug($slot);
	$c->publish_stream($blockChainId, 'slotsh', $slot);

	$c->render(json => $slots, status => 200);
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
	
# 	$c->debug($container);
#	$c->publish_stream($blockChainId, $streamId, $container);
	$c->render(text => "Ok", status => 200);
};

sub buildSearch {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	
 	my $db = DBM::Deep->new( 
 		file => "/home/node/search/$blockChainId-$streamId.db",
 		type => DBM::Deep->TYPE_ARRAY
 	);
	
	my $processData = $c->get_all_stream_item($blockChainId, $streamId);
	
	delete $processData->{'count'};
	
	$c->debug($processData);
	
	foreach my $key (keys %{$processData}) {
#		if (defined($ads->))
		$c->debug("Build Search");
		if (defined($processData->{$key}->{'cdata'}->{'towns'})) {
			my $json = $processData->{$key};
			my @array = @$db;
			
			## Gets the Index of the any matching search container
			my ($index) = grep { $array[$_] =~ /$json->{'containerid'}/ }  0..$#array;
			
			my $towns = join(' ', @{$json->{'cdata'}->{'towns'}});
			
			## Update Existing Index position or push into array
			if (defined($index)) {
				$db->put($index, "$json->{'containerid'} $json->{'cdata'}->{'sections'} $towns");
			} else {
				push(@$db, "$json->{'containerid'}  $json->{'cdata'}->{'sections'} $towns");
			}			
		}
	}
	$c->render(text => "Ok", status => 200);
};

sub search {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	my $db = DBM::Deep->new( 
		file => "/home/node/search/$blockChainId-$streamId.db",
		type => DBM::Deep->TYPE_ARRAY
	);
	my $outData;
	my @docs = @$db;
	my $engine = PotNode::VectorSpace->new( docs => \@docs, threshold => 0.20);
# 	my $search = $json->{'search'};
	my $search = "$json->{'search'}->{'section'} $json->{'search'}->{'town'}";
	
	$engine->build_index();
	
#	$c->debug($json);
	$c->debug("Search Query");
	$c->debug($search);
	$c->debug(@docs);
	my (@searchindex) = grep(/$search/, @docs);
	
 	my $searchresults;
 	while ( my $query = $search ) {
 		my %results = $engine->search( $query );
 		foreach my $result ( sort { $results{$b} <=> $results{$a} } keys %results ) {
 			my $resultlist;		
 			$resultlist->{'relevance'} = $results{$result};
 			$resultlist->{'containerid'} = substr($result, 0, 36);
 			my $slot  = $c->get_stream_item($blockChainId, 'slotsh', $resultlist->{'containerid'});
 			$slot->{$resultlist->{'containerid'}}->{'relevance'} = $results{$result};
 			push(@{$searchresults}, $slot);
 		}
 		last;
 	}
    
	$c->debug($searchresults);
	
	$c->render(json => $searchresults, status => 200);	
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
