package PotNode::PubSubService;
use Mojo::Base -base;
use AnyEvent::HTTP;
use AnyEvent::Proc;
use Mojo::Redis2;
use Mojo::JSON qw/decode_json encode_json/;
use Carp;

use constant 'IPFS_PUBSUB_ENDPOINT' => "http://localhost:5001/api/v0/pubsub/";
use constant 'REDIS_MSGS' => "messages";

has redis => sub { Mojo::Redis2->new };

sub sub{
  my $self = shift;
  my $topic = shift || croak('Topic required.');
  my $callback = shift;
  $AnyEvent::HTTP::MAX_PER_HOST = 10000;

  http_request
    GET => IPFS_PUBSUB_ENDPOINT."sub?arg=$topic",
    persistent => 1,
    keepalive =>1,
    on_body => sub {
      my ($body, $hdr) = @_;

      unless ($hdr->{Status} =~ /^2/){
        my $now = localtime();
        croak("Error while receiving message from $topic at $now.");
      }
      &$callback(@_);
      return 1;
    },
    sub {

    };
}

sub pub{
  my $self = shift;
  my $topic = shift || croak('Topic required.');
  my $message = shift || croak('Message required.');

  http_request
    GET => IPFS_PUBSUB_ENDPOINT."pub?arg=$topic&arg=$message",
    sub {
      my ($body, $hdr) = @_;

      unless ($hdr->{Status} =~ /^2/){
        my $now = localtime();
        croak("Could not send message to $topic at $now.");
      }
    };
}

1;
