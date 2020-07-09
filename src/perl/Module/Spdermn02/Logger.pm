package Spdermn02::Logger;

use feature 'say';
use base qw( Exporter );
use Time::HiRes qw( gettimeofday );

our @EXPORT = qw( logIt );

use constant {
    START    => 0,
    SHUTDOWN => 0,
    FATAL    => 0,
    ERROR    => 1,
    WARN     => 2,
    DEBUG    => 3,
    INFO     => 4
};

my %errLevel = (
    'SHUTDOWN' => SHUTDOWN,
    'START'    => START,
    'FATAL'    => FATAL,
    'ERROR'    => ERROR,
    'WARN'     => WARN,
    'DEBUG'    => DEBUG,
    'INFO'     => INFO
);

our $level = ERROR;

sub _get_log_level {
    my $debugFile = $main::dir . '\.tpohm_debug_flag';
    if ( -f $debugFile ) {
        my $fh;
        if ( open( $fh, '<', $debugFile ) ) {
            $level = <$fh>;
            chomp($level);
            close $fh;
            return 0;
        }
    }

    #Default to ERROR
    $level = ERROR;
}

sub logIt {
    my ( $type, $msg ) = @_;

    _get_log_level();

    if ( $errLevel{$type} > $level ) {
        return 0;
    }

    my $logTime = _get_time();

    #say $self->{log}, "$curTime - [$type] $msg";
    say "$logTime - [$type] $msg";
}

sub _get_time {
    my ( $time, $usec ) = gettimeofday();
    chomp($usec);
    my ( $sec, $min, $hour, $mday, $month, $year ) =
      ( localtime($time) )[ 0 .. 5 ];

    return sprintf(
        "%04d-%02d-%02d %02d:%02d:%02d.%06d",
        $year + 1900,
        $month + 1, $mday, $hour, $min, $sec, $usec
    );
}

1;
