package PotNode::PubSubService;
use Mojo::Base -base;
use AnyEvent::HTTP;
use AnyEvent::Proc;
use Mojo::UserAgent;
use Mojo::Redis2;
use Mojo::JSON qw/decode_json encode_json/;
use Mojo::Util qw/url_escape/;
use Carp;

use constant 'IPFS_PUBSUB_ENDPOINT' => "http://localhost:5001/api/v0/pubsub/";
use constant 'REDIS_MSGS' => "messages";

has redis => sub { Mojo::Redis2->new };
has ua => sub { Mojo::UserAgent->new };

sub sub{
  my $self = shift;
  my $topic = shift || croak('Topic required.');
  my $callback = shift;
  $AnyEvent::HTTP::MAX_PER_HOST = 100000;
  $AnyEvent::HTTP::PERSISTENT_TIMEOUT = 10000;
  $AnyEvent::HTTP::TIMEOUT = 30000;

  http_request
    GET => IPFS_PUBSUB_ENDPOINT."sub?arg=$topic",
    persistent => 1,
    keepalive => 1,
    on_body => sub {
      my ($body, $hdr) = @_;

      unless ($hdr->{Status} =~ /^2/){
        my $now = localtime();
        croak("Error while receiving message from $topic at $now.");
      }
      return &$callback(@_);
    },
    sub {

    };
}

sub pub{
  my $self = shift;
  my $topic = shift || croak('Topic required.');
  my $message = shift || croak('Message required.');
  my $callback = shift;
  $AnyEvent::HTTP::MAX_PER_HOST = 100000;
  $AnyEvent::HTTP::PERSISTENT_TIMEOUT = 10000;
  $AnyEvent::HTTP::TIMEOUT = 30000;

  $topic = url_escape($topic);
  $message = url_escape($message);
  $self->ua->get_p(IPFS_PUBSUB_ENDPOINT."pub?arg=$topic&arg=$message");

  # system("curl \"http://localhost:5001/api/v0/pubsub/pub?arg=$topic&arg=$message\"");
}

sub ls {
  my $self = shift;
  my $callback = shift;

  $self->ua->get_p(IPFS_PUBSUB_ENDPOINT."ls")->then(sub {
    my @value = @_;
    &$callback($value[0]);
  });
}

1;
