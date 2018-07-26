package PotNode::MessageService;
use Mojo::Base -base;
use PotNode::PubSubService;
use Mojo::Redis2;
use Mojo::JSON qw/encode_json decode_json/;

use constant 'REDIS_MSGS' => "messages_";

has redis => sub { Mojo::Redis2->new };
has pubsub => sub { PotNode::PubSub->new };

sub send {
  my ($self, $sender, $receiver, $message) = @_;

  my $payload = encode_json (
    sender => $sender,
    message => $message
  );

  $self->pubsub->pub($receiver, $payload);
}

sub get_msgs{
  my ($self, $receiver, @senders) = @_;

  my @all_messages = $self->redis->lrange(REDIS_MSGS.$receiver, 0, -1);
  my @messages;

  for my $message(@all_messages){
    my $msg_data = decode_json $message;
    if ($msg_data->{sender} ~~ @senders){
      push(@messages, $message);
    }
  }

  return @messages;
}

sub add_msg_redis{
  my ($self, $body, $sender, $receiver) = @_;

  my $msg_data = decode_json $body;
  my %msg = (
    id => $msg_data->{seqno},
    sender => $sender,
    date => time(),
    msg => decode_base64 $msg_data->{data}
  );

  $self->redis->lpush(REDIS_MSGS.$receiver, encode_json(%msg));
}

1;
