package PotNode::Controller::Publicnew;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::QRCode;
use Mojo::URL;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::IOLoop;
use Mojo::UserAgent;
use Mojo::Asset::File;
use Mojo::ByteStream 'b';
use Data::UUID;
use PotNode::Encryption::Helpers;
use Data::Dumper;
use PotNode::Multichain;
use Config::IniFiles;
use DBM::Deep;
use Devel::Size qw(total_size);
use Encode::Base58::GMP;
use File::Grep qw/ fgrep /;
use Mojo::Util qw(b64_decode b64_encode);
use Image::Scale;
use PotNode::VectorSpace;


# This action will render a template
  my $ua = Mojo::UserAgent->new;
  my $redis = Mojo::Redis2->new;
  
  

sub redirect {
    my $c = shift;
    $c->redirect_to('/main.html');
};

sub run {
  my $c = shift;
  my $run = $c->param('run');
  my $blockChainId = $c->param('blockChainId');
  my $container = $c->req->json;
  my $xurl = $c->req->headers->header('X-Url');
  my $xsession = $c->req->headers->header('X-Session');
  my $method = $c->req->method;
  my $message;
  my $dapp = $c->redis->get('url_'.$xurl);
  my ($ipfs,undef) = split(/:/, $dapp);
  my ($containerid,undef) = $c->uuid();
  my $config;
  my $outData;
  my $loadedfromcache = 'no';
  my $checkcache = 'no';

  $c->debug('RUN');

  if (!defined($container->{'containerid'})) {
    $c->debug("Containerid Not Found - Generating One");
    $container->{'containerid'} = $containerid;
  } else {
    $c->debug("Container ID Found : $container->{'containerid'}");
  }

  $c->debug("Run : $method : $run : $dapp : $xurl : $xsession : $ipfs");

  if (!$c->redis->exists($xurl.'_config_'.$ipfs)) {
    $c->debug("Config Loading");
    if (-d "/home/node/dev/$ipfs") {
      $c->debug('Loading Local');
      my $file = "/home/node/dev/$ipfs/config.json";
      $config = Mojo::Asset::File->new(path => $file);
      $config = decode_json($config->slurp);
    }
    else {
      $c->debug('Loading IPFS');
      my $base = "http://127.0.0.1:8080/ipfs/$ipfs/config.json";
      $config = $ua->get($base)->res->json;
    }
    $c->redis->setex($xurl.'_config_'.$ipfs,1800, encode_json($config));
  } else {
    $c->debug("Config Loaded from Redis");
    $config = decode_json($c->redis->get($xurl.'_config_'.$ipfs));
  }

  $c->debug($container);

  if (defined($config->{'streams'})) {
    foreach my $streamId (@{$config->{'streams'}}) {
      $c->debug("Creating Stream $streamId");
      $c->create_stream($blockChainId, $streamId);
    }
  }

  if (defined($config->{$run}->{run}->{'group'})) {
    foreach my $item (@{$config->{$run}->{'run'}->{'group'}}) {
      ## check cache, if exists load from cache
      ## if it does not exist ask $outData to be stored in cache
      if (defined($item->{'cache'})) {
        if ($item->{'cache'} eq 'check') {
          $c->debug("Check Cache GET");
          $checkcache = 'yes';
          if ($c->redis->exists('cache_'.$blockChainId.'_' . $item->{'stream'})) {
            $c->debug("Loading from cache : cache_".$blockChainId."_".$item->{'stream'});
            $outData = decode_json($c->redis->get('cache_'.$blockChainId.'_' . $item->{'stream'}));
            $loadedfromcache = 'yes';
          }
        }
      }

      ## if Index then build index based on what config file passes


      ## If api requested this allows the dapp to call the local public / helper functions

      if ((defined($item->{'api'})) && ($loadedfromcache eq 'no')) {
        $c->debug("$item->{'api'} : $item->{'stream'}");
        my $function = $item->{'api'};
        $c->debug("No Cache Loading from blockchain");
        if (defined($item->{'settings'})) {
          $outData->{'message'} = $c->$function($blockChainId, $item->{'stream'}, $item->{'settings'}, $container);
          if ($outData->{'message'}->{status} != 200) {
            $c->debug("Error Detected Exiting");
            last;
          }
        } else {
          $outData->{'data'} = $c->$function($blockChainId, $item->{'stream'}, $container);
        }
      }

      if (defined($item->{'microservice'})) {
        ##TODO : load javascript to process data
        $c->debug("Config Loading MicroService - None functional add code");
      }

      ## If no existing cache then we have already ran cache : check then store the $outData into redis

      if (($loadedfromcache eq 'no') && ($checkcache eq 'yes')) {
        $c->debug("cache create cache_".$blockChainId."_".$item->{'stream'});
        $c->redis->setex('cache_'.$blockChainId.'_' . $item->{'stream'}, 1800, encode_json($outData));
      }

      ## if cache is

      if (defined($item->{'cache'})) {
        $c->debug("cache detected");
        if ($item->{'cache'} eq 'delete') {
          $c->debug("cache delete cache_$item->{'stream'}");
          $c->redis->del('cache_'.$blockChainId.'_'.$item->{'stream'});
        }
      }
    }
  }
  $c->debug($config);
  $c->render(json => $outData, status => 200);
};

1;
