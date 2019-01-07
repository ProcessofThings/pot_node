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
use Mojo::Util qw(b64_decode b64_encode);
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
    $c->mailchimp_subscribe($container);
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
      $c->mailchimp_subscribe($container);
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

sub userExists {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
  my $outData;
  my $message;

  $c->debug("userExists");

	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	my ($containerid,undef) = $c->uuid();


	## build container
	$container->{'containerid'} = $containerid;
	$container->{'cdata'} = $hash;

	my @array;
	push(@array, "CID$containerid");
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
	my $index = join(' ', @array);
	$c->debug("Index : $index");
	my $file = "/home/node/search/$streamId.txt";
	if (not -e $file) {
		$c->debug("File Not found adding Index");
	} else {
		$c->debug("Search");
		my $userName = Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'});
		$c->debug("$userName");
		my @matches = fgrep { /$userName/ } $file;
		$c->debug(@matches[0]);
		$c->debug(@matches[0]->{'count'});
		if (@matches[0]->{'count'} < 1) {
			$c->debug("Search Entry Not Found");
      $c->render(openapi => {message => 'not_found'});
		} else {
      $c->debug("Search Found");
      $c->debug(@matches[0]->{'matches'});
      my $search = @matches[0]->{'matches'};
      $c->debug($search);
      foreach my $key (keys %{$search}) {
        my $result = @matches[0]->{'matches'}->{$key};
        ($result) = split(/ /, $result);
        $result = substr($result, 3);
        my $userInfo  = $c->get_stream_item($blockChainId, 'profiles', $result);
		    foreach ( keys%{ $userInfo } ){
          $outData->{ $_ } = $userInfo->{ $_ } ;
		    }
        $c->debug($outData);
        if (!defined($outData->{$result}->{cdata}->{userPassword})) {
          $message = 'setup';
        } else {
          $message = 'user_found';
          if (defined($outData->{$result}->{cdata}->{userResetId})) {
            if ($outData->{$result}->{cdata}->{userResetId} eq $container->{cdata}->{userResetId}) {
              $message = 'reset_password';
            }
          }
        }
      }
      $c->render(openapi => {message => $message});
		}
	}
};

sub updatePassword {
  my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
  my $outData;
  my $message;
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	my ($containerid,undef) = $c->uuid();


	## build container
	$container->{'containerid'} = $containerid;
	$container->{'cdata'} = $hash;

  $c->debug($container);

	my @array;
	push(@array, "CID$containerid");
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
	my $index = join(' ', @array);
	my $file = "/home/node/search/$streamId.txt";
	if (not -e $file) {
		$c->debug("File Not found adding Index");
	} else {
		my $userName = Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'});
		my @matches = fgrep { /$userName/ } $file;
		if (@matches[0]->{'count'} < 1) {
			$c->debug("Search Entry Not Found");
      $c->render(openapi => {message => 'not_found'});
		} else {
      my $search = @matches[0]->{'matches'};
      foreach my $key (keys %{$search}) {
        my $result = @matches[0]->{'matches'}->{$key};
        ($result) = split(/ /, $result);
        $result = substr($result, 3);
        my $userInfo  = $c->get_stream_item($blockChainId, 'profiles', $result);
		    foreach ( keys%{ $userInfo } ){
          $outData->{ $_ } = $userInfo->{ $_ } ;
		    }
        if (!defined($outData->{$result}->{cdata}->{userPassword})) {
          $c->debug("Password Found");
          $outData->{$result}->{cdata}->{userPassword} = $container->{cdata}->{userPassword};
          $container->{containerid} =  $outData->{$result}->{containerid};
          $container->{cdata} = $outData->{$result}->{cdata};
          $c->publish_stream($blockChainId, $streamId, $container);
          $message = 'password_changed';
        } else {
          $message = 'user_found';
          if (defined($outData->{$result}->{cdata}->{userResetId})) {
            $c->debug("userResetId Found");
            if ($outData->{$result}->{cdata}->{userResetId} eq $container->{cdata}->{userResetId}) {
              $c->debug("userResetId Match");
              $outData->{$result}->{cdata}->{userPassword} = $container->{cdata}->{userPassword};
              $container->{containerid} =  $outData->{$result}->{containerid};
              delete $outData->{$result}->{cdata}->{userResetId};
              $container->{cdata} = $outData->{$result}->{cdata};
              $c->debug($container);
              $c->publish_stream($blockChainId, $streamId, $container);
              $message = 'password_reset';
            } else {
              $c->debug("userResetId No Match");
              $message = 'invalid_reset_id';
            }
          }
        }
      }
      $c->render(openapi => {message => $message});
		}
	}
};

sub resetPassword {
  use Email::Send::SMTP::Gmail;

  my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
  my $outData;
  my $message;
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	my ($containerid,undef) = $c->uuid();


	## build container
	$container->{'containerid'} = $containerid;
	$container->{'cdata'} = $hash;
  $container->{cdata}->{userResetId} = Encode::Base58::GMP::md5_base58($containerid);

	my @array;
	push(@array, "CID$containerid");
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
	my $index = join(' ', @array);
	my $file = "/home/node/search/$streamId.txt";
	if (not -e $file) {
		$c->debug("File Not found adding Index");
	} else {
		my $userName = Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'});
		my @matches = fgrep { /$userName/ } $file;
		if (@matches[0]->{'count'} < 1) {
			$c->debug("Search Entry Not Found");
      $c->render(openapi => {message => 'not_found'});
		} else {
      my $search = @matches[0]->{'matches'};
      foreach my $key (keys %{$search}) {
        my $result = @matches[0]->{'matches'}->{$key};
        ($result) = split(/ /, $result);
        $result = substr($result, 3);
        my $userInfo  = $c->get_stream_item($blockChainId, 'profiles', $result);
		    foreach ( keys%{ $userInfo } ){
          $outData->{ $_ } = $userInfo->{ $_ } ;
		    }
        if (defined($outData->{$result}->{cdata}->{userPassword})) {
          $outData->{$result}->{cdata}->{userResetId} = $container->{cdata}->{userResetId};
          $container->{containerid} =  $outData->{$result}->{containerid};
          $container->{cdata} = $outData->{$result}->{cdata};
          $c->publish_stream($blockChainId, $streamId, $container);
          # Send Email to request password change
          $c->debug($container);
          $c->debug("Sending Email");
          my $email = -1;
          my ($mail,$error)=Email::Send::SMTP::Gmail->new(-layer=>'ssl',
                                                -port=>'465',
                                                -smtp=>'smtp.gmail.com',
                                                 -login=>'craig.harper@chainsolutions.net',
                                                 -pass=>'3Hsch8278+');
          $mail->send(-to=>$container->{cdata}->{userName}, -subject=>'Password Reset', -body=>"Please click on the following link to reset your password<br>https://pinkpagesonline.co.uk/login.html?reset=$container->{cdata}->{userName}&id=$container->{cdata}->{userResetId}");
          $mail->bye;



          $c->debug($container->{cdata}->{userResetId});
          $message = 'email_sent';
        }
      }
      $c->render(openapi => {message => $message});
		}
	}
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
  my $outData;
  my $message;
  my $session;
	
  my ($session_key,undef) = $c->uuid();
  $session_key = Encode::Base58::GMP::md5_base58($session_key);
  $container->{'cdata'} = $hash;
		$container->{cdata}->{userName} = Encode::Base58::GMP::md5_base58($hash->{'userName'});

 	$c->debug($container->{cdata}->{userName});
	
	my @matches = fgrep { /$container->{cdata}->{userName}/ } $file;
	$c->debug(@matches[0]);
	if (@matches[0]->{'count'} < 1) {
		$c->debug("Search Entry Not Found");
		$c->render(json => {'error' => "Username and Password did not match"}, status => 404);
	} else {
    my $search = @matches[0]->{'matches'};
      foreach my $key (keys %{$search}) {
        my $result = @matches[0]->{'matches'}->{$key};
        ($result) = split(/ /, $result);
        $result = substr($result, 3);
        my $userInfo = $c->get_stream_item($blockChainId, 'profiles', $result);
        foreach (keys %{$userInfo}) {
          $outData->{ $_ } = $userInfo->{ $_ };
        }
        $c->debug($container->{cdata}->{userPassword});
        $c->debug($outData->{$result}->{cdata}->{userPassword});
        if ($outData->{$result}->{cdata}->{userPassword} eq $container->{cdata}->{userPassword}) {
          if ($redis->exists("session_userid_".$result)) {
            $c->debug("Delete Old Session");
            my $old_session = $redis->get("session_userid_".$result);
            $redis->del('session_'.$old_session);
          }
          $session->{session_key} = $session_key;
          $session->{user_id} = $result;
          $session->{cdata} = $outData->{$result}->{cdata};
          $c->debug("Create New Session");
          $redis->setex('session_'.$session_key,1800, encode_json($session));
          $redis->setex('session_userid_'.$result,1800, $session_key);
          $message = {'message' => 'success','sessionKey' => $session_key, 'status' => 200};
        } else {
          $message = {'message' => 'Problem with Username or Password', 'status' => 400};
        }
      }
    $c->render(openapi => { 'res' => $message }, status => $message->{status});
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
  my $json = $c->req->json;
  my $headers = $c->req->headers;
	my $container;
  my $deleted = 1;
	my $method = $spec->{'x-mojo-function'};
  $c->debug('Get Customers Start');
  $c->debug($c->req->headers->header('X-Url'));
  $c->debug($hash);
  $c->debug($json);
  my $host = $c->req->url->to_abs->host;
  $c->debug($host);

  #if ($redis->exists('session_'.$hash->{sessionKey})) {
  #  my $admin_id = $redis->get('session_'.$hash->{sessionKey});
  #  if (!$redis->exists())
  #}

#	$streamId = 'test12314';
	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);
	
	my $outData = $c->get_all_stream_item($blockChainId, $streamId,-1,$deleted);

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
	my $threshold;
	my $records = @docs;
  my $search;
  my %filter;
	my (@searchindex) = grep(/$json->{'search'}->{'section'}/, @docs);
	my $sectioncount = @searchindex;
	(@searchindex) = grep(/$json->{'search'}->{'town'}/, @docs);
	my $locationcount = @searchindex;
	%filter = ('and' => '1', 'cleaners'=> '1');
	$c->debug("Total Records : $records with $sectioncount Section Count and $locationcount");
	
	if ($locationcount < 1) { $threshold = 0.25};
	if ($locationcount > 1) { $threshold = $sectioncount/$locationcount*0.05};
	
	$c->debug("Threshold is $threshold");

	my $engine = PotNode::VectorSpace->new( docs => \@docs, threshold => int($threshold), filter => \%filter);
# 	my $search = $json->{'search'};
  if (defined($json->{'search'}->{'town'})) {
    $c->debug("Search No Town");
    $search = "$json->{'search'}->{'section'}";
  } else {
    $c->debug("Search With Town");
    $search = "$json->{'search'}->{'section'} $json->{'search'}->{'town'}";
  }
	
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

sub cleandata {
  my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
  my $customerData;
  my $slotData;
	my $method = $spec->{'x-mojo-function'};

  ## Get all customers and check if they have been deleted and remove any related slots
  my $customerData = $c->get_all_stream_item($blockChainId, $streamId);


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

sub localstore_post {

  my ($self) = @_;
  my $c = shift;
  my $block_chain_id = $c->param('blockChainId');
  my $container;
  my $ipfs_hash = '';
  my $json = $c->req->json;
#  my $config = $ua->get('http://127.0.0.1:8080/ipfs/'.$ipfsHash.'/config.json')->result->body;
#  if ($config =~ /\n$/) { chop $config; };
#  $config = decode_json($config);
  my $tempjson = '{"localstore": {"storename": "mailchimp","encode" : [],"index":"userId"}}';
  my $config = decode_json($tempjson);
  my ($containerid,undef) = $c->uuid();
  my @array;
  my $index;
  my $path = "/home/node/search/$block_chain_id";
  my $file;
  my $filename;
  my $method;
  my $sub_name = (caller(0))[3];
  $sub_name = (split '::', $sub_name)[-1];
  ($sub_name,$method) = (split '_', $sub_name);

  #Path does not exist create it
  if (not -d $path) {
    mkdir $path;
  }

  #Generate Container
  $container->{'containerid'} = $containerid;
	$container->{'cdata'} = $json;

  #run encoding from config (encoding insures that private data is encrypted)
  #ideally encryption should be done on the client before passing important information

  #TODO: search config file for the encode array of variables against
  # contents of the cdata->hash

  #Build Array for local storage
  #Array first element must be the containerid
  push(@array, "CID$containerid");
  push(@array, "$container->{'cdata'}->{$config->{$sub_name}->{'index'}}");
  #convert array to flat index string
  $index = join(' ', @array);

  $filename = $config->{$sub_name}->{'storename'};
  $file = "$path/$filename.txt";

  if (not -e $file) {
    open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
			say $fh $index;
		close $fh;
  } else {
    my @matches = fgrep { /$container->{'cdata'}->{$config->{$sub_name}->{'index'}}/ } $file;
    if (@matches[0]->{'count'} < 1) {
      open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
				say $fh $index;
			close $fh;
      $c->render(openapi => {message => 'not_found', info => "The requested $config->{$sub_name}->{'index'} with data $container->{'cdata'}->{$config->{$sub_name}->{'index'}} was not found."});
    } else {
      $c->render(openapi => {message => 'found'});
    }
  }
};

sub localstore_get {

  my ($self) = @_;
  my $c = shift;
  my $block_chain_id = $c->param('blockChainId');
  my $container;
  my $ipfs_hash = '';
  my $hash = $c->req->params->to_hash;
  my $json = $c->req->json;
  my $tempjson = '{"localstore": {"storename": "mailchimp","encode" : [],"index": "userId"}}';
  my $config = decode_json($tempjson);
  my ($containerid,undef) = $c->uuid();
  my $path = "/home/node/search/$block_chain_id";
  my $file;
  my $filename;
  my $method;
  my $sub_name = (caller(0))[3];
  $sub_name = (split '::', $sub_name)[-1];
  ($sub_name,$method) = (split '_', $sub_name);

  #Path does not exist create it
  if (not -d $path) {
    mkdir $path;
    $c->render(openapi => {error => 'no_data_created', info => 'Has not been used yet or the database does not exist it will be automatically created when you use it'});
  }

  #Generate Container
  $container->{'containerid'} = $containerid;
	$container->{'cdata'} = $hash;

  #run encoding from config (encoding insures that private data is encrypted)
  #ideally encryption should be done on the client before passing important information

  #TODO: search config file for the encode array of variables against
  # contents of the cdata->hash

  $filename = $config->{$sub_name}->{'storename'};
  $file = "$path/$filename.txt";

  if (not -e $file) {
    $c->render(openapi => {error => 'no_data_created', info => 'Has not been used yet or the database does not exist it will be automatically created when you use it'});
  } else {
    my @matches = fgrep { /$container->{'cdata'}->{$config->{$sub_name}->{'index'}}/ } $file;
    if (@matches[0]->{'count'} < 1) {
      $c->render(openapi => {message => 'not_found', info => "The requested $config->{$sub_name}->{'index'} with data $container->{'cdata'}->{$config->{$sub_name}->{'index'}} was not found."});
    } else {
      $c->render(openapi => {message => 'found'});
    }
  }
};

1;
