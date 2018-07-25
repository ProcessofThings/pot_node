package PotNode::InviteService;
use Mojo::Base -base;
use Mojo::Redis2;
use Data::UUID;
use PotNode::EncryptHelpers;

use constant REDIS_GEN_UUIDS_KEY => 'generated_uuids';
use constant REDIS_UUIDS_KEY => 'device_uuids';
use constant UUIDS_EXPIRE_MIN => 5;

has redis => sub { Mojo::Redis2->new };
has uuid => sub { Data::UUID->new };
has encr => sub { PotNode::EncryptHelpers->new };

sub gen_new{
  my $self = shift;

  $self->encr->redis_rsa_keys;

  my $contact_id = shift;

  # Generating UUID
  my $gen_uuid = $self->uuid->create_str();
  $self->redis->hset(REDIS_GEN_UUIDS_KEY, $gen_uuid, time()+(UUIDS_EXPIRE_MIN*60));

  # Getting the node public key from redis
  my $node_pubkey = $self->redis->hget('keys', 'pubkey');

  # Removing the header and footer of the node pubkey
  $node_pubkey =~ s/^(.*\n){1}//;
  $node_pubkey =~ s/(.*\n){1}$//;

  # Adding the host
  my $host = "http://10.10.40.174:9090/device/new";
  my $invite_str = '';
  if ($contact_id) { $invite_str = $contact_id }
  $invite_str .= $gen_uuid.$node_pubkey.$host;
  $invite_str =~ s/\n//g;

  # Adding the hash
  $self->encr->pothash($invite_str).$invite_str;
}

sub clear_expired_uuids{
  my $self = shift;
  my $now = time();
  for my $uuid (@{$self->redis->hkeys(REDIS_GEN_UUIDS_KEY)}){
    if ($self->redis->hget(REDIS_GEN_UUIDS_KEY,$uuid) - $now <= 0){
      $self->redis->hdel(REDIS_GEN_UUIDS_KEY,$uuid);
    }
  }
}

1;
