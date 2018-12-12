package PotNode::Controller::Device;
use PotNode::Encryption::EncryptedRequest;
use PotNode::Encryption::EncryptedResponse;
use PotNode::InviteService;
use PotNode::Messaging::Service;
use PotNode::Messaging::Device;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Redis2;
use Mojo::JSON qw(decode_json encode_json);

use constant 'REDIS_GEN_UUIDS_KEY' => 'generated_uuids';
use constant 'REDIS_UUIDS_KEY' => 'device_uuids';

my $redis = Mojo::Redis2->new;
my $msg_srv = PotNode::Messaging::Service->new;

sub genInvite{
  my $c = shift;
  my $invite = PotNode::InviteService->new->gen_new();
  $c->render(json => $c->genqrcode64($invite, 5, 5, 'yes'), status => 200);
}

sub genDeviceInvite{
  my $c = shift;
  my $invite = PotNode::InviteService->new->gen_new();
  return $c->render(json => PotNode::Encryption::EncryptedResponse->new({
    data => encode_json($c->genqrcode64($invite)),
    dev_pubkey => $c->req->json->{pubkey}
  })->encr_data);
}

sub addNew{
  my $c = shift;
  my $error;

  my $req = $c->req->json;
  my $dev_pubkey = $req->{pubkey};

  $req = PotNode::Encryption::EncryptedRequest->new(req => $req);

  return $c->render(json => { error => $req->error }, status => 400)
  if $req->error;

  my $decr_data;
  eval { $decr_data = decode_json $req->decr_data; }
  or return $c->render(json => { error => "Decryption error" }, status => 500);

  # Checking if posted UUID is generated from node and if it already exists
  my $uuid = $decr_data->{uuid};
  my $pubid = $decr_data->{pubid};
  my $movekey = $decr_data->{movekey};

  unless ($uuid){
    $error = "No UUID received.";
  }
  elsif($c->redis->sismember(REDIS_UUIDS_KEY, $uuid)){
    $error = "UUID already exists.";
  } elsif (!$c->redis->hexists(REDIS_GEN_UUIDS_KEY, $uuid)){
    $error = "Invalid or expired UUID.";
  }

  unless ($pubid){
    $error = "No PubID received";
  }

  return $c->render(json => { error => $error }, status => 400)
  if ($error);

  # If no errors removes the UUID from the generated and adds it to the device UUIDS
  $c->redis->hdel(REDIS_GEN_UUIDS_KEY, $uuid);
  $c->redis->sadd(REDIS_UUIDS_KEY, $uuid);

  $c->app->log->debug("New device UUID registered!: $uuid");
  my $new_dev = PotNode::Messaging::Device->new(pubid => $pubid);

  if ($new_dev->movekey ne $movekey) {
    my %payload = (
      type => "move"
    );
    $new_dev->register;
    # $msg_srv->send_data($pubid, %payload);
    $msg_srv->subscribe($new_dev);
  }

  $c->res->headers->header('Content-Type' => 'application/json; charset=utf-8');

  my %response_payload = (
    "status" => "OK",
    "uuid" => $uuid,
    "movekey" => $new_dev->movekey,
    "message" => "Connected to the node."
  );

  $c->render(json => PotNode::Encryption::EncryptedResponse->new({
    data => encode_json(\%response_payload),
    dev_pubkey => $c->req->json->{pubkey}
  })->encr_data);
}

sub genqrcode{
  my $c = shift;
  my $req = $c->req->json;
  my $dev_pubkey = $req->{pubkey};

  $req = PotNode::Encryption::EncryptedRequest->new(req => $req);

  return $c->render(json => { error => $req->error }, status => 400)
  if $req->error;

  my $decr_data;
  eval { $decr_data = decode_json $req->decr_data; }
  or return $c->render(json => { error => "Decryption error" }, status => 500);

  my $data = $decr_data->{data};
  return $c->render(json => { error => "Data required."}, status => 400) unless $data;
  return $c->render(json => PotNode::Encryption::EncryptedResponse->new({
    data => encode_json($c->genqrcode64($data)),
    dev_pubkey => $c->req->json->{pubkey}
  })->encr_data);
}

1;
