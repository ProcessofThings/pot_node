package PotNode::Controller::Message;
use Mojo::Base 'Mojolicious::Controller';
use PotNode::EncryptedRequest;
use PotNode::EncryptedResponse;
use PotNode::MessageService;

sub send {
  my $c = shift;
  my $req = PotNode::EncryptedRequest->new(

  )
  my $sender = $req->{sender};
  my $receiver = $req->{receiver};
  my $message = $req->{message};

  unless ($sender && $receiver && $message)
    return $c->render(json => { error: "Invalid request" }, status => 400);

  MessageService::send($sender, $receiver, $message);

  $c->render(text => "OK");
}

sub get {
  my $c = shift;
}

sub listen {

}

1;
