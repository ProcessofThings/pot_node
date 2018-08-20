package PotNode;
use Mojo::Base 'Mojolicious';
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Alien::SwaggerUI;
use AnyEvent::HTTP;
# This method will run once at server start
sub startup {
  my $self = shift;
  my $redis = Mojo::Redis2->new;
  my $uanb = Mojo::UserAgent->new;
  my $msg_srv = PotNode::Messaging::Service->new;
  # Load configuration from hash returned by "my_app.conf"
  my $config = $self->plugin('Config');

  # Documentation browser under "/perldoc"
  $self->plugin('PODRenderer') if $config->{perldoc};
  $self->plugin('PotNode::Helpers');
  $self->plugin('PotNode::Encryption::Helpers');
  $self->plugin('DebugDumperHelper');
  $self->plugin('Crypto');
  $self->plugin(OpenAPI => {spec => $self->static->file("v1apimultichain.json")->path});
  $self->mode('development');

  $self->log->path('/home/node/log/pot_node.log');

#  $self->secrets(['23898afh2k34ljglkashjdfoul2by34abdlfjh;lqademjbp32b4foasduyfhapsdfknh','29g927gjahsfdskjhgkbcnqi0akjsdh9ubkjsdldfjwkljhdlkfjowlskdflksdhf']);
  $self->app->sessions->cookie_name('potnode-763248762384');
  $self->app->sessions->default_expiration('3600');
#  $self->app->renderer->cache->max_keys(0);

  # Router
  my $r = $self->routes;

  # Normal route to controller

  $r->websocket('/ws')->to('start#ws');
  $r->websocket('/wsapi')->to('api#wsapi');
  #Public Functions

  $r->get('/node/join')->to('node#join')->name('node');
  $r->get('/node/alive')->to('node#alive')->name('node');

  $r->get('/ipfs/:ipfs')->to('public#load');

  my $auth = $r->under ( sub {
    my $c = shift;
    return 1 if $c->tx->local_port eq '9090';
    $c->app->log->debug("Requested Port 9090 Not Allowed ");
    return undef;
  });

  my $authPublic = $r->under ( sub {
    my $c = shift;
    return 1 if $c->tx->local_port eq '9080';
    $c->app->log->debug("Requested Port Not Allowed ");
    return undef;
  });

  # Starting IPFS PubSub listeners for buffered messages
  my $cursor_messages = $self->scan(0, MATCH => 'messages_*');
  while (my $r = $cursor_messages->next) {
    my @results = @$r;
    for my $result (@results){
      my $pubid = substr $result, 10;
      $msg_srv->subscribe(PotNode::Messaging::Device->new(pubid => $pubid));
    }
  }

  my $cursor_contacts = $self->scan(0, MATCH => 'new_contacts_*');
  while (my $r = $cursor_contacts->next) {
    my @results = @$r;
    for my $result (@results){
      my $pubid = substr $result, 13;
      $msg_srv->subscribe(PotNode::Messaging::Device->new(pubid => $pubid));
    }
  }

  my $cursor_contact_info = $self->scan(0, MATCH => 'new_contact_info_*');
  while (my $r = $cursor_contact_info->next) {
    my @results = @$r;
    for my $result (@results){
      my $pubid = substr $result, 17;
      $msg_srv->subscribe(PotNode::Messaging::Device->new(pubid => $pubid));
    }
  }


  # These functions can only be access thought the local lan or via ssh tunnel from your computer
  # SSH Tunnel - ssh ipaddress -l username -L 9090:127.0.0.1:9090

  $auth->get('/system/check')->to('system#check');
  $auth->any('/system/alertnotify')->to('system#alertnotify');

  # These are system functions that are required by various API and Web Interfaces

  $auth->get('/setup')->to('system#start');
  $auth->any(['GET', 'POST'] => '/setup/createchain')->to('system#createchain');
  $auth->get('/setup/:html')->to('system#start');
  $auth->get('/genqrcode')->to('system#genqrcode');  # Generates QRCode VIA API
  $auth->get('/genqrcode64')->to('system#genqrcode64');  #Generates Base64 QRCode pushing to websites

  $auth->get('/swagger/*path')->to('explore#swagger')->name('path');
  $auth->get('/explore')->to('explore#redirect');
  $auth->get('/explore/blockchain')->to('explore#blockchain');
  $auth->get('/explore/api')->to('explore#api');
  $auth->get('/explore/:page')->to('explore#load');
  $auth->get('/explore/set/:id')->to('explore#set');
  $auth->any(['GET', 'POST'] => '/explore/:method/:params')->to('explore#method');

  $auth->get('/developer')->to('developer#redirect');
  $auth->get('/developer/blockchain')->to('developer#blockchain');
  $auth->get('/developer/:page')->to('developer#load');
  $auth->get('/developer/set/:id')->to('developer#set');
  $auth->get('/developer/images/*')->to('developer#assets');
  $auth->get('/developer/assets/*')->to('developer#assets');
  $auth->get('/developer/app/:page')->to('developer#loadApp');
  $auth->get('/developer/app/assets/*')->to('developer#assets');
  $auth->post('/developer/api/createApp')->to('developer#createApp');

  $auth->get('/device/new')->to('device#genInvite');
  $auth->post('/device/invite')->to('device#genDeviceInvite');
  $auth->post('/device/new')->to('device#addNew');
  $auth->post('/device/genqrcode')->to('device#genqrcode');

  $auth->post('/device/messages/subscribe')->to('messaging#subscribe');
  $auth->post('/device/messages/send')->to('messaging#send_msg');
  $auth->post('/device/messages/new_contact')->to('messaging#new_contact');
  $auth->post('/device/messages/new_contact_info')->to('messaging#new_contact_info');
  $auth->post('/device/messages/get')->to('messaging#get_new');
  $auth->post('/device/messages/move')->to('messaging#move');

  $auth->post('/code')->to('testing#code');

  $auth->get('/nav')->to('private#api');
  $auth->get('/')->to('private#redirect');
  $auth->get('/assets/*')->to('private#assets');
  $auth->get('/:page')->to('private#load');
}

1;
