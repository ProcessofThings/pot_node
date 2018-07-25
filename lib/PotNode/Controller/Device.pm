package PotNode::Controller::Device;
use PotNode::EncryptedRequest;
use PotNode::EncryptedResponse;
use PotNode::InviteService;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Redis2;
use Mojo::JSON qw(decode_json);
use Try::Tiny;
use Mojo::IOLoop::Stream;


use constant REDIS_GEN_UUIDS_KEY => 'generated_uuids';
use constant REDIS_UUIDS_KEY => 'device_uuids';

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

  my $req = PotNode::EncryptedRequest->new(
    encr_data => $req->{data},
    encr_aeskey => $req->{aeskey},
    iv => $req->{iv},
    dev_pubkey => $req->{pubkey}
  );

  if ($req->error) {
    $c->render(json => { error => $req->error }, status => 400);
    return;
  }

  my $decr_data;
  my $result = eval {
    $decr_data = decode_json $req->decr_data;
  };

  unless ($result){
    $c->render(json => { error => "Encryption error" }, status => 500);
    return;
  }

  # Checking if posted UUID is generated from node and if it already exists
  my $uuid = $decr_data->{uuid};

  unless ($uuid){
    $error = "No UUID received.";
  } elsif($c->redis->sismember(REDIS_UUIDS_KEY, $uuid)){
    $error = "UUID already exists.";
  } elsif (!$c->redis->hexists(REDIS_GEN_UUIDS_KEY, $uuid)){
    $error = "Invalid or expired UUID.";
  }

  if ($error) {
    $c->render(json => { error => $error }, status => 400);
    return;
  }

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
