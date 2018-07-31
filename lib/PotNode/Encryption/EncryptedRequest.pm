package PotNode::Encryption::EncryptedRequest;
use Mojo::Base -base;
use Mojo::Redis2;
use Carp;

has redis => sub { Mojo::Redis2->new };
has encr => sub { PotNode::Encryption::Helpers->new };
has 'req';
has 'encr_data' => sub { shift->req->{data} };
has 'dev_pubkey' => sub { shift->req->{pubkey} };
has 'encr_aeskey' => sub { shift->req->{aeskey} };
has 'iv' => sub { shift->req->{iv} };
has node_privkey => sub { my $self = shift; $self->redis->hget('keys', 'privkey')};

sub decr_data{
  my $self = shift;

  # Checking if node RSA keys are available and if not, creating such
  $self->encr->redis_rsa_keys();

  # Decrypting the aes key
  my $decr_aeskey = $self->encr->rsa_decrypt($self->encr_aeskey, $self->node_privkey);

  # Decrypting the data and converting from json to a hash
  $self->encr->aes_decrypt($self->encr_data, $decr_aeskey, $self->iv);
}

sub error{
  my $self = shift;

  unless ($self->encr_data) { return "No data received."; }
  unless ($self->dev_pubkey) { return "No public RSA key received."; }
  unless ($self->encr_aeskey) { return "No AES key received."; }
  unless ($self->iv) { return "No init vector received."; }

  return 0;
}

1;
