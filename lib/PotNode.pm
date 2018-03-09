package PotNode;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
  my $self = shift;

  # Load configuration from hash returned by "my_app.conf"
  my $config = $self->plugin('Config');

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer') if $config->{perldoc};
  $self->plugin('PotNode::Helpers');
  
  $self->log->path('/home/node/log/pot_node.log');
  
  Mojo::IOLoop->recurring(60 => sub {
    use Mojo::UserAgent;
    ## recurring events
    my $loop = shift;
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
        ## gets all process with exact match
        $command = 'pgrep -f "^multichaind '.$entry.' -daemon$"';
        $process_chk_command = qx/$command/;
        ## Removes any \n\r
        $process_chk_command =~ s/\R//g;
        if ($process_chk_command ne '') {
            $self->app->log->debug("Running Process : $process_chk_command");
        } else {
            ## launched the daemon using > /dev/null & to return control to mojolicious
            $command = "multichaind $entry -daemon > /dev/null &";
            system($command);
            $self->app->log->debug("Starting : $entry");
        }
    }
    closedir $DIR;
    
    $command = 'ipfs add -r -w -Q /home/node/pot_node';
    my $value = qx/$command/;
    $value =~ s/\R//g;
    $self->app->log->debug("pot_node Hash : $value");
    #my $res = $ua->get("http://127.0.0.1:5001/api/v0/pubsub/sub?arg=$value&discover=\1");
    #$self->app->dumper($res);
  });

  # Router
  my $r = $self->routes;

  # Normal route to controller

  $r->websocket('/ws')->to('start#ws');
  $r->get('/')->to('start#setup');
  
  # These are system functions that are required by various API and Web Interfaces
  $r->get('/setup')->to('system#start');
  $r->any(['GET', 'POST'] => '/setup/createchain')->to('system#createchain');
  $r->get('/setup/:html')->to('system#start');
  $r->get('/genqrcode')->to('system#genqrcode');  # Generates QRCode VIA API
  $r->get('/genqrcode64')->to('system#genqrcode64');  #Generates Base64 QRCode pushing to websites

  
}

1;
