package PotNode::EncryptHelpers;
use base 'Mojolicious::Plugin::DebugDumperHelper';
use Mojo::JSON qw(decode_json encode_json);
use Digest::MD5 qw(md5_hex);
use Crypt::OpenSSL::RSA;
use Crypt::Cipher::AES;
use Crypt::Mode::CBC;
use MIME::Base64;
use Data::UUID;
use Encode;
use Carp;

use constant AES_BYTES => 16;
use constant RSA_BITS => 1024;

my $redis = Mojo::Redis2->new;

sub register {

  my ($self, $app) = @_;

  $app->helper(aes_encrypt => \&aes_encrypt);
  $app->helper(aes_decrypt => \&aes_decrypt);
  $app->helper(rsa_encrypt => \&rsa_encrypt);
  $app->helper(rsa_decrypt => \&rsa_decrypt);
  $app->helper(gen_rsa_keys => \&gen_rsa_keys);
  $app->helper(redis_rsa_keys => \&redis_rsa_keys);
  $app->helper(to_hex => \&to_hex);
  $app->helper(pothash => \&pothash);
}

sub aes_encrypt{
  my $self = shift;
  my $raw_data = shift;
  my $bytes = shift || $self->AES_BYTES;

  my $key = Crypt::CBC->random_bytes($bytes);
  my $iv = Crypt::CBC->random_bytes($bytes);

  my %settings = (key         => "$key",
                  iv          => "$iv",
                  cipher      => "Cipher::AES",
                  header      => "none",
                  literal_key => 1,
                  keysize     => $bytes);

  my $cipher = Crypt::CBC->new(\%settings);
  my $encr_data = $cipher->encrypt($raw_data);

  (encode_base64 ($encr_data), encode_base64($key), encode_base64($iv));
};

sub aes_decrypt{
  my $self = shift;
  my $encr_data = decode_base64 shift;
  my $key = decode_base64 shift;
  my $iv = decode_base64 shift;

  my $bytes = shift || AES_BYTES;

  my %settings = (key         => "$key",
                  iv          => "$iv",
                  cipher      => "Cipher::AES",
                  header      => "none",
                  literal_key => 1,
                  keysize     => $bytes);

  my $cipher = Crypt::CBC->new(\%settings);
  $cipher->decrypt($encr_data);
};

sub rsa_encrypt{
  my $self = shift;
  my $raw_data = shift;
  my $pubkey = shift;

  unless ($pubkey =~ /BEGIN PUBLIC KEY/){
    $pubkey = "-----BEGIN PUBLIC KEY-----\n".$pubkey."-----END PUBLIC KEY-----";
  }

  $pubkey = Crypt::OpenSSL::RSA->new_public_key($pubkey);
  $pubkey->use_pkcs1_padding();
  encode_base64 $pubkey->encrypt($raw_data);
}

sub rsa_decrypt{
  my $self = shift;
  my $encr_data = decode_base64 shift;
  my $privkey = shift;
  my $has_headers = shift || 1;

  unless ($privkey =~ /BEGIN RSA PRIVATE KEY/){
    $privkey = "-----BEGIN RSA PRIVATE KEY-----\n".$privkey."-----END RSA PRIVATE KEY-----";
  }

  $privkey = Crypt::OpenSSL::RSA->new_private_key($privkey);
  $privkey->use_pkcs1_padding();
  $privkey->decrypt($encr_data);
}

sub gen_rsa_keys{
  my $self = shift;
  my $bits = shift;
  $bits = RSA_BITS unless $bits;
  # Generating keys
  my $key = Crypt::OpenSSL::RSA->generate_key($bits);

  my $pubkey = $key->get_public_key_x509_string();
  my $privkey = $key->get_private_key_string();

  ($pubkey, $privkey);
};

sub redis_rsa_keys{
  my $self = shift;
  unless ($redis->exists('keys')){
    my ($pubkey, $privkey) = &gen_rsa_keys();

    # Adding the keys to the redis database encoded as JSON
    $redis->hset('keys', 'pubkey', $pubkey);
    $redis->hset('keys', 'privkey', $privkey);
  }
};

sub to_hex{
  my $self = shift;
  my $text = shift;
  Encode::_utf8_off ($text);
  my $hex = uc unpack "H*", $text;
  join ('', $hex =~ /(..)/g);
};

sub pothash{
  my $self = shift;
  my $string = shift;
  # Getting a random part of a md5 hash;
  # In this case characters 3-4-5-6
  substr(md5_hex($string), 3, 4);
}

1;
