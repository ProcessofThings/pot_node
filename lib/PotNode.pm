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

  # Router
  my $r = $self->routes;

  # Normal route to controller

  $r->websocket('/ws')->to('start#ws');
  $r->get('/')->to('start#setup');
  
  # These are system functions that are required by various API and Web Interfaces
  $r->get('/setup')->to('system#start');
  $r->get('/genqrcode')->to('system#genqrcode');  # Generates QRCode VIA API
  $r->get('/genqrcode64')->to('system#genqrcode64');  #Generates Base64 QRCode pushing to websites

  
}

1;
