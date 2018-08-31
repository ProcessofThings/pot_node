package PotNode::Controller::Dapp;
use PotNode::Encryption::EncryptedRequest;
use PotNode::Encryption::EncryptedResponse;
use PotNode::Encryption::Helpers;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Redis2;
use Mojo::JSON qw(decode_json encode_json);
use MIME::Base64;

use Data::Dumper;

use constant 'REDIS_GEN_UUIDS_KEY' => 'generated_uuids';
use constant 'DAPP_ARCHIVE_EXTENSION' => 'zip';

my $redis = Mojo::Redis2->new;
my $encr = PotNode::Encryption::Helpers->new;

sub get_files{
  my $c = shift;
  my $error;

  my $req = $c->req->json;
  my $dev_pubkey = $req->{pubkey};

  $req = PotNode::Encryption::EncryptedRequest->new(req => $req);

  return $c->render(json => { error => $req->error }, status => 401)
  if $req->error;

  my $decr_data;
  eval { $decr_data = decode_json $req->decr_data; }
  or return $c->render(json => { error => "Decryption error" }, status => 500);

  my $dapp_uuid = $decr_data->{dapp_uuid};
  my $aeskey = $decr_data->{aeskey};
  my $iv = $decr_data->{iv};

  return $c->render(json => { error => "Invalid request" }, status => 400)
  unless ($dapp_uuid && $aeskey && $iv);

  my $dapps_dir = $c->config->{dev};

  unless (-d "$dapps_dir/$dapp_uuid"){
    return $c->render(json => { error => "No files for this dapp." }, status => 500);
  }

  my $zip_file_path = "$dapps_dir/$dapp_uuid.zip";

  $c->zip($dapps_dir, $dapp_uuid, $zip_file_path);

  my $encr_zip_file_path = "$dapps_dir/_$dapp_uuid.zip";

  $encr->aes_encrypt_file($zip_file_path, $encr_zip_file_path, 0, $aeskey, $iv);
  $c->render_file(filepath => $encr_zip_file_path);
}

1;
