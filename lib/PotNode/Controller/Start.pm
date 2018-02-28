package PotNode::Controller::Start;
use Mojo::Base 'Mojolicious::Controller';

my $clients = {};

# This action will render a template
sub setup {
  my $c = shift;
 
#  $c->redis->set(foo => "42");
#  my $res = $c->redis->get("foo");

#  $c->app->log->debug("Res : $res");

  # Render template "example/welcome.html.ep" with message
  $c->render(msg => 'Welcome to the Mojolicious real-time web framework!');
}


sub ws {
    my $c = shift;
#    $c->kept_alive;
    $c->inactivity_timeout(60);
    $c->app->log->debug("Open Websocket");
    $c->app->log->debug(sprintf 'Client connected: %s', $c->tx);
    my $id = sprintf "%s", $c->tx;
    $clients->{$id} = $c->tx;

    $c->on(message => sub {
        	my ($self, $msg) = @_;

	        if ($msg eq '__ping__') {
                    $c->app->log->debug("Ping");
        	        my $wsconid = $c->tx->handshake->{'connection'};
		        $self->send({json => {
                    type => "pong",
                    msg => "__pong__"
                }});
                return undef;
        	}
        	
        	
        if ($msg eq 'start') {
#		my $ua  = Mojo::UserAgent->new;
            my $reginfo;
            my $junk;
            my $wsconid = $c->tx->handshake->{'connection'};
#		my $tx = $ua->get("http://mapidev.processofthings.io/wsreg" => {'session-key' => '2h98as9f2gkjagd892graosdhjfgpasdjfbg32h4fvlasdbfvlajsdflakjdsf32u4glasjdfbglasdvf928haskdfh'});
#		if (my $res = $tx->success) {
#			$reginfo = $res->json; 
#	 		if ($reginfo->{'uuid'}) {
#	        	       	my $qrcode = $reginfo->{'uuid'};
#	                	print "QRcode Text : $qrcode\n";
#			$cache->set("wscon_".$wsconid,$reginfo->{'sessionid'},1800);
#				$qrcode = $ua->get("http://mapidev.processofthings.io/genqrcode64?text=$qrcode&s=10")->result->json;	
#	                	qrpng (text => $qrcode, out => \$qrcode);
#				$qrcode = $qrcode->{'image'};
#				print "$qrcode\n";
#	                	$qrcode = b($qrcode)->b64_encode;
#	                	$self->send({json => {
#					type => "image",
#	                		image => $qrcode,
#					show => "yes",
#					elementid => "qrcode"
#	                	}});
            $self->send({json => {
                type => "text",
                show => "yes",
                elementid => "#title",
                text => "Please Scan the QRCode to activate this screen" 
            }});
        }
#		} else {
#	  		my $err = $tx->error;
#	  		die "$err->{code} response: $err->{message}" if $err->{code};
#	  		die "Connection error: $err->{message}";
#		}	
    });
    
    $c->on(finish => sub {
        $c->app->log->debug('Client disconnected');
        my $wsconid = $c->tx->handshake->{'connection'};
        $c->app->log->debug("Get connection id : $wsconid");

#        if ($cache->get("wscon_".$wsconid)) {
#                my $sessionid = $cache->get("wscon_".$wsconid);
#                $cache->delete("wscon_".$wsconid);
#                my $ua  = Mojo::UserAgent->new;
#                $ua->get("http://papi.apicomms.com/wsunreg/$sessionid");
#                print "Closing WS tidying up cache\n";
#        } else {
#                print "No Active Websocket connection\n";
#        }
        delete $clients->{$id};
    });

}

1;
