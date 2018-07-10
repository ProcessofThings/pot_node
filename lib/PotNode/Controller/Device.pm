package PotNode::Controller::Device;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Redis2;
use Mojo::JSON qw(decode_json encode_json);
use Crypt::OpenSSL::RSA;
use MIME::Base64;
use Data::UUID;
use Encode;
use Crypt::Mode::CBC;
use Crypt::Cipher::AES;

use constant REDIS_GEN_UUIDS_KEY => 'generated_uuids';
use constant REDIS_UUIDS_KEY => 'device_uuids';

my $redis = Mojo::Redis2->new;
my $uuid = Data::UUID->new;

sub gen_rsa_keys{
  my $bits = shift;
  $bits = 1024 unless $bits;
  # Generating keys
  my $key = Crypt::OpenSSL::RSA->generate_key($bits);
  my $pubkey = $key->get_public_key_string();
  # $pubkey =~ s/^(.*\n){1}//;
  # $pubkey =~ s/(.*\n){1}$//;

  my $privkey = $key->get_private_key_string();
  # $privkey =~ s/^(.*\n){1}//;
  # $privkey =~ s/(.*\n){1}$//;

  ($pubkey, $privkey);
}

sub genNew{
  my $c = shift;
  my $node_keys;
  my $node_pubkey;
  my $gen_pubkey;
  my $gen_privkey;
  my $gen_uuid;
  my $json;
  my @hosts;

  unless ($redis->exists('keys')){
    $c->app->log->debug('RSA Keys for node not found, creating new ones.');

    my ($pubkey, $privkey) = &gen_rsa_keys();
    $c->app->log->debug("Public key: \n $pubkey \n Private key: \n $privkey");

    # Adding the keys to the redis database encoded as JSON
    $redis->hset('keys', 'pubkey', $pubkey);
    $redis->hset('keys', 'privkey', $privkey);
  }

  # Getting the node public key from redis
  $node_pubkey = $redis->hget('keys', 'pubkey');

  # Generating new RSA keys for the device
  ($gen_pubkey, $gen_privkey) = &gen_rsa_keys();

  # Generating UUID
  $gen_uuid = $uuid->create_str();
  $redis->sadd(REDIS_GEN_UUIDS_KEY, $gen_uuid);

  @hosts = &get_hosts();

  # Encoding into json
  $json = encode_json {
    uuid => $gen_uuid,
    genpotkey => 1,
    pubkey => $gen_pubkey,
    privkey => $gen_privkey,
    nodepubkey => $node_pubkey,
    hosts => \@hosts
  };

  # Converting json to hex
  my $json_text = $json;
  Encode::_utf8_off ($json);
  my $json_hex = uc unpack "H*", $json;
  $json_hex = join (' ', $json_hex =~ /(..)/g);

  $c->render(text => "$json_text \n \n $json_hex");
}

sub addNew{
  my $c = shift;
  my $encr_data;
  my $encr_aeskey;
  my $decr_data;
  my $decr_aeskey;

  unless ($redis->exists('keys')){
    $c->app->log->debug('RSA Keys for node not found, creating new ones.');

    my ($pubkey, $privkey) = &gen_rsa_keys();
    $c->app->log->debug("Public key: \n $pubkey \n Private key: \n $privkey");

    # Adding the keys to the redis database encoded as JSON
    $redis->hset('keys', 'pubkey', $pubkey);
    $redis->hset('keys', 'privkey', $privkey);
  }

  $encr_data = $c->req->body_params->param('data');
  $encr_aeskey = $c->req->body_params->param('aeskey');

  unless ($encr_data) {
    $c->render(json => {
      "error" => "No data received.",
      "status" => 400
    }, status => 400);
    return;
  }

  unless ($encr_aeskey) {
    $c->render(json => {
      "error" => "No AES key received.",
      "status" => 400
    }, status => 400);
    return;
  }


  # Getting the node private key
  my $node_privkey_string = $redis->hget('keys', 'privkey');
  my $node_privkey = Crypt::OpenSSL::RSA->new_private_key($node_privkey_string);
  $node_privkey->use_pkcs1_padding();

  # Decrypting the aes key
  my $decr_aeskey_string = $node_privkey->decrypt(decode_base64($encr_aeskey));
  my $decr_aeskey = Crypt::Cipher::AES->new($decr_aeskey_string);

  # Decrypting the data and converting from json to a hash
  my $decr_data_string = $decr_aeskey->decrypt(decode_base64($encr_data));

  $c->render(text => "$decr_data_string");
  return;
  my $decr_data = decode_json $decr_data_string;

  # Checking if posted UUID is generated from node and if it already exists
  my $uuid = $decr_data->{uuid};
  unless ($uuid){
    $c->app->log->debug("NO UUID SENT");
    $c->render(json => {
      "error" => "No UUID received.",
      "status" => 400
    }, status => 400);
  }

  unless ($redis->sismember(REDIS_GEN_UUIDS_KEY, $uuid)){
    $c->render(json => {
      "error" => "Invalid or expired UUID.",
      "status" => 400
    },status => 400);
  }

  if($redis->sismember(REDIS_UUIDS_KEY, $uuid)){
    $c->render(json => {
      "error" => "UUID already exists.",
      "status" => 400
    },status => 400);
  }

  # If no errors removes the UUID from the generated and adds it to the device UUIDS
  $redis->srem(REDIS_GEN_UUIDS_KEY, $uuid);
  $redis->sadd(REDIS_UUIDS_KEY, $uuid);

  my $message = (
    "status" => "OK",
    "uuid" => $uuid
  );

  $c->app->log->debug("New device UUID registered!: $uuid");

  $c->render(json => $message, status => 418);
}

sub get_hosts{
  ("127.0.0.1", "10.10.40.174", "google.com");
}

sub test{
  my $c = shift;
  my $key = Crypt::CBC->random_bytes(16);
  my $iv = Crypt::CBC->random_bytes(16);
  my $cipher = 'Cipher::AES';
  my $header = 'none';
  my %settings = (key    => "$key",
                  key_base64 => encode_base64($key),
                  iv     => "$iv",
                  iv_base64 => encode_base64($iv),
                  cipher => "$cipher",
                  header => "$header");
  my $cipher = Crypt::CBC->new(\%settings);
  my $text = 'test';
  my $encr_text = $cipher->encrypt($text);
  my $decr_text = $cipher->decrypt($encr_text);

  $c->render(json => {
    settings => \%settings,
    encr_text => $encr_text,
    text => $text,
    encr_text_base64 => encode_base64($encr_text),
    decr_text => $decr_text
  });

}
