package PotNode::Helpers;
use base 'Mojolicious::Plugin';

sub register {

    my ($self, $app) = @_;

    $app->helper(mypluginhelper =>
            sub { return 'I am your helper and I live in a plugin!'; });

    $app->helper(redis => 
	    sub { shift->stash->{redis} ||= Mojo::Redis2->new; });

}

1;
