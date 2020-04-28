package TouchPortal::Socket;

our $VERSION = '1.0.0';

use Spdermn02::Logger qw( logIt );
use feature 'say';
use IO::Socket::INET;
use JSON;

# exepct $options to be hash { 'plugin_id' => '<plugin id goes here>', 'run_dir' => '<directory were exe is running>'}
sub new {
    my $class   = shift;
    my $options = shift;

    my $defaults = { 'IP' => '127.0.0.1', 'plugin_id' => undef };

    my $self = { %$defaults, %$options, 'socket' => undef, 'PORT' => '12136' };

    $self->{'log'} = $self->{'run_dir'} . '\\' . $self->{'plugin_id'} . '.log';

    bless $self, $class;

    $self->_connect();

    $self->_pair();

    return $self;
}

sub _connect {
    my $self = shift;

    $self->{'socket'} = new IO::Socket::INET(
        PeerHost => $self->{'IP'},
        PeerPort => $self->{'PORT'},
        Proto    => 'tcp'
    );

    if ( !$self->{'socket'} ) {
        logIt( 'ERROR',
                'Unable to establish the socket connection IP='
              . $self->{'IP'}
              . ' Port='
              . $self->{'PORT'} );

        exit 1;
    }
}

sub _send {
    my $self = shift;
    my $msg  = shift;

    my $send_msg = '';
    eval { $send_msg = encode_json($msg) };
    if ($@) {
        logIt( 'ERROR', 'Unable to encode msg as json = ' . $@ );
        return 0;
    }

    logIt( 'DEBUG', 'Sending: ' . $send_msg );
    my $rc = $self->_send_json( $send_msg);

    return $rc;
}

sub _send_json {
    my $self = shift;
    my ($send_msg) = @_;

    my $rc = $self->{'socket'}->send( $send_msg . "\n" );

    return $rc;
}

sub _pair {
    my $self = shift;

    my $pairMsg = {
        'type' => 'pair',
        'id'   => $self->{'plugin_id'}
    };

    return $self->_send($pairMsg);
}

sub choice_update {
    my $self = shift;
    my ( $id, $valArray ) = @_;

    if ( ref $valArray ne ref [] ) {
        logIt( 'ERROR', 'valArray passed in is not an array' );
        return 0;
    }

# Adding in the ''. to make sure it's a string going back, perl is finicky about that
    my $msg = {
        'type'  => 'choiceUpdate',
        'id'    => '' . $id,
        'value' => $valArray
    };

    return $self->_send($msg);

}

sub state_update {
    my $self = shift;
    my ( $id, $value ) = @_;

    if ( ref $value ne ref 'SCALAR' ) {
        logIt( 'ERROR', 'value passed in is not a scalar' );
        return 0;
    }

# Adding in the ''. to make sure it's a string going back, perl is finicky about that
    my $msg = {
        'type'  => 'stateUpdate',
        'id'    => '' . $id,
        'value' => '' . $value
    };

    return $self->_send($msg);

}

sub state_update_array {
    my $self = shift;
    my ( $stateArray ) = @_;

    my @stateJsonArray = ();

    foreach my $state ( @$stateArray ) {
        my $msg = {
        'type'  => 'stateUpdate',
        'id'    => '' . $state->{id},
        'value' => '' . $state->{value}
        };

        push @stateJsonArray, encode_json($msg);
    }

    $self->_send_json(join("\n",@stateJsonArray));

}

# for the future when I implement Actions
# to possibly configure the plugin through TP
sub read {

}
