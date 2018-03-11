package PotNode;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;
  my $redis = Mojo::Redis2->new;

  # Load configuration from hash returned by "my_app.conf"
  my $config = $self->plugin('Config');

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer') if $config->{perldoc};
  $self->plugin('PotNode::Helpers');
  $self->mode('development');
  
  $self->log->path('/home/node/log/pot_node.log');
  
  Mojo::IOLoop->singleton->recurring(60 => sub {
    if (!$redis->exists("checkprocess")){
    $redis->set(checkprocess => "yes");
    use Mojo::UserAgent;
    ## recurring events
    my $loop = shift;
    $loop->max_connections(1);
    my $path = "/home/node/.multichain/";
    my $process_chk_command;
    my $command;
    $self->app->log->debug("Recurring : Checking");
    my $ua  = Mojo::UserAgent->new;

    ## Checks the multichain directory for any active blockchains and checks if the daemon is running
    opendir( my $DIR, $path );
    while ( my $entry = readdir $DIR ) {
        ## Finds all directories and filters out all directories apart from those that contain HEX 32 chars
        next unless -d $path . '/' . $entry;
        next if $entry eq '.' or $entry eq '..';
        next if $entry !~ m/^\w{32}$/;
        if ( -f '/home/node/run/'.$entry.'.pid') {
            $self->app->log->debug("Running Process : $entry");
        } else {
            ## launched the daemon using > /dev/null & to return control to mojolicious
            $command = "multichaind $entry -daemon -pid=/home/node/run/$entry.pid > /dev/null &";
            system($command);
            $self->app->log->debug("Starting : $entry");
        }
    }
    
    closedir $DIR;
    if (!$redis->exists("addpotnode")){
        $command = 'ipfs add -r -w -Q /home/node/pot_node';
        my $value = qx/$command/;
        $value =~ s/\R//g;
        $self->app->log->debug("pot_node Hash : $value");
        #my $res = $ua->get("http://127.0.0.1:5001/api/v0/pubsub/sub?arg=$value&discover=\1");
        #$self->app->dumper($res);
        $redis->setex('addpotnode',30, "yes");
    }

    $redis->del("checkprocess");
    }
  });

  # Router
  my $r = $self->routes;

  # Normal route to controller

  $r->websocket('/ws')->to('start#ws');
  #Public Functions
  
  $r->get('/node/join')->to('node#join')->name('node');
  $r->get('/node/alive')->to('node#alive')->name('node');
  
  my $auth = $r->under ( sub {
    my $c = shift;
    return 1 if $c->tx->local_port eq '9090';
    $c->app->log->debug("Requested Port Not Allowed ");
    return undef;
  });

  # These functions can only be access thought the local lan or via ssh tunnel from your computer
  # SSH Tunnel - ssh ipaddress -l username -L 9090:127.0.0.1:9090 
  
  $auth->get('/')->to('start#setup');

  # These are system functions that are required by various API and Web Interfaces

  $auth->get('/setup')->to('system#start');
  $auth->any(['GET', 'POST'] => '/setup/createchain')->to('system#createchain');
  $auth->get('/setup/:html')->to('system#start');
  $auth->get('/genqrcode')->to('system#genqrcode');  # Generates QRCode VIA API
  $auth->get('/genqrcode64')->to('system#genqrcode64');  #Generates Base64 QRCode pushing to websites
  
}

1;
