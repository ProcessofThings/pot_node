package PotNode::Controller::Device;
use PotNode::EncryptedRequest;
use PotNode::EncryptedResponse;
use PotNode::InviteService;
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
use Try::Tiny;

use constant REDIS_GEN_UUIDS_KEY => 'generated_uuids';
use constant REDIS_UUIDS_KEY => 'device_uuids';
use constant AES_BYTES => 16;
use constant RSA_BITS => 1024;

my $redis = Mojo::Redis2->new;
my $uuid = Data::UUID->new;
my $date = Mojo::Date->new;

# PINGING SUBROUTINES

sub ping_aes{
  my $c = shift;
  my $req = $c->req->json;

  my $inv = new PotNode::InviteService->gen_new('');
  $c->render(text => $inv);
}

sub ping_reset{
  my $c = shift;
  my $now = time();
  $redis->set("ping_time", $now);
  $redis->set("ping_received", 0);
  $c->res->headers->header('Access-Control-Allow-Origin' => '*');
  $c->res->headers->header('Access-Control-Allow-Headers' => '*');
  $c->render(json => {
    "msg" => "OK"
  });
}

sub ping_aes_dec{
  my $c = shift;
}

sub ping{
  my $c = shift;
  my $req;
  my $encr_data;
  my $encr_aeskey;
  my $decr_data;
  my $decr_aeskey_string;
  my $iv;
  my $node_keys;
  my $dev_pubkey;

  $req = $c->req->json;
  $encr_data = $req->{data};
  $dev_pubkey = $req->{pubkey};
  $encr_aeskey = $req->{aeskey};
  $iv = $req->{iv};

  my %error = &check_req($req);
  if (&check_req($req)){
    $c->render(json => \%error, status => 400);
    return;
  }

  $c->redis_rsa_keys();

  # Getting the node private key
  my $node_privkey_string = $redis->hget('keys', 'privkey');

  # Decrypting the aes key
  my $decr_aeskey_string = $c->rsa_decrypt($encr_aeskey, $node_privkey_string);

  # Decrypting the data and converting from json to a hash
  my $decr_data_string = &aes_decrypt($encr_data, $decr_aeskey_string, $iv);
  my $decr_data = $decr_data_string;

  ###### ENCRYPTING DATA AGAIN
  my ($encr_data, $new_aes_key, $new_iv) = aes_encrypt($decr_data);
  my $node_pubkey = $redis->hget('keys', 'pubkey');
  $dev_pubkey = "-----BEGIN PUBLIC KEY-----\n".$dev_pubkey."-----END PUBLIC KEY-----";
  my $dev_pubkey = Crypt::OpenSSL::RSA->new_public_key($dev_pubkey);
  $dev_pubkey->use_pkcs1_padding();
  $new_aes_key = encode_base64 $new_aes_key;
  $new_aes_key = encode_base64 $dev_pubkey->encrypt($new_aes_key);

  # my $a;
  # $a = $c->genqrcode64($new_aes_key);

  $c->render(json => {
    data => $encr_data,
    aeskey => $new_aes_key,
    iv => encode_base64($new_iv),
    pubkey => $node_pubkey
  });
}

sub pingjs{
  my $c = shift;
  my $req;
  my $encr_data;
  my $encr_aeskey;
  my $decr_data;
  my $decr_aeskey_string;
  my $iv;
  my $node_keys;
  my $dev_pubkey;

  $req = $c->req->json;
  $encr_data = $req->{data};
  $dev_pubkey = $req->{pubkey};
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

  unless ($dev_pubkey) {
    $c->render(json => {
      "error" => "No RSA public key received.",
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
  my $decr_data = $decr_data_string;

  ###### ENCRYPTING DATA AGAIN
  my ($encr_data, $new_aes_key, $new_iv) = aes_encrypt($decr_data);
  my $node_pubkey = $redis->hget('keys', 'pubkey');
  # $dev_pubkey = "-----BEGIN PUBLIC KEY-----\n".$dev_pubkey."-----END PUBLIC KEY-----";
  my $dev_pubkey = Crypt::OpenSSL::RSA->new_public_key($dev_pubkey);
  $dev_pubkey->use_pkcs1_padding();
  $new_aes_key = encode_base64 $new_aes_key;
  $new_aes_key = encode_base64 $dev_pubkey->encrypt($new_aes_key);

  # my $a;
  # $a = $c->genqrcode64($new_aes_key);

  $c->res->headers->header('Access-Control-Allow-Origin' => '*');
  $c->render(json => {
    data => $encr_data,
    aeskey => $new_aes_key,
    iv => encode_base64($new_iv),
    pubkey => $node_pubkey
  });
  $redis->incr("ping_received");
  my $elapsed = time() - ($redis->get("ping_time"));
  $c->app->log->debug("--- ".$elapsed." SECONDS ELAPSED ---");
  my $received = $redis->get("ping_received");
  my $per_min = ($received/$elapsed)*60;
  $c->app->log->debug("--- ".$per_min." REQUESTS PER MIN ---");
}

sub genNew{
  my $c = shift;
  my $node_pubkey;
  my $gen_uuid;
  my $host = "10.10.40.174:9090/device/new";
  my $qr_result;

  &redis_rsa_keys();

  # Getting the node public key from redis
  $node_pubkey = $redis->hget('keys', 'pubkey');

  # Generating UUID
  $gen_uuid = $c->uuid();
  $redis->sadd(REDIS_GEN_UUIDS_KEY, $gen_uuid);

  # Removing the header and footer of the node pubkey
  $node_pubkey =~ s/^(.*\n){1}//;
  $node_pubkey =~ s/(.*\n){1}$//;

  # Adding the host
  $qr_result = $gen_uuid.$node_pubkey.$host;
  $qr_result =~ s/\n//g;

  # Adding the hash
  $qr_result = pothash($qr_result).$qr_result;

  # Generating the qr code
  my $data = $c->genqrcode64($qr_result);

  $c->render(json => $data, status => 200);
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

  # unless ($encr_data) {
  #   $c->render(json => {
  #     "error" => "No data received.",
  #     "status" => 400
  #   }, status => 400);
  #   return;
  # }
  #
  # unless ($encr_aeskey) {
  #   $c->render(json => {
  #     "error" => "No AES key received.",
  #     "status" => 400
  #   }, status => 400);
  #   return;
  # }
  #
  # unless ($iv) {
  #   $c->render(json => {
  #     "error" => "No init vector received.",
  #     "status" => 400
  #   }, status => 400);
  #   return;
  # }

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

sub aes_encryptt{
  my $raw_data = shift;
  my $bytes = shift || AES_BYTES;
  my $c = shift;
  my $key = Crypt::CBC->random_bytes($bytes);
  my $iv = Crypt::CBC->random_bytes($bytes);
  my %settings = (key    => "$key",
                  iv     => "$iv",
                  cipher => "Cipher::AES",
                  header => "none",
                  literal_key => 1,
                  keysize => $bytes);

  my $cipher = Crypt::CBC->new(\%settings);
  my $encr_data = encode_base64 $cipher->encrypt($raw_data);
  ($encr_data, $key, $iv);
}

sub aes_decryptt{
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

sub check_req{
  my $req = shift;

  my $encr_data = $req->{data};
  my $dev_pubkey = $req->{pubkey};
  my $encr_aeskey = $req->{aeskey};
  my $iv = $req->{iv};

  unless ($encr_data) {
    return (
      "error" => "No data received.",
      "status" => 400
    );
  }

  unless ($encr_aeskey) {
    return (
      "error" => "No AES key received.",
      "status" => 400
    );
  }

  unless ($iv) {
    return (
      "error" => "No init vector received.",
      "status" => 400
    );
  }

  unless ($dev_pubkey) {
    return (
      "error" => "No RSA public key received.",
      "status" => 400
    );
  }

  0;
}
