package PotNode;
use Mojo::Base 'Mojolicious';
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

# This method will run once at server start
sub startup {
  my $self = shift;
  my $redis = Mojo::Redis2->new;
  my $uanb = Mojo::UserAgent->new;

  # Load configuration from hash returned by "my_app.conf"
  my $config = $self->plugin('Config');

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer') if $config->{perldoc};
  $self->plugin('PotNode::Helpers');
  $self->plugin('DebugDumperHelper');
  $self->plugin('Crypto');
  $self->mode('development');
  
  $self->log->path('/home/node/log/pot_node.log');

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
  $auth->get('/system/check')->to('system#check');
  $auth->any('/system/alertnotify')->to('system#alertnotify');

  # These are system functions that are required by various API and Web Interfaces

  $auth->get('/setup')->to('system#start');
  $auth->any(['GET', 'POST'] => '/setup/createchain')->to('system#createchain');
  $auth->get('/setup/:html')->to('system#start');
  $auth->get('/genqrcode')->to('system#genqrcode');  # Generates QRCode VIA API
  $auth->get('/genqrcode64')->to('system#genqrcode64');  #Generates Base64 QRCode pushing to websites
  
}

1;
