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
use Digest::MD5 qw(md5_hex);

use constant REDIS_GEN_UUIDS_KEY => 'generated_uuids';
use constant REDIS_UUIDS_KEY => 'device_uuids';
use constant AES_BYTES => 16;
use constant RSA_BITS => 1024;

my $redis = Mojo::Redis2->new;
my $uuid = Data::UUID->new;

sub ping{
  my $c = shift;
  $c->render(text => "OK", status => 200);
}

sub genNew{
  my $c = shift;
  my $node_keys;
  my $node_pubkey;
  # my $gen_pubkey;
  # my $gen_privkey;
  my $gen_uuid;
  my $json;
  my $host = "10.10.40.174:9090/device/new";
  my @hosts;
  my $qr_result;

  &redis_rsa_keys();

  # Getting the node public key from redis
  $node_pubkey = $redis->hget('keys', 'pubkey');

  # Generating new RSA keys for the device
  # ($gen_pubkey, $gen_privkey) = &gen_rsa_keys();

  # Generating UUID
  $gen_uuid = $uuid->create_str();
  $redis->sadd(REDIS_GEN_UUIDS_KEY, $gen_uuid);

  # @hosts = &get_hosts();

  $node_pubkey =~ s/^(.*\n){1}//;
  $node_pubkey =~ s/(.*\n){1}$//;

  # # Encoding into json
  # $json = encode_json {
  #   uuid => $gen_uuid,
  #   genkeys => 'true',
  #   # pubkey => $gen_pubkey,
  #   # privkey => $gen_privkey,
  #   nodepubkey => $node_pubkey,
  #   hosts => \@hosts
  # };

  # # Converting json to hex
  # my $qr_result = &to_hex($json);

  $qr_result = $gen_uuid.$node_pubkey.$host;
  $qr_result =~ s/\n//g;
  $qr_result = pothash($qr_result).$qr_result;

  my $data = $c->genqrcode64($qr_result);
  my $image = $data->{image};
  my $content = "<img src=\"$image\"/>";
  # $c->render(template => 'new-device-qr');
  $c->render(text => $content);
}

sub addNew{
  my $c = shift;
  my $req;
  my $encr_data;
  my $encr_aeskey;
  my $decr_data;
  my $decr_aeskey_string;
  my $iv;

  $req = $c->req->json;
  $encr_data = $req->{data};
  $encr_aeskey = $req->{aeskey};
  $iv = $req->{iv};
  # my @log = @{$c->req->json};
  # $c->app->log->debug("getting: @log");

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

  unless ($iv) {
    $c->render(json => {
      "error" => "No init vector received.",
      "status" => 400
    }, status => 400);
    return;
  }

  &redis_rsa_keys();

  # Getting the node private key
  my $node_privkey_string = $redis->hget('keys', 'privkey');
  my $node_privkey = Crypt::OpenSSL::RSA->new_private_key($node_privkey_string);
  $node_privkey->use_pkcs1_padding();

  # Decrypting the aes key
  my $decr_aeskey_string = $node_privkey->decrypt(decode_base64($encr_aeskey));

  # Decrypting the data and converting from json to a hash
  my $decr_data_string = &aes_decrypt($encr_data, $decr_aeskey_string, $iv);
  my $decr_data = decode_json $decr_data_string;

  # Checking if posted UUID is generated from node and if it already exists
  my $uuid = $decr_data->{uuid};
  unless ($uuid){
    $c->app->log->debug("NO UUID SENT");
    $c->render(json => {
      "error" => "No UUID received.",
      "status" => 400
    }, status => 400);
    return;
  }

  if($redis->sismember(REDIS_UUIDS_KEY, $uuid)){
    $c->render(json => {
      "error" => "UUID already exists.",
      "status" => 400
    },status => 400);
    return;
  }

  unless ($redis->sismember(REDIS_GEN_UUIDS_KEY, $uuid)){
    $c->render(json => {
      "error" => "Invalid or expired UUID.",
      "status" => 400
    },status => 400);
    return;
  }

  # If no errors removes the UUID from the generated and adds it to the device UUIDS
  $redis->srem(REDIS_GEN_UUIDS_KEY, $uuid);
  $redis->sadd(REDIS_UUIDS_KEY, $uuid);

  my %message = (
    "status" => "OK",
    "uuid" => $uuid,
    "message" => "Connected to the node."
  );

  $c->app->log->debug("New device UUID registered!: $uuid");

  $c->res->headers->header('Content-Type' => 'application/json; charset=utf-8');

  $c->render(json => {
    "status" => "OK",
    "uuid" => $uuid,
    "message" => "Connected to the node."
  },status => 200);
}

sub get_hosts{
  ("http://10.10.40.174:9090/device/new");
}

sub aes_encrypt{
  my $raw_data = shift;
  my $bytes = shift || AES_BYTES;

  my $key = Crypt::CBC->random_bytes($bytes);
  my $iv = Crypt::CBC->random_bytes($bytes);
  my %settings = (key    => "$key",
                  iv     => "$iv",
                  cipher => "Cipher::AES",
                  header => "none",
                  padding => "standard",
                  literal_key => 1,
                  keysize => $bytes);

  my $cipher = Crypt::CBC->new(\%settings);
  encode_base64 $cipher->encrypt($raw_data);
}

sub aes_decrypt{
  my $encr_data = decode_base64 shift;
  my $key = decode_base64 shift;
  my $iv = decode_base64 shift;
  my $bytes = shift || AES_BYTES;

  my %settings = (key    => "$key",
                  iv     => "$iv",
                  cipher => "Cipher::AES",
                  header => "none",
                  padding => "standard",
                  literal_key => 1,
                  keysize => $bytes);

  my $cipher = Crypt::CBC->new(\%settings);
  $cipher->decrypt($encr_data);
}

sub gen_rsa_keys{
  my $bits = shift;
  $bits = RSA_BITS unless $bits;
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

sub redis_rsa_keys{
  unless ($redis->exists('keys')){
    my ($pubkey, $privkey) = &gen_rsa_keys();

    # Adding the keys to the redis database encoded as JSON
    $redis->hset('keys', 'pubkey', $pubkey);
    $redis->hset('keys', 'privkey', $privkey);
  }
}

sub to_hex{
  my $text = shift;
  Encode::_utf8_off ($text);
  my $hex = uc unpack "H*", $text;
  join ('', $hex =~ /(..)/g);
}

sub pothash{
  my $string = shift;
  # Getting a random part of a md5 hash
  substr(md5_hex($string), 3, 4);
}
