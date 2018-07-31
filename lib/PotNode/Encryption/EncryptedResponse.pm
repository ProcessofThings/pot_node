package PotNode::Encryption::EncryptedResponse;
use Mojo::Base -base;
use PotNode::Encryption::Helpers;
use Mojo::Redis2;
use Carp;

has redis => sub { Mojo::Redis2->new };
has encr => sub { PotNode::Encryption::Helpers->new };
has data => sub { croak 'No data received to encrypt.' };
has dev_pubkey => sub { croak 'No RSA public key received.' };
has node_pubkey => sub { shift->redis->hget('keys', 'pubkey') };

sub encr_data{
  my $self = shift;

  my ($encr_data, $new_aes_key, $new_iv) = $self->encr->aes_encrypt($self->data);
  my $encr_aeskey = $self->encr->rsa_encrypt($new_aes_key, $self->dev_pubkey);
  {
    data => $encr_data,
    aeskey => $encr_aeskey,
    iv => $new_iv,
    pubkey => $self->node_pubkey
  };
}

1;
