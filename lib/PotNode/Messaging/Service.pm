package PotNode::Messaging::Service;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::PubSubService;
use Mojo::Redis2;
use Mojo::JSON qw/encode_json decode_json/;
use Carp;
use MIME::Base64;

use Mojo::Log;
my $log = Mojo::Log->new(path => '/home/node/log/pot_node.log');

use constant 'REDIS_MSGS' => "messages_";
use constant 'REDIS_NEW_CONTACTS' => "new_contacts_";
use constant 'REDIS_NEW_CONTACT_INFO' => "new_contact_info_";

has redis => sub { Mojo::Redis2->new };
has pubsub => sub { PotNode::PubSubService->new };

sub send_data {
  my ($self, $pubid, %payload) = @_;
  $self->pubsub->pub($pubid, encode_json \%payload);
}

sub get_msgs{
  my ($self, $pubid, $clear) = @_;

  my $all_messages = $self->redis->lrange(REDIS_MSGS.$pubid, 0, -1);
  $self->redis->del(REDIS_MSGS.$pubid) if $clear;

  return $all_messages;
}

sub get_new_contacts{
  my ($self, $pubid, $clear) = @_;

  my $new_contacts = $self->redis->lrange(REDIS_NEW_CONTACTS.$pubid, 0, -1);
  $self->redis->del(REDIS_NEW_CONTACTS.$pubid) if $clear;

  return $new_contacts;
}

sub get_new_contact_info{
  my ($self, $pubid, $clear) = @_;

  my $new_contacts = $self->redis->lrange(REDIS_NEW_CONTACT_INFO.$pubid, 0, -1);
  $self->redis->del(REDIS_NEW_CONTACT_INFO.$pubid) if $clear;

  return $new_contacts;
}

sub add_msg_redis{
  my ($self, $pubid, $sender, $data, $seqno, $date) = @_;

  my %msg = (
    sender => $sender,
    seqno => $seqno,
    date => $date,
    data => $data
  );

  $self->redis->lpush(REDIS_MSGS.$pubid, encode_json(\%msg));
}

sub add_new_contact_redis{
  my ($self, $pubid, $sender, $data, $aeskey, $seqno, $date) = @_;

  my %new_contact = (
    sender => $sender,
    seqno => $seqno,
    date => $date,
    data => $data,
    aeskey => $aeskey
  );

  $self->redis->lpush(REDIS_NEW_CONTACTS.$pubid, encode_json(\%new_contact));
}

sub add_new_contact_info_redis{
  my ($self, $pubid, $sender, $data, $aeskey, $seqno, $date) = @_;

  my %new_contact_info = (
    sender => $sender,
    seqno => $seqno,
    date => $date,
    data => $data,
    aeskey => $aeskey
  );

  $self->redis->lpush(REDIS_NEW_CONTACT_INFO.$pubid, encode_json(\%new_contact_info));
}

sub subscribe {
  my ($self, $dev) = @_;
  $self->pubsub->sub($dev->pubid, sub {
    my $pub_body = decode_json shift;
    my $msg_body_json = decode_base64 $pub_body->{data};
    my $msg_body = decode_json($msg_body_json);

    my $sender = $msg_body->{sender};
    my $type = $msg_body->{type};
    my $data = $msg_body->{data};
    my $seqno = $pub_body->{seqno};

    if ($type eq 'message'){
      return 0 unless ($dev->is_registered);
      $self->add_msg_redis(
        $dev->pubid,
        $sender,
        $data,
        $pub_body->{seqno},
        time()
      );
      return 1;
    } elsif($type eq 'new_contact') {
      return 0 unless ($dev->is_registered);
      $self->add_new_contact_redis(
        $dev->pubid,
        $sender,
        $data,
        $msg_body->{aeskey},
        $pub_body->{seqno},
        time()
      );
      return 1;
    } elsif($type eq 'new_contact_info') {
      return 0 unless ($dev->is_registered);
      $self->add_new_contact_info_redis(
        $dev->pubid,
        $sender,
        $data,
        $msg_body->{aeskey},
        $pub_body->{seqno},
        time()
      );
      return 1;
    } elsif ($type eq 'move'){
      $dev->cancel;
      my $all_messages = $self->get_msgs($dev->pubid, 1);
      for my $message(reverse @$all_messages){
        $message = decode_json $message;
        my %payload = %$message;
        $payload{type} = "message";
        $self->send_data($dev->pubid, %payload);
      }

      my $all_contacts = $self->get_new_contacts($dev->pubid, 1);
      for my $contact(reverse @$all_contacts){
        $contact = decode_json $contact;
        my %payload = %$contact;
        $payload{type} = "new_contact";
        $self->send_data($dev->pubid, %payload);
      }

      my $all_contact_info = $self->get_new_contact_info($dev->pubid, 1);
      for my $contact_info(reverse @$all_contact_info){
        $contact_info = decode_json $contact_info;
        my %payload = %$contact_info;
        $payload{type} = "new_contact_info";
        $self->send_data($dev->pubid, %payload);
      }
      return 0;
    }
    return 1;
  });
}


1;
