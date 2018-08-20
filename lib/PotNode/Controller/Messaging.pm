package PotNode::Controller::Messaging;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::Encryption::EncryptedRequest;
use PotNode::Encryption::EncryptedResponse;
use PotNode::Messaging::Service;
use PotNode::Messaging::Device;
use Mojo::JSON qw/encode_json decode_json/;

my $msg_srv = PotNode::Messaging::Service->new;
my $pubsub = PotNode::PubSubService->new;

sub subscribe {
  my $c = shift;
  my $req = PotNode::Encryption::EncryptedRequest->new(req => $c->req->json);
  eval { $req = decode_json $req->decr_data }
  or return $c->render(json => { error => "Decryption error"} );

  my $pubid = $req->{pubid};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless $pubid;

  my $dev = PotNode::Messaging::Device->new(pubid => $pubid);
  $dev->register;
  $msg_srv->subscribe($dev);
  $c->render(json => {"message" => "OK"});
}

sub send_msg{
  my $c = shift;

  my $req = PotNode::Encryption::EncryptedRequest->new(req => $c->req->json);
  eval { $req = decode_json $req->decr_data }
  or return $c->render(json => { error => "Decryption error"} );

  my $pubid = $req->{pubid};
  my $sender = $req->{sender};
  my $data = $req->{data};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless ($pubid && $sender && $data);

  my %payload = (
    type => "message",
    sender => $sender,
    data => $data
  );

  $msg_srv->send_data($pubid, %payload);

  $c->render(json => {"message" => "OK"});
}

sub new_contact{
  my $c = shift;

  my $req = PotNode::Encryption::EncryptedRequest->new(req => $c->req->json);
  eval { $req = decode_json $req->decr_data }
  or return $c->render(json => { error => "Decryption error"} );

  my $pubid = $req->{pubid};
  my $sender = $req->{sender};
  my $data = $req->{data};
  my $aeskey = $req->{aeskey};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless ($pubid && $sender && $data && $aeskey);

  my %payload = (
    type => "new_contact",
    sender => $sender,
    data => $data,
    aeskey => $aeskey
  );

  $msg_srv->send_data($pubid, %payload);

  $c->render(json => {"message" => "OK"});
}

sub new_contact_info{
  my $c = shift;

  my $req = PotNode::Encryption::EncryptedRequest->new(req => $c->req->json);
  eval { $req = decode_json $req->decr_data }
  or return $c->render(json => { error => "Decryption error"} );

  my $pubid = $req->{pubid};
  my $sender = $req->{sender};
  my $data = $req->{data};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless ($pubid && $sender && $data);

  my %payload = (
    type => "new_contact_info",
    sender => $sender,
    data => $data
  );

  $msg_srv->send_data($pubid, %payload);

  $c->render(json => {"message" => "OK"});
}

sub get_new{
  my $c = shift;

  my $req = PotNode::Encryption::EncryptedRequest->new(req => $c->req->json);
  eval { $req = decode_json $req->decr_data }
  or return $c->render(json => { error => "Decryption error"} );

  my $pubid = $req->{pubid};
  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless ($pubid);

  my $messages = $msg_srv->get_msgs($pubid, 1);
  my $new_contacts = $msg_srv->get_new_contacts($pubid, 1);
  my $new_contact_info = $msg_srv->get_new_contact_info($pubid, 1);

  $pubsub->ls(sub {
    my $tx = shift;
    my $topics = $tx->res->json->{Strings};
    unless ($topics && $pubid ~~ @$topics){
      my $dev = PotNode::Messaging::Device->new(pubid => $pubid);
      $dev->register;
      PotNode::Controller::Messaging->subscribe($c);
    }
  });

  $c->render(json => PotNode::Encryption::EncryptedResponse->new({
    data => encode_json({messages => $messages, contacts => $new_contacts, contact_info => $new_contact_info}),
    dev_pubkey => $c->req->json->{pubkey}
  })->encr_data);
}


1;
