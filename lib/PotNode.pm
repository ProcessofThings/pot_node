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

  my $log = Mojo::Log->new(path => '/var/log/mojo.log', level => 'warn');
  
  Mojo::IOLoop->recurring(60 => sub {
    my $loop = shift;
    my $path = "/home/node/.multichain/";
    my $process_chk_command;
    my $command;
    my $startdaemon;
    my @daemon;
    $self->app->log->debug("Recurring : Checking");
    opendir( my $DIR, $path );
    while ( my $entry = readdir $DIR ) {
        next unless -d $path . '/' . $entry;
        next if $entry eq '.' or $entry eq '..';
        next if $entry !~ m/^\w{32}$/;
        $command = 'pgrep -f "^multichaind '.$entry.' -daemon$"';
        $process_chk_command = qx/$command/;
        $process_chk_command =~ s/\R//g;
        if ($process_chk_command ne '') {
            $self->app->log->debug("Running Process : $process_chk_command");
        } else {
            $command = "multichaind $entry -daemon > /dev/null &";
            system($command);
            $self->app->log->debug("Starting : $entry");
        }
    }
    closedir $DIR;
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
