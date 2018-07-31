package PotNode::Controller::Device;
use PotNode::Encryption::EncryptedRequest;
use PotNode::Encryption::EncryptedResponse;
use PotNode::InviteService;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Redis2;
use Mojo::JSON qw(decode_json);


use constant 'REDIS_GEN_UUIDS_KEY' => 'generated_uuids';
use constant 'REDIS_UUIDS_KEY' => 'device_uuids';

my $redis = Mojo::Redis2->new;

sub genInvite{
  my $c = shift;
  my $contact_id = $c->param('contact_id');
  my $invite = PotNode::InviteService->new->gen_new($contact_id);
  $c->render(json => $c->genqrcode64($invite), status => 200);
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

  unless ($uuid){
    $error = "No UUID received.";
  } elsif($c->redis->sismember(REDIS_UUIDS_KEY, $uuid)){
    $error = "UUID already exists.";
  } elsif (!$c->redis->hexists(REDIS_GEN_UUIDS_KEY, $uuid)){
    $error = "Invalid or expired UUID.";
  }

  return $c->render(json => { error => $error }, status => 400)
  if ($error);

  # If no errors removes the UUID from the generated and adds it to the device UUIDS
  $c->redis->hdel(REDIS_GEN_UUIDS_KEY, $uuid);
  $c->redis->sadd(REDIS_UUIDS_KEY, $uuid);

  $c->app->log->debug("New device UUID registered!: $uuid");

  $c->res->headers->header('Content-Type' => 'application/json; charset=utf-8');

  $c->render(json => {
    "status" => "OK",
    "uuid" => $uuid,
    "message" => "Connected to the node."
  },status => 200);
}

1;
