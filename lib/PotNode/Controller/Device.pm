package PotNode::Controller::Device;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Redis2;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Crypt::RSA;

my $redis = Mojo::Redis2->new;
my $ua = Mojo::UserAgent->new;
my $rsa = Crypt::RSA->new;

sub ping{
  my $c = shift;
  my $encr_data = $c->req->params('data');
  my $pubkey = $c->req->params('pubkey');

  my ($pubkey, $privkey) =
  $rsa->keygen (Size => 1024)
   or die $rsa->errstr();

   $pubkey->write(Filename=>"/home/node/pubkey.pk");
   $privkey->write(Filename=>"/home/node/privkey.pk");

  unless ($redis->exists('keys')){
    $c->app->log->debug('RSA Keys for node not found, creating new ones.');
    my ($pubkey, $privkey) =
    $rsa->keygen (Size => 1024)
     or die $rsa->errstr();

     # $redis->set('keys', encode_json {
     #     pubkey => $pubkey->serialize(),
     #     privkey => $privkey->serialize()
     #   });
  }

  $c->render(text => "worked");

  # my $nodepubkey = (decode_json $redis->get('keys')){'privkey'};
  # $c->render(text => $nodepubkey);
}
