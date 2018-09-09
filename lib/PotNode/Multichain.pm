package PotNode::Multichain;
use Mojo::Base -base;

use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::Util qw/monkey_patch decode/;
use Data::Dumper;

use Carp qw/croak/;

has ioloop  => sub { Mojo::IOLoop->singleton };
has ua      => sub { Mojo::UserAgent->new };
has url     => sub { "localhost:8332" };
has account => "";
has id      => 0;

sub new {
  my $self = shift->SUPER::new( @_ );

  # Tune JSON-RPC connection for minimum latency
  $self->ua->max_redirects( 0 )->connect_timeout( 3 )->request_timeout( 5 );

  return $self;
}

# Multichain nodeversion : 10003901, protocolversion : 10009 or <

my @methods = qw/
  getbestblockhash
  getblock
  getblockchaininfo
  getblockcount
  getblockhash
  getchaintips
  getdifficulty
  getmempoolinfo
  getrawmempool
  gettxout
  gettxoutsetinfo
  listassets
  listblocks
  listpermissions
  liststreams
  listupgrades
  verifychain

  clearmempool
  getblockchainparams
  getinfo
  getruntimeparams
  pause
  resume
  setlastblock
  setruntimeparam
  stop

  generate
  gethashespersec
  setgenerate

  getblocktemplate
  getmininginfo
  getnetworkhashps
  prioritisetransaction
  submitblock

  addnode
  getaddednodeinfo
  getconnectioncount
  getnettotals
  getnetworkinfo
  getpeerinfo
  ping

  appendrawchange
  appendrawdata
  appendrawtransaction
  createrawtransaction
  decoderawtransaction
  decodescript
  getrawtransaction
  sendrawtransaction
  signrawtransaction

  createkeypairs
  createmultisig
  estimatefee
  estimatepriority
  validateaddress
  verifymessage

  addmultisigaddress
  appendrawexchange
  approvefrom
  backupwallet
  combineunspent
  completerawexchange
  create
  createfrom
  createrawexchange
  createrawsendfrom
  decoderawexchange
  disablerawtransaction
  dumpprivkey
  dumpwallet
  encryptwallet
  getaccount
  getaccountaddress
  getaddressbalances
  getaddresses
  getaddressesbyaccount
  getaddresstransaction
  getassetbalances
  getassettransaction
  getbalance
  getnewaddress
  getrawchangeaddress
  getreceivedbyaccount
  getreceivedbyaddress
  getstreamitem
  gettotalbalances
  gettransaction
  gettxoutdata
  getunconfirmedbalance
  getwalletinfo
  getwallettransaction
  grant
  grantfrom
  grantwithdata
  grantwithdatafrom
  importaddress
  importprivkey
  importwallet
  issue
  issuefrom
  issuemore
  issuemorefrom
  keypoolrefill
  listaccounts
  listaddresses
  listaddressgroupings
  listassettransactions
  listlockunspent
  listreceivedbyaccount
  listreceivedbyaddress
  listsinceblock
  liststreamblockitems
  liststreamitems
  liststreamkeyitems
  liststreamkeys
  liststreampublisheritems
  liststreampublishers
  listtransactions
  listunspent
  listwallettransactions
  lockunspent
  move
  preparelockunspent
  preparelockunspentfrom
  publish
  publishfrom
  resendwallettransactions
  revoke
  revokefrom
  send
  sendasset
  sendassetfrom
  sendfrom
  sendfromaccount
  sendmany
  sendwithdata
  sendwithdatafrom
  setaccount
  settxfee
  signmessage
  subscribe
  unsubscribe
/;

for my $method ( @methods ) {
  monkey_patch __PACKAGE__, lc $method => sub {
    return shift->_call( $method => @_ )
  };
}

sub _call {
  my ( $self, $method, $params, $cb ) = @_;

  $self->id( $self->id + 1 );

  my $headers = { Content_Type => 'application/json' };

  my $body = encode_json {
    id => $self->id, method => $method, params => $params
  };

  if ( $cb ) {
    $self->ioloop->delay->steps(
      sub {
        my ( $delay ) = @_;

        $self->ua->post( $self->url, $headers, $body => $delay->begin );
      },

      sub {
        my ( $delay, $tx ) = @_;

        return $cb->( $self, undef, $tx->res->json ) if $tx->success;

        return $cb->( $self, $self->_error( $method, $tx ) );
      }
    );
  }

  else {
    print Dumper($body);
    my $tx = $self->ua->post( $self->url, $headers, $body );

    return $tx->res->json if $tx->success;

    return $self->_error( $method, $tx );
#		return $tx->res->json;
  }
}

sub _error {
  my ( $self, $method, $tx ) = @_;
  $tx->error->{message} = decode 'UTF-8', $tx->error->{message};

  if ( $tx->error->{code} ) {
		my $errormessage = decode_json($tx->res->body);
    my $format = "%s HTTP error: %s %s";
#    my @values = ( $method, @{ $tx->error }{ qw/code message/ } );
		my @values = (400,$errormessage->{error}->{message} );
    return sprintf $format, @values;
  }

  else {
    my $format = "%s connection error: %s";
    my @values = ( $method, $tx->error->{message} );

    return sprintf $format, @values;
  }
}


1;
