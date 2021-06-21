#!C:\Strawberry\bin\perl
use Data::Dumper;

use TouchPortal::Socket;
use Spdermn02::Logger qw( logIt );
use Spdermn02::Graph;
use Win32::OLE;
use Win32::OLE::Const;
use MIME::Base64 qw(encode_base64url encode_base64);
use JSON;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use Time::HiRes qw( usleep );

# Auto appends /n on the end of message, alternate to print "msg \n";
use feature 'say';
our $VERSION = '6.0.0';

our $dir = dirname( abs_path($0) );

our $debugLog = undef;
open $debugLog, '>', $dir . '\tp_ohm.log';
select $debugLog;
## Auto flush prints
$| = 1;

#print Dumper(@INC);

use constant {
    SEC_OF_DAY => 60 * 60 * 24,

    DEFAULT_INTERVAL => 2000,    #Default of 2000 ms for loop interval

    MILLI_to_MICRO => 1000,
    ONE_THOUSAND   => 1000,

    ID   => 'TPOpenHardwareMonitor',
    HOST => 'localhost',
};

# Flags for Interacting in WMI Queries
use constant wbemFlagReturnImmediately => 0x10;
use constant wbemFlagForwardOnly       => 0x20;

our ( $socket, $WMI );

#convert for use in usleep of microseconds
our $updateInterval = DEFAULT_INTERVAL * MILLI_to_MICRO;

our %sensor_config = load_sensor_config();
our $time          = time;

main();

exit 0;

sub recvHandler {
    my $data = shift;

    logIt( 'DEBUG', 'we received a message' . Dumper($data) );

    if ( $data->{type} eq 'settings' ) {
        processSettings( $data->{values} );
        return 1;
    }
    if ( $data->{type} eq 'info' ) {
        processSettings( $data->{settings} );
        run();
        return 1;
    }

    return 0;
}

sub processSettings {
    my $settings = shift;
    foreach my $setting ( @{$settings} ) {
        logIt( 'DEBUG', 'Processing setting ' . Dumper($setting) );
        if ( defined $setting->{'Update Interval In Seconds'} ) {
            $updateInterval =
              $setting->{'Update Interval In Seconds'} *
              ONE_THOUSAND *
              MILLI_to_MICRO;
            next;
        }

        # Bar Graph Colors
        if ( defined $setting->{'CPU 1 Load Bar Graph Color'} ) {
            _processColor( $sensor_config{'Load'}->{'CPU Total'}->{'ids'}->[2],
                'barGraphColor', $setting->{'CPU 1 Load Bar Graph Color'} );
            next;
        }
        if ( defined $setting->{'Memory Load Bar Graph Color'} ) {
            _processColor( $sensor_config{'Load'}->{'Memory'}->{'ids'}->[2],
                'barGraphColor', $setting->{'Memory Load Bar Graph Color'} );
            next;
        }
        if ( defined $setting->{'GPU Core Load Bar Graph Color'} ) {
            _processColor( $sensor_config{'Load'}->{'GPU Core'}->{'ids'}->[2],
                'barGraphColor', $setting->{'GPU Core Load Bar Graph Color'} );
            next;
        }

        # Gauge Needle Colors
        if ( defined $setting->{'CPU 1 Load Gauge Needle Color'} ) {
            _processColor( $sensor_config{'Load'}->{'CPU Total'}->{'ids'}->[3],
                'needleColor', $setting->{'CPU 1 Load Gauge Needle Color'} );
            next;
        }
        if ( defined $setting->{'Memory Load Gauge Needle Color'} ) {
            _processColor( $sensor_config{'Load'}->{'Memory'}->{'ids'}->[3],
                'needleColor', $setting->{'Memory Load Gauge Needle Color'} );
            next;
        }
        if ( defined $setting->{'GPU Core Load Gauge Needle Color'} ) {
            _processColor( $sensor_config{'Load'}->{'GPU Core'}->{'ids'}->[3],
                'needleColor', $setting->{'GPU Core Load Gauge Needle Color'} );
            next;
        }

        # Thresholds
        if ( defined $setting->{'CPU 1 Load Thresholds'} ) {
            _thresholdProcessor(
                $sensor_config{'Load'}->{'CPU Total'}->{'ids'}->[1],
                $setting->{'CPU 1 Load Thresholds'} );
            next;
        }
        if ( defined $setting->{'CPU 1 Temp Thresholds'} ) {
            _thresholdProcessor(
                $sensor_config{'Temperature'}->{'CPU Package'}->{'ids'}->[1],
                $setting->{'CPU 1 Temp Thresholds'} );
            next;
        }
        if ( defined $setting->{'Memory Load Thresholds'} ) {
            _thresholdProcessor(
                $sensor_config{'Load'}->{'Memory'}->{'ids'}->[1],
                $setting->{'Memory Load Thresholds'} );
            next;
        }
        if ( defined $setting->{'GPU Load Thresholds'} ) {
            _thresholdProcessor(
                $sensor_config{'Load'}->{'GPU Core'}->{'ids'}->[1],
                $setting->{'GPU Load Thresholds'} );
            next;
        }
        if ( defined $setting->{'GPU Load Thresholds'} ) {
            _thresholdProcessor(
                $sensor_config{'Load'}->{'GPU Memory'}->{'ids'}->[1],
                $setting->{'GPU Load Thresholds'} );
            next;
        }
        if ( defined $setting->{'GPU Temp Thresholds'} ) {
            _thresholdProcessor(
                $sensor_config{'Temperature'}->{'GPU Core'}->{'ids'}->[1],
                $setting->{'GPU Temp Thresholds'} );
            next;
        }
        if ( defined $setting->{'GPU Mem Temp Thresholds'} ) {
            _thresholdProcessor(
                $sensor_config{'Temperature'}->{'GPU Memory'}->{'ids'}->[1],
                $setting->{'GPU Mem Temp Thresholds'} );
            next;
        }
    }

    return 0;
}

sub _processColor {
    my ( $sensor, $cfgKey, $color ) = @_;

    my @rgb = map $_, unpack 'C*', pack 'H*', $color;

    $sensor->{cfg}->{$cfgKey} = \@rgb;

    print STDERR Dumper($sensor);

    return 0;
}

sub _thresholdProcessor {
    my ( $sensor, $thresholds ) = @_;

    my @newThresholds = ();

    my @thresholdAry = split( /\|/, $thresholds );
    foreach my $th (@thresholdAry) {
        my ( $value, $threshold ) = split( /\=/, $th );
        if ( $threshold eq 'default' ) {
            $sensor->{'default'} = $value;
            next;
        }
        push @newThresholds, { 'threshold' => $threshold, 'value' => $value };
    }

    $sensor->{'thresholds'} = \@newThresholds;

    return 0;
}

sub main {

    logIt( 'START', 'tp_ohm is starting up, and about to connect' );

    $socket = new TouchPortal::Socket(
        {
            'run_dir'     => $dir,
            'plugin_id'   => ID,
            'recvHandler' => \&recvHandler
        }
    );
    if ( !$socket ) {
        logIt( 'FATAL', 'Cannot create socket connection : $!' );
        return 0;
    }

    $socket->{loop}->loop_once(1);
}

sub run {
    if ( !connect_wmi() ) {
        logIt( 'FATAL', 'Unable to connect to WMI...' );
        return 0;
    }

    my $irc = $socket->state_update( 'tpohm_connected', 'Yes' );
    logIt( 'START', "Checking to see if we are connected" );

    #sit here and wait for stuff
    while (1) {

        if ( !defined $irc ) {    #|| !$socket->{'socket'}->connected() ) {
            logIt( 'WARN', 'Socket Disconnecting, ending infinite loop' );
            last;
        }

        _roll_log();

        if ( !get_sensor_data() ) {
            last;
        }

        usleep $updateInterval;
    }

    logIt( 'SHUTDOWN', 'tp_ohm is shutting down' );

    return 1;
}

sub connect_wmi {
    $WMI =
      Win32::OLE->GetObject(
        "winmgmts:\\\\" . HOST . "\\root\\OpenHardwareMonitor" );

    if ( !$WMI ) {
        return 0;
    }

    return 1;
}

sub get_hardware_data {
    my $hardwares = $WMI->ExecQuery( "SELECT * FROM Hardware",
        "WQL", wbemFlagReturnImmediately | wbemFlagForwardOnly );

    if ( !$hardwares ) {
        logIt( 'ERROR',
            'Unable to run query to get hardware data, quitting program' );
        return 0;
    }

    foreach my $hardware ( in $hardwares ) {
        logIt(
            'INFO',
            sprintf(
                "Name: %s Type: %s",
                $hardware->{Name}, $hardware->{HardwareType}
            )
        );
    }

    return 1;
}

sub get_sensor_data {
    my $sensors = $WMI->ExecQuery( "SELECT * FROM Sensor",
        "WQL", wbemFlagReturnImmediately | wbemFlagForwardOnly );

    if ( !$sensors ) {
        logIt( 'ERROR',
            'Unable to run query to get sensor data, quitting program' );
        return 0;
    }

    my @stateArray = ();

    my $count = 0;
    foreach my $sensor ( in $sensors) {
        my $type   = $sensor->{SensorType};
        my $name   = $sensor->{Name};
        my $value  = $sensor->{Value};
        my $parent = $sensor->{Parent};

        $name = _normalize_name_by_type( $type, $name );

        if (   defined $sensor_config{$type}
            && defined $sensor_config{$type}->{$name} )
        {
            logIt(
                'INFO',
                sprintf(
"GOOD: Sensor configured to be handled - Parent: %s Name: %s SensorType: %s Value: %s",
                    $parent, $name, $type, $value
                )
            );
            process_sensor( $type, $name, $value, \@stateArray );
            $count++;
        }
        else {
            logIt(
                'INFO',
                sprintf(
"Sensor Not configured to be handled - Parent: %s Name: %s SensorType: %s Value: %s",
                    $parent, $name, $type, $value
                )
            );

        }
    }

    if ($count) {
        my $rc = $socket->state_update_array( \@stateArray );
    }

    return 1;
}

sub process_sensor {
    my ( $type, $name, $value, $stateArray ) = @_;

    $sensor_info = $sensor_config{$type}->{$name};

    my $prevValue = $sensor_info->{prevValue} // '';
    my $curValue  = sprintf( "%.1f", $value );

    foreach my $id ( @{ $sensor_info->{ids} } ) {

        if ( $id->{type} eq "value" ) {
            if ( $curValue eq $prevValue ) {
                logIt(
                    'DEBUG',
                    sprintf(
"Value - Sensor %s value has not changed from %s will not send update for value",
                        $name, $prevValue
                    )
                );
                next;
            }
            my $useValue = sprintf( "%.1f", $value );

            push @$stateArray, { id => $id->{id}, value => $useValue };
        }
        elsif ( $id->{type} eq "threshold" ) {
            if ( $curValue eq $prevValue ) {
                logIt(
                    'DEBUG',
                    sprintf(
"Threshold - Sensor %s value has not changed from %s will not send update for threshold",
                        $name, $prevValue
                    )
                );
                next;
            }
            my $useValue = $id->{default};
            foreach my $threshold ( @{ $id->{thresholds} } ) {
                if ( int($value) >= int( $threshold->{threshold} ) ) {
                    $useValue = $threshold->{value};
                    last;
                }
            }

            push @$stateArray, { id => $id->{id}, value => $useValue };
        }
        elsif ( $id->{type} eq "bar_graph" ) {
            my $vals = $sensor_info->{values};
            if ( $#{$vals} == 127 ) {
                shift @$vals;
            }
            push @$vals, sprintf( "%.1f", $value );

            my $img = bar_graph( $id->{cfg}, $vals );
            chomp($img);

            my $imgB64 = encode_base64( $img, '' );

            chomp $imgB64;
            push @$stateArray, { id => $id->{id}, value => "${imgB64}" };
        }
        elsif ( $id->{type} eq "gauge" ) {
            if ( $curValue eq $prevValue ) {
                logIt(
                    'DEBUG',
                    sprintf(
"Gauge - Sensor %s value has not changed from %s will not send update for gauge",
                        $name, $prevValue
                    )
                );
                next;
            }
            my $img = gauge( $id->{cfg}, sprintf( "%.1f", $value ) );
            chomp($img);

            my $imgB64 = encode_base64( $img, '' );

            chomp $imgB64;
            push @$stateArray, { id => $id->{id}, value => "${imgB64}" };
        }
    }

    $sensor_info->{prevValue} = $curValue;
}

sub _normalize_name_by_type {
    my ( $type, $name ) = @_;
    my $origName = $name;

    #Handle AMD Package listed as Core #1 - #N by OHM - issue #4
    if ( $type eq 'Temperature' ) {
        if ( $name =~ /Core #[0-9]+ - #[0-9]+/ ) {
            $name = 'CPU Package';
        }
    }
    if ( $origName ne $name ) {
        logIt( 'INFO', "Normalizing name from $origName to $name" );
    }

    return $name;
}

sub _roll_log {

    my $curTime = time;
    if ( ( $curTime - $time ) / SEC_OF_DAY > 1 ) {
        close $debugLog;
        open $debugLog, '>', $dir . '\tpohm.log';
        logIt( 'WARN',
            'Cleaned Debug log due to 24 hour length timeframe for log rolling'
        );
        $time = $curTime;
    }

}

sub load_sensor_config {
    my %sensor_config = (
        'Load' => {
            'CPU Total' => {
                ids => [
                    { id => 'tpohm_cpu_total_load_val', type => 'value' },
                    {
                        id         => 'tpohm_cpu_total_load_status',
                        type       => 'threshold',
                        default    => "Low",
                        thresholds => [
                            { threshold => 85, value => "High" },
                            { threshold => 45, value => "Medium" }
                        ]
                    },
                    {
                        id   => 'tpohm_cpu_total_load_graph',
                        type => 'bar_graph',
                        cfg  => { 'barGraphColor' => [ 0, 0, 255 ] }
                    },
                    {
                        id   => 'tpohm_cpu_total_load_gauge',
                        type => 'gauge',
                        cfg  => { 'needleColor' => [ 0, 0, 255 ] }
                    }
                ],
                values => []
            },
            'Memory' => {
                ids => [
                    { id => 'tpohm_memory_load_val', type => 'value' },
                    {
                        id         => 'tpohm_memory_load_status',
                        type       => 'threshold',
                        default    => 'Low',
                        thresholds => [
                            { threshold => 85, value => "High" },
                            { threshold => 40, value => "Medium" }
                        ]
                    },
                    {
                        id   => 'tpohm_memory_load_graph',
                        type => 'bar_graph',
                        cfg  => { 'barGraphColor' => [ 0, 0, 255 ] }
                    },
                    {
                        id   => 'tpohm_memory_load_gauge',
                        type => 'gauge',
                        cfg  => { 'needleColor' => [ 0, 0, 255 ] }
                    }
                ],
                values => []
            },
            'CPU Core #1' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_1_load_val', type => 'value' }, ]
            },
            'CPU Core #2' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_2_load_val', type => 'value' }, ]
            },
            'CPU Core #3' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_3_load_val', type => 'value' }, ]
            },
            'CPU Core #4' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_4_load_val', type => 'value' }, ]
            },
            'CPU Core #5' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_5_load_val', type => 'value' }, ]
            },
            'CPU Core #6' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_6_load_val', type => 'value' }, ]
            },
            'CPU Core #7' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_7_load_val', type => 'value' }, ]
            },
            'CPU Core #8' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_8_load_val', type => 'value' }, ]
            },
            'CPU Core #9' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_9_load_val', type => 'value' }, ]
            },
            'CPU Core #10' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_10_load_val', type => 'value' }, ]
            },
            'CPU Core #11' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_11_load_val', type => 'value' }, ]
            },
            'CPU Core #12' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_12_load_val', type => 'value' }, ]
            },
            'CPU Core #13' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_13_load_val', type => 'value' }, ]
            },
            'CPU Core #14' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_14_load_val', type => 'value' }, ]
            },
            'CPU Core #15' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_15_load_val', type => 'value' }, ]
            },
            'CPU Core #16' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_16_load_val', type => 'value' }, ]
            },
            'GPU Core' => {
                ids => [
                    { id => 'tpohm_gpu_core_load_val', type => 'value' },
                    {
                        id         => 'tpohm_gpu_core_load_status',
                        type       => 'threshold',
                        default    => "Low",
                        thresholds => [
                            { threshold => 85, value => "High" },
                            { threshold => 45, value => "Medium" }
                        ]
                    },
                    {
                        id   => 'tpohm_gpu_core_load_graph',
                        type => 'bar_graph',
                        cfg  => { 'barGraphColor' => [ 0, 0, 255 ] }
                    },
                    {
                        id   => 'tpohm_gpu_core_load_gauge',
                        type => 'gauge',
                        cfg  => { 'needleColor' => [ 0, 0, 255 ] }
                    }
                ],
                values => []
            },
            'GPU Memory' => {
                ids => [
                    { id => 'tpohm_gpu_memory_load_val', type => 'value' },
                    {
                        id         => 'tpohm_gpu_memory_load_status',
                        type       => 'threshold',
                        default    => "Low",
                        thresholds => [
                            { threshold => 85, value => "High" },
                            { threshold => 40, value => "Medium" }
                        ]
                    }
                ]
            }
        },
        'Clock' => {
            'GPU Core' => {
                ids =>
                  [ { id => 'tpohm_gpu_core_clock_val', type => 'value' }, ]
            },
            'GPU Memory' => {
                ids =>
                  [ { id => 'tpohm_gpu_memory_clock_val', type => 'value' }, ]
            },
            'GPU Shader' => {
                ids =>
                  [ { id => 'tpohm_gpu_shader_clock_val', type => 'value' }, ]
            },
            'CPU Core #1' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_1_clock_val', type => 'value' }, ]
            },
            'CPU Core #2' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_2_clock_val', type => 'value' }, ]
            },
            'CPU Core #3' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_3_clock_val', type => 'value' }, ]
            },
            'CPU Core #4' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_4_clock_val', type => 'value' }, ]
            },
            'CPU Core #5' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_5_clock_val', type => 'value' }, ]
            },
            'CPU Core #6' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_6_clock_val', type => 'value' }, ]
            },
            'CPU Core #7' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_7_clock_val', type => 'value' }, ]
            },
            'CPU Core #8' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_8_clock_val', type => 'value' }, ]
            },
            'CPU Core #9' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_9_clock_val', type => 'value' }, ]
            },
            'CPU Core #10' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_10_clock_val', type => 'value' }, ]
            },
            'CPU Core #11' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_11_clock_val', type => 'value' }, ]
            },
            'CPU Core #12' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_12_clock_val', type => 'value' }, ]
            },
            'CPU Core #13' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_13_clock_val', type => 'value' }, ]
            },
            'CPU Core #14' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_14_clock_val', type => 'value' }, ]
            },
            'CPU Core #15' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_15_clock_val', type => 'value' }, ]
            },
            'CPU Core #16' => {
                ids =>
                  [ { id => 'tpohm_cpu_core_16_clock_val', type => 'value' }, ]
            },
        },
        'Temperature' => {
            'CPU Package' => {
                'ids' => [
                    { id => 'tpohm_cpu_package_temp_val', type => 'value' },
                    {
                        id         => 'tpohm_cpu_package_temp_status',
                        type       => 'threshold',
                        default    => "Low",
                        thresholds => [
                            { threshold => 65, value => "High" },
                            { threshold => 45, value => "Medium" }
                        ]
                    },
                ]
            },
            'GPU Core' => {
                'ids' => [
                    { id => 'tpohm_gpu_core_temp_val', type => 'value' },
                    {
                        id         => 'tpohm_gpu_core_temp_status',
                        type       => 'threshold',
                        default    => "Low",
                        thresholds => [
                            { threshold => 60, value => "High" },
                            { threshold => 40, value => "Medium" }
                        ]
                    },
                ]
            },

            #Maybe AMD Only
            'GPU Memory' => {
                'ids' => [
                    { id => 'tpohm_gpu_memory_temp_val', type => 'value' },
                    {
                        id         => 'tpohm_gpu_memory_temp_status',
                        type       => 'threshold',
                        default    => "Low",
                        thresholds => [
                            { threshold => 60, value => "High" },
                            { threshold => 40, value => "Medium" }
                        ]
                    },
                ]
            },
        },
        'Power' => {
            'CPU Package' => {
                ids =>
                  [ { id => 'tpohm_cpu_package_power_val', type => 'value' } ]
            },

            #NVidia
            'GPU Power' => {
                ids => [ { id => 'tpohm_gpu_power_val', type => 'value' } ]
            },

            #AMD
            'GPU Total' => {
                ids => [ { id => 'tpohm_gpu_power_val', type => 'value' } ]
            }
        },
        'Data' => {
            'Used Memory' => {
                ids => [ { id => 'tpohm_used_memory_val', type => 'value' } ]
            },
            'Available Memory' => {
                ids => [ { id => 'tpohm_avail_memory_val', type => 'value' } ]
            },
        },
        'SmallData' => {
            'GPU Memory Free' => {
                ids =>
                  [ { id => 'tpohm_gpu_free_memory_val', type => 'value' } ]
            },
            'GPU Memory Used' => {
                ids =>
                  [ { id => 'tpohm_gpu_used_memory_val', type => 'value' } ]
            },
        }
    );
    return %sensor_config;
}

=pod 

What to track that is "universal" per say

CPU Total Load
CPU Cores Power
CPU Package Temperature
CPU Core Temperatures (1-16 maybe)

RAM Load Memory
RAM Data Used Memory
RAM Data Availabe Memory

GPU Core Clock
GPU Mmeory Clock
GPU Shader Clock
GPU Core Temperature
GPU Load Core
GPU Load Frame Buffer
GPU Load Video Engine
GPU Load Bus Interface
GPU Load Memory
GPU Fan
GPU Data Memory Free
GPU Data Memory Used
GPU Data Memory Used %
GPU Data Memory Total


=pod

Name: Temperature #3
Name: AVCC
Name: Temperature
Name: Voltage #7
Name: Temperature
Name: CPU Package
Name: GPU Video Engine
Name: Memory
Name: CPU Core #4
Name: CPU Core #4
Name: GPU Memory Used
Name: GPU Core
Name: CPU VCore
Name: GPU PCIE Tx
Name: Voltage #5
Name: Used Space
Name: Fan Control #1
Name: CPU Core
Name: GPU Core
Name: Bus Speed
Name: CPU Core #2
Name: CPU Core #2
Name: GPU Fan
Name: Available Memory
Name: CPU Cores
Name: CPU Core #1
Name: GPU Memory
Name: GPU Memory
Name: CPU Core #3
Name: Fan #3
Name: 3VCC
Name: Fan #2
Name: GPU Memory Total
Name: Voltage #2
Name: Voltage #6
Name: CPU Core #4
Name: Fan Control #3
Name: GPU Frame Buffer
Name: CPU Core #3
Name: CPU Core #3
Name: CPU Core #2
Name: GPU PCIE Rx
Name: Temperature #1
Name: Total Bytes Written
Name: 3VSB
Name: Used Space
Name: GPU Shader
Name: CPU Graphics
Name: CPU Core #1
Name: CPU Core #1
Name: GPU Bus Interface
Name: Used Memory
Name: CPU Package
Name: CPU Total
Name: GPU Memory Free
Name: GPU Core
Name: Fan Control #2

=cut
