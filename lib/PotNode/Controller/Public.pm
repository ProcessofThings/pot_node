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
  my $create_user = 'no';
  my $message;
  my $package_attribs;



  $c->debug("register user");
  $c->debug($hash);

	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);

	my ($containerid,undef) = $c->uuid();
  my ($groupid,undef) = $c->uuid();
	

	## build container
	$container->{'containerid'} = $containerid;
	$container->{'cdata'} = $hash;
  $container->{'cdata'}->{'groupid'} = $groupid;

  # Normalise Website
  if (lc($container->{'cdata'}->{'website'}) !~ /^http/) {
    $container->{'cdata'}->{'website'} = 'http://'.$container->{'cdata'}->{'website'};
  }

  #Remove package as this is only required for the slot, additional slots and packages will be created manually

  ## Setup Packages Attributes
  $package_attribs = {'package' => 'Starter', 'ad' => \1, 'pos3' => \0, 'banner' => \0, 'sub' => \0} if ($hash->{'package'} =~ /^starter/);
  $package_attribs = {'package' => 'Premier', 'ad' => \1, 'pos3' => \1, 'banner' => \0, 'sub' => \0} if ($hash->{'package'} =~ /^premier/);
  $package_attribs = {'package' => 'Gold', 'ad' => \1, 'pos3' => \1, 'banner' => \1, 'sub' => \0} if ($hash->{'package'} =~ /^gold/);
  $package_attribs = {'package' => 'Platinum', 'ad' => \1, 'pos3' => \1, 'banner' => \1, 'sub' => \1} if ($hash->{'package'} =~ /^platinum/);

  $c->debug($package_attribs);

	my @array;
	push(@array, "CID$containerid");
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userEmail'}));
	push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
	my $index = join(' ', @array);
	$c->debug("Index : $index");
	my $file = "/home/node/search/$streamId.txt";
	if (not -e $file) {
		$c->debug("File Not found adding Index");
    $create_user = 'yes';
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
      $create_user = 'yes';
		} else {
      $message = {'message' => 'Problem with Email Address or Password', 'status' => 400};
			$c->render(text => "User Exists", status => 400);
		}
	}
  if ($create_user eq 'yes') {
    $c->debug("Create New User");
    ## Subscribe to MailChimp
    $c->mailchimp_subscribe($container);
    ## Create Profile
    $c->publish_stream($blockChainId, $streamId, $container);
    ## Create Company Profile
    my $customer;
    $customer->{'containerid'} = $containerid;
    $customer->{'groupid'} = $groupid;
    $customer->{'cdata'}->{'companyName'} = $container->{'cdata'}->{'companyName'};
    $customer->{'cdata'}->{'companyWebsite'} = $container->{'cdata'}->{'website'};
    ## Link Default Slot to Company Profile
    $customer->{'cdata'}->{'slots'} = [$containerid];
    $c->publish_stream($blockChainId, 'custh', $customer);
    ## Create Default Slot
    my $slot;
    $slot->{'containerid'} = $containerid;
    $slot->{'cdata'}->{'title'} = $container->{'cdata'}->{'companyName'};
    $slot->{'attribs'} = $package_attribs;

    $c->create_stream($blockChainId, 'slotsh');
    $c->publish_stream($blockChainId, 'slotsh', $slot);
    #Setup Social Marketing Information If Ordered
    $c->debug('Check Social');
    if ($hash->{'package'} =~ /social$/) {
      $c->debug('Save Social');
      $c->create_stream($blockChainId, 'socialh');
      $c->publish_stream($blockChainId, 'socialh', $container);
    }

    ## Create User Index
    open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
      say $fh $index;
    close $fh;
    $message = {'message' => 'user_created', 'status' => 200};

  }
  $c->render(openapi => { 'res' => $message }, status => $message->{status});
};

sub setupUser {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $container = $c->req->json;
  my $create_user = 'no';
  my $message;
  my $package_attribs;
  my $session_key;

  $c->debug("setup user");
  $c->debug($container);

  $session_key = $container->{'config'}->{'sessionKey'};
  delete $container->{'config'};

  if (!defined($container->{'cdata'}->{'groupid'})) {
    $container->{'cdata'}->{'groupid'} =  $container->{'containerid'};
  }

  # Normalise Website
  if (lc($container->{'cdata'}->{'website'}) !~ /^http/) {
    $container->{'cdata'}->{'website'} = 'http://'.$container->{'cdata'}->{'website'};
  }
  $c->debug("Normalise Website");
  $c->debug($container);
  #Remove package as this is only required for the slot, additional slots and packages will be created manually

  ## Setup Packages Attributes
  $package_attribs = {'package' => 'Starter', 'ad' => \1, 'pos3' => \0, 'banner' => \0, 'sub' => \0} if ($container->{'cdata'}->{'package'} =~ /^starter/);
  $package_attribs = {'package' => 'Premier', 'ad' => \1, 'pos3' => \1, 'banner' => \0, 'sub' => \0} if ($container->{'cdata'}->{'package'} =~ /^premier/);
  $package_attribs = {'package' => 'Gold', 'ad' => \1, 'pos3' => \1, 'banner' => \1, 'sub' => \0} if ($container->{'cdata'}->{'package'} =~ /^gold/);
  $package_attribs = {'package' => 'Platinum', 'ad' => \1, 'pos3' => \1, 'banner' => \1, 'sub' => \1} if ($container->{'cdata'}->{'package'} =~ /^platinum/);

  $c->debug($package_attribs);

  $c->debug("Create Company");

  my $customer;
  $customer->{'containerid'} = $container->{'containerid'};
  $customer->{'groupid'} = $container->{'cdata'}->{'groupid'};
  $customer->{'cdata'}->{'companyName'} = $container->{'cdata'}->{'companyName'};
  $customer->{'cdata'}->{'companyWebsite'} = $container->{'cdata'}->{'website'};
  ## Link Default Slot to Company Profile
  $customer->{'cdata'}->{'slots'} = [$container->{'containerid'}];
  $c->debug($customer);

  $c->publish_stream($blockChainId, 'custh', $customer);
  ## Create Default Slot
  $c->debug("Create Slot");
  my $slot;
  $slot->{'containerid'} = $container->{'containerid'};
  $slot->{'groupid'} = $container->{'cdata'}->{'groupid'};
  $slot->{'cdata'}->{'title'} = $container->{'cdata'}->{'companyName'};
  $slot->{'attribs'} = $package_attribs;
  $c->debug($slot);
  $c->create_stream($blockChainId, 'slotsh');
  $c->publish_stream($blockChainId, 'slotsh', $slot);
  #Setup Social Marketing Information If Ordered
  $c->debug('Check Social');
  if ($container->{'cdata'}->{'package'} =~ /social$/) {
    $c->debug('Save Social');
    $c->create_stream($blockChainId, 'socialh');
    $c->publish_stream($blockChainId, 'socialh', $container);
  }
  ## Create User Index
  $message = {'message' => 'customer_created', 'status' => 200};

  $c->render(openapi => { 'res' => $message }, status => $message->{status});
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
		$c->debug("$userName $file");
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
          my $gmail_config;
          $gmail_config->{login} = 'some@emailaddress';
          $gmail_config->{password} = 'password';
          $gmail_config = encode_json($gmail_config);
          my $requrl = $c->req->headers->header('X-Url');
          $c->debug($requrl);
          if (!$redis->exists('gmail')) {
            $redis->set('gmail', $gmail_config);
          } else {
            $gmail_config = decode_json($redis->get('gmail'));
          }
          $c->debug($requrl);
          if ($requrl !~ /pinkpagesonline.co.uk$/) {
            $c->debug('Diverting Email to sendTo');
            $container->{cdata}->{userName} = $gmail_config->{'sendTo'};
          }
          my $email = -1;
          my ($mail,$error)=Email::Send::SMTP::Gmail->new(-layer=>'ssl',
                                                -port=>'465',
                                                -smtp=>'smtp.gmail.com',
                                                 -login=>$gmail_config->{login},
                                                 -pass=>$gmail_config->{password});
          $mail->send(-to=>$container->{cdata}->{userName}, -subject=>'Password Reset', -body=>'Please click on the following link to reset your password<br><br><a href="https://pinkpagesonline.co.uk/login.html?reset='.$container->{cdata}->{userName}.'&id='.$container->{cdata}->{userResetId}.'">Reset Password</a>',-contenttype=>'text/html');
          $mail->bye;



          $c->debug($container->{cdata}->{userResetId});
          $message = 'email_sent';
        } else {
          $message = 'initial_password not setup';
        }

      }
      $c->render(openapi => {message => $message});
		}
	}
};

sub sendContact {
  use Email::Send::SMTP::Gmail;

  my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
  my $message;
	## Move to Registration User Module when building the dapp

  $c->debug("Sending Email");
  my $gmail_config;
  $gmail_config->{login} = 'some@emailaddress';
  $gmail_config->{password} = 'password';
  $gmail_config->{sendTo} = 'some@emailaddress';
  $gmail_config = encode_json($gmail_config);
  my $requrl = $c->req->headers->header('X-Url');
  $c->debug($requrl);
  if (!$redis->exists('gmail')) {
    $redis->set('gmail', $gmail_config);
  } else {
    $gmail_config = decode_json($redis->get('gmail'));
  }
  my $email = -1;
  my ($mail,$error)=Email::Send::SMTP::Gmail->new(-layer=>'ssl',
                                        -port=>'465',
                                        -smtp=>'smtp.gmail.com',
                                         -login=>$gmail_config->{login},
                                         -pass=>$gmail_config->{password});
  $mail->send(-to=>$gmail_config->{sendTo}, -subject=>'Request for Information', -body=>'Please find the following information submitted via your contact form<br><br>Name : '.$hash->{Name}.'<br>Phone : '.$hash->{Phone}.'<br>Email: '.$hash->{Email}.'<br>Info : '.$hash->{Info}.'<br>Thank you',-contenttype=>'text/html');
  $mail->bye;
  $message = 'email_sent';
  $c->render(openapi => {message => $message});
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
	my $session_key;

  ($session_key,undef) = $c->uuid();

  $session_key = Encode::Base58::GMP::md5_base58($session_key);
  $c->debug($session_key);

  $container->{'cdata'} = $hash;
  $container->{cdata}->{userName} = Encode::Base58::GMP::md5_base58($hash->{'userName'});

 	$c->debug($container->{cdata}->{userName});
	
	my @matches = fgrep { /$container->{cdata}->{userName}/ } $file;
	$c->debug(@matches[0]);
	if (@matches[0]->{'count'} < 1) {
	  $c->debug("Search Entry Not Found");
    $message = {'message' => 'Email Address does not exists', 'status' => 400};
    $c->render(openapi => { 'res' => $message }, status => $message->{status});
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
          $session->{session_key} = $session_key;
          $session->{user_id} = $result;
          $session->{cdata} = $outData->{$result}->{cdata};
          $c->debug("Create New Session");
          $c->redis->setex('session_'.$session_key,1800, encode_json($session));
          $message = {'message' => 'success','sessionKey' => $session_key, 'status' => 200};
        } else {
          $message = {'message' => 'Problem with Email Address or Password', 'status' => 400};
        }
      }
    $c->render(openapi => { 'res' => $message }, status => $message->{status});
	}
	#$c->render(text => "Ok", status => 200);
};

sub logoutUser {
	my $c = shift;
	my $hash = $c->req->params->to_hash;
  my $message;

  if ($redis->exists('session_'.$hash->{sessionKey})) {
    $redis->del('session_' . $hash->{sessionKey});
    $message = { 'message' => 'success', 'status' => 200 };
  } else {
    $message = { 'message' => 'session no longer exists', 'status' => 200 };
  }
  $c->render(openapi => { 'res' => $message }, status => $message->{status});

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

sub deleteContainer {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};
  my $message;

  $streamId = $hash->{streamId} if (defined($hash->{streamId}));

  $c->debug("Delete Container");

  if ($c->redis->exists('session_'.$hash->{sessionKey})) {
    $c->debug("Valid Session $streamId");

    ## Move to Registration User Module when building the dapp
    $c->create_stream($blockChainId, $streamId);

    ## build container
    $container->{'containerid'} = $hash->{'containerid'};
    $c->debug($container);
    my $returndata = $c->delete_stream_item($blockChainId, $streamId, $container);
    $c->debug($returndata);
    $message->{'message'} = 'container_deleted';
    $message->{'data'} = $container;

  } else {
    $message = {'message' => 'no_session', 'status' => 400};
  }
  $c->render(openapi => { 'res' => $message }, status => $message->{status} || 200);
};

sub deleteContainers {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
  my $json = $c->req->json;
  my $container;
  my $message;

  ## Pass { streamId: [containerid] }
  if ($c->redis->exists('session_'.$json->{'config'}->{sessionKey})) {
    delete $json->{'config'};
    foreach (keys %{$json}) {
      foreach my $item (@{$json->{$_}}) {
        $container->{'containerid'} = $item;
        my $returndata = $c->delete_stream_item($blockChainId, $_, $container);
        $c->debug($returndata);
      }
    }
    $message->{'message'} = 'containers_deleted';
  } else {
    $message = {'message' => 'no_session', 'status' => 400};
  }
  $c->render(openapi => { 'res' => $message }, status => $message->{status} || 200);
};

sub createContainer {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $hash = $c->req->params->to_hash;
	my $json = $c->req->json;
  my $message;
  my $streamId;
  my $create_user;

  $c->debug("Create Container");

  if (defined($json->{'config'}->{'streamId'})) {
    $streamId = $json->{'config'}->{'streamId'};
    delete $json->{'config'};

    ## Move to Registration User Module when building the dapp
	  $c->create_stream($blockChainId, $streamId);

    ## Use passed containerid if not generate one
    my ($containerid,undef) = $json->{'containerid'} || $c->uuid();

    ## build container
		$json->{'containerid'} = $containerid;

    ## Normalise
    if (lc($json->{'cdata'}->{'website'}) !~ /^http/) {
      $json->{'cdata'}->{'website'} = 'http://'.$json->{'cdata'}->{'website'};
    }
    $json->{'cdata'}->{'userEmail'} = lc($json->{'cdata'}->{'userEmail'}) if (defined($json->{'cdata'}->{'userEmail'}));
    $json->{'cdata'}->{'userName'} = lc($json->{'cdata'}->{'userName'}) if (defined($json->{'cdata'}->{'userName'}));
    $json->{'cdata'}->{'website'} = lc($json->{'cdata'}->{'website'}) if (defined($json->{'cdata'}->{'website'}));

    $create_user = $c->create_index($streamId, $json);

    $c->debug($create_user);

    if ($create_user->{'message'} eq 'Success') {
      $c->debug("Create New User");
      ## Subscribe to MailChimp
      $c->mailchimp_subscribe($json);

      ## Create Container
      $c->publish_stream($blockChainId, $streamId, $json);

      $message = { 'message' => 'created', 'status' => 200 };
    }
  } else {
    $message = {'message' => 'no_streamId', 'info' => 'you must pass a config->streamId', 'status' => 400};
  }

  $c->render(openapi => { 'res' => $message }, status => $message->{status} || 200);
};

sub getCustomers {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
  my $json = $c->req->json;
  my $headers = $c->req->headers;
  my $outData;
	my $container;
  my $deleted = 1;
	my $method = $spec->{'x-mojo-function'};
  $c->debug('Get Customers Start');
  my $xurl = $c->req->headers->header('X-Url');
  my $session;
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
  $streamId = $hash->{streamId} if (defined($hash->{streamId}));

	$c->create_stream($blockChainId, $streamId);

  if ($c->redis->exists("session_$hash->{sessionKey}")) {
   $session = decode_json($c->redis->get('session_'.$hash->{sessionKey}));
    my $admin = $xurl.'_admin_'.$session->{user_id};
    $c->debug($admin);
    if ($c->redis->exists($admin)) {
      $outData->{permissions}->{'admin'} = \1;
      $outData->{data} = $c->get_all_stream_item($blockChainId, $streamId,-1,$deleted);
    } else {
      $c->debug("Not Admin");
      $outData->{permissions}->{'admin'} = \0;
      $outData->{'data'} = $c->get_stream_item($blockChainId, $streamId, $session->{'user_id'});
      $outData->{'data'}->{'count'} = '1';
    }

  }

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
  my $outData;

	## Move to Registration User Module when building the dapp
	$c->create_stream($blockChainId, $streamId);
	
	$outData  =$c->get_all_stream_item($blockChainId, $streamId);
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

sub getSlot {

	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $container;
	my $method = $spec->{'x-mojo-function'};
	my $outData = {};
  my $xurl = $c->req->headers->header('X-Url');
  my $session;


 	$c->debug("GetSlot");
 	$c->debug($json);

  my $slot  = $c->get_stream_item($blockChainId, 'slotsh', $json->{'containerid'});
  if ($c->redis->exists("session_$json->{sessionKey}")) {
    $session = decode_json($c->redis->get('session_'.$json->{sessionKey}));
  }

  $c->debug($slot);

  my $admin = $xurl.'_admin_'.$session->{'user_id'};
  $c->debug($admin);
  if ($c->redis->exists($admin)) {
    $c->debug("Admin Detected");
    $slot->{$json->{'containerid'}}->{'permissions'}->{'edit'} = \1;
    $slot->{$json->{'containerid'}}->{'permissions'}->{'admin'} = \1;
  } elsif ($c->redis->exists("session_$json->{sessionKey}")) {
    my $customer  = $c->get_stream_item($blockChainId, 'custh', $session->{user_id});
    $c->debug($customer);
    foreach ( keys%{ $customer } ) {
      $c->debug($_);

      foreach my $item (@{$customer->{$_}->{'cdata'}->{'slots'}}) {
        $c->debug($item);
        if ($item eq $json->{'containerid'}) {
          $slot->{$json->{'containerid'}}->{'permissions'}->{'edit'} = \1;
        }
      }
    }
  } else {
    $c->debug("Session Not Found");
    $slot->{$json->{'containerid'}}->{'permissions'}->{'edit'} = \0;
  }

  foreach ( keys%{ $slot } ){
    $outData->{ $_ } = $slot->{ $_ } ;
  }

  $c->debug($outData);


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

  $c->debug("Update Slot");

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


  ## Process Gallery
  my ($tmpdir,undef) = $c->uuid();
  my $path = "/tmp/$tmpdir";
  mkdir $path;
  my @filenames;

  foreach my $item (@{$json->{'cdata'}->{'gallery'}}) {
    my ($dataimage,$image) = split(/,/,$item->{'link'});
	  if ($dataimage =~ /^data:image/) {
      my $imagedecoded = b64_decode $image;
      my ($file,undef) = $c->uuid();
      my ($filetype,undef) = split(/;/,$dataimage);
      $c->debug($filetype);
      $filetype = 'jpg' if ($filetype =~ /jpeg$/);
      $filetype = 'png' if ($filetype =~ /png$/);
      $file .= '.'.$filetype;
      $c->debug("Gallery Base64 File $file");
      push(@filenames, $file);
      $file = $path.'/'.$file;
      open my $fh, '>', $file or die $!;
		  binmode $fh;
		  print $fh $imagedecoded;
		  close $fh;
    }
  }
  $c->debug('Gallery Files');
  $c->debug(@filenames);

  ## Save Images to IPFS network
    $c->debug('Save IPFS');
		my $command = "ipfs add -r -Q $path";
		my $ipfsid = qx/$command/;
		$ipfsid =~ s/\R//g;

    my $counter = 0;
    foreach my $item (@{$json->{'cdata'}->{'gallery'}}) {
      my ($dataimage,undef) = split(/,/,$item->{'link'});
	    if ($dataimage =~ /^data:image/) {
        $item->{'link'} = './ipfs/' . $ipfsid . '/' . @filenames[$counter];
        $counter++;
      }
    }

    $c->debug("Update Gallery");
    $c->debug($json->{'cdata'}->{'gallery'});

  ## clean up folder remove temp files
		my $command = "rm -rf $path";
		qx/$command/;


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
	
	$c->create_stream($blockChainId, 'subadb');
	
	if ($json->{'attribs'}->{'sub'}) {
		$c->publish_stream($blockChainId, 'subadb', $json);
	} else {
		$c->delete_stream_item($blockChainId, 'subadb', $json);
	}
	
	$c->create_stream($blockChainId, 'slotsh');
	
 	$c->publish_stream($blockChainId, 'slotsh', $json);

	$c->render(json => {'message' => 'Ok'}, status => 200);
};

sub buildSubAds {
  my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $json = $c->req->json;
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};

  $c->debug($hash);

  $c->create_stream($blockChainId, $hash->{'new'});

  $c->rebuild_subads($blockChainId, $hash->{'old'}, $hash->{'new'}, $hash->{'lessthan'});

  $c->render(json => {'message' => 'ok'}, status => 200);

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

sub buildUsers {
	my $c = shift;
	my $spec = $c->openapi->spec;
	my $blockChainId = $c->param('blockChainId');
	my $streamId = $spec->{'x-mojo-streamid'};
	my $hash = $c->req->params->to_hash;
	my $container;
	my $method = $spec->{'x-mojo-function'};

	my $processData = $c->get_all_stream_item($blockChainId, 'profiles');

	delete $processData->{'count'};

	$c->debug($processData);

	foreach my $key (keys %{$processData}) {
#		if (defined($ads->))
		$c->debug("Build Users Index");

		if (defined($processData->{$key}->{'cdata'}->{'userName'})) {
			my $container = $processData->{$key};
      my $file = "/home/node/search/profiles.txt";
      my @array;
	    push(@array, "CID$container->{containerid}");
	    push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
      push(@array, Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'}));
	    my $index = join(' ', @array);
      $c->debug($index);

      if (not -e $file) {
        open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
        say $fh $index;
        close $fh;
      } else {
        $c->debug("Search $container->{'containerid'}");
		    my $userName = Encode::Base58::GMP::md5_base58($container->{'cdata'}->{'userName'});
		    my @matches = fgrep { /$userName/ } $file;
#		    $c->debug(@matches[0]);
#		    $c->debug(@matches[0]->{'count'});
		    if (@matches[0]->{'count'} < 1) {
          $c->debug("Search Entry Not Found");
          open(my $fh, '>>', $file) or die "Could not open file '$file' $!";
          say $fh $index;
          close $fh;
        } else {
          $c->debug("User Exists $container->{'containerid'}");
        }
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
  my $filter;
  my %filter;
	my (@searchindex) = grep(/$json->{'search'}->{'section'}/, @docs);
	my $sectioncount = @searchindex;
	(@searchindex) = grep(/$json->{'search'}->{'town'}/, @docs);
	my $locationcount = @searchindex;

  $filter->{'and'} = '1';
  $filter->{'cleaners'} = '1';
  $filter->{'services'} = '1';
  $filter = encode_json($filter);
  if (!$redis->exists('word_filter')) {
    $redis->set('word_filter', $filter);
  } else {
    $filter = decode_json($redis->get('word_filter'));
    %filter = %$filter;
  }

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
