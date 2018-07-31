package PotNode::Messaging::Service;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::PubSubService;
use Mojo::Redis2;
use Mojo::JSON qw/encode_json decode_json/;
use Carp;
use MIME::Base64;

# use Mojo::Log;
# my $log = Mojo::Log->new(path => '/home/node/log/pot_node.log');

use constant 'REDIS_MSGS' => "messages_";

has redis => sub { Mojo::Redis2->new };
has pubsub => sub { PotNode::PubSubService->new };

sub send_msg {
  my ($self, $pubid, $sender, $message, $seqno, $date) = @_;

  my %payload = (
    type => "message",
    sender => $sender,
    message => $message,
  );

  $payload{seqno} = $seqno if $seqno;
  $payload{date} = $date if $date;

  $self->pubsub->pub($pubid, encode_json \%payload);
}

sub send_move{
  my ($self, $pubid) = @_;

  my $payload = encode_json {
    type => "move"
  };

  $self->pubsub->pub($pubid, $payload);
}

sub get_msgs{
  my ($self, $pubid, @senders, $clear) = @_;

  my $all_messages = $self->redis->lrange(REDIS_MSGS.$pubid, 0, -1);
  $self->redis->del(REDIS_MSGS.$pubid) if $clear;
  my @messages;
  for my $message(@$all_messages){
    my $msg_data = decode_json $message;
    if ($msg_data->{sender} ~~ @senders){
      push(@messages, $message);
    }
  }

  return @messages;
}

sub add_msg_redis{
  my ($self, $pubid, $sender, $message, $seqno, $date) = @_;

  my %msg = (
    seqno => $seqno,
    sender => $sender,
    date => $date,
    message => $message
  );

  $self->redis->lpush(REDIS_MSGS.$pubid, encode_json(\%msg));
}

sub subscribe {
  my ($self, $dev) = @_;

  $self->pubsub->sub($dev->pubid, sub {
    my $pub_body = decode_json shift;
    my $msg_body_json = decode_base64 $pub_body->{data};
    my $msg_body = decode_json($msg_body_json);
    my $type = $msg_body->{type};
    if ($type eq 'message'){
      return 0 unless ($dev->is_registered);
      $self->add_msg_redis(
        $dev->pubid,
        $msg_body->{sender},
        $msg_body->{message},
        $pub_body->{seqno},
        time()
      );
      return 1;
    } elsif ($type eq 'move'){
      $dev->cancel;
      my $all_messages = $self->redis->lrange(REDIS_MSGS.$dev->pubid, 0, -1);
      for my $message(@$all_messages){
        $message = decode_json $message;
        $self->send_msg(
          $dev->pubid,
          $message->{sender},
          $message->{message},
          $message->{seqno},
          $message->{date}
        );
      }
      $self->redis->del(REDIS_MSGS.$dev->pubid);
      return 0;
    }
    return 1;
  });
}


1;
