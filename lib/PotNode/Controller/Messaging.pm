package PotNode::Controller::Messaging;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::Encryption::EncryptedRequest;
use PotNode::Encryption::EncryptedResponse;
use PotNode::Messaging::Service;
use PotNode::Messaging::Device;
use Mojo::JSON qw/encode_json decode_json/;

my $msg_srv = PotNode::Messaging::Service->new;

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

  my $sender = $req->{sender};
  my $pubid = $req->{pubid};
  my $message = $req->{message};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless ($sender && $pubid && $message);

  $msg_srv->send_msg($pubid, $sender, $message);

  $c->render(json => {"message" => "OK"});
}

sub get_msgs{
  my $c = shift;

  my $req = PotNode::Encryption::EncryptedRequest->new(req => $c->req->json);
  eval { $req = decode_json $req->decr_data }
  or return $c->render(json => { error => "Decryption error"} );

  my $pubid = $req->{pubid};
  my @senders = @{$req->{senders}};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless (@senders && $pubid);

  my @messages = $msg_srv->get_msgs($pubid, @senders);

  $c->render(json => PotNode::Encryption::EncryptedResponse->new({
    data => encode_json({messages => \@messages}),
    dev_pubkey => $c->req->json->{pubkey}
  })->encr_data);

}

sub move {
  my $c = shift;

  my $req = PotNode::Encryption::EncryptedRequest->new(req => $c->req->json);
  eval { $req = decode_json $req->decr_data }
  or return $c->render(json => { error => "Decryption error"} );

  my $pubid = $req->{pubid};
  my $movekey = $req->{movekey};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless ($movekey && $pubid);

  my $dev = PotNode::Messaging::Device->new(pubid => $pubid);
  unless($dev->movekey eq $movekey) {
    $msg_srv->send_move($pubid);
    $msg_srv->subscribe($dev);
  }

  $c->render(json => {"message" => "OK"});
}


1;
