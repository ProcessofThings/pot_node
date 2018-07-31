package PotNode::Messaging::Device;
use Mojo::Base -base;
use Mojo::Redis2;
use Mojo::JSON qw/encode_json decode_json/;
use Carp;

use constant 'REDIS_MSG_DEVICES' => "msg_devices";

has redis => sub { Mojo::Redis2->new };
has 'pubid';
has movekey => sub {
  my $self = shift;
  if ($self->is_registered){
    return decode_json($self->redis->hget(REDIS_MSG_DEVICES, $self->pubid))->{movekey};
  } else {
    return $self->gen_movekey;
  }
};

sub register{
  my $self = shift;
  return if $self->is_registered;

  $self->redis->hset(REDIS_MSG_DEVICES, $self->pubid, encode_json {
    movekey => $self->movekey
  });
}

sub gen_movekey{
  my @chars = ("A".."Z", "a".."z", 0 .. 9);
  my $string;
  $string .= $chars[rand @chars] for 1..8;
  return $string;
}

sub is_registered{
  my $self = shift;
  return $self->redis->hexists(REDIS_MSG_DEVICES, $self->pubid);
}

sub cancel{
  my $self = shift;
  $self->redis->hdel(REDIS_MSG_DEVICES, $self->pubid);
}

1;
