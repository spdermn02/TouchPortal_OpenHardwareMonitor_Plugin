#!C:\Strawberry\bin\perl

use lib "./Module";

use TouchPortal::Socket;
use Spdermn02::Logger qw( logIt );
use Win32::OLE;
use Win32::OLE::Const;
use JSON;
use Cwd qw(abs_path);
use File::Basename qw(dirname);

# Auto appends /n on the end of message, alternate to print "msg \n";
use feature 'say';
our $VERSION = '1.0.0';

## Auto flush prints
$| = 1;

our $dir = dirname( abs_path($0) );

our $debugLog = undef;
open $debugLog, '>', $dir . '\tpohm.log';

select $debugLog;

use constant {
    SEC_OF_DAY => 60 * 60 * 24,

    ID   => 'TPOpenHardwareMonitor-test',
    HOST => 'localhost',
};

# Flags for Interacting in WMI Queries
use constant wbemFlagReturnImmediately => 0x10;
use constant wbemFlagForwardOnly       => 0x20;

our ( $socket, $WMI );
our $waitTime = 2;    #default wait 2 seconds per sensor read and update
our %sensor_config = load_sensor_config();
our $time          = time;

main();

exit 0;

sub main {

    logIt('START','tp_ohm is starting up, and about to connect');

    $socket =
      new TouchPortal::Socket( { 'run_dir' => $dir, 'plugin_id' => ID } );
    if ( !$socket ) {
        logIt( 'FATAL', 'Cannot create socket connection : $!' );
        return 0;
    }

    if ( !connect_wmi() ) {
        logIt( 'FATAL', 'Unable to connect to WMI...' );
        return 0;
    }

    #sit here and wait for stuff
    while (1) {
        my $irc = $socket->state_update( 'tpohm_connected', 'Yes' );
        logIt( 'INFO',
            "Checking to see if we are connected, bytes sent to TP = $irc" );

        if ( !defined $irc || !$socket->{'socket'}->connected() ) {
            logIt( 'WARN', 'Socket Disconnecting, ending infinite loop' );
            last;
        }

        _roll_log();

        if ( !get_sensor_data() ) {
            last;
        }

        sleep $waitTime;
    }

    # If we get here and we are still connected,
    # send update we are no longer going to be connected
    if ( $socket->{'socket'}->connected() ) {
        my $irc = $socket->state_update( 'tpohm_connected', 'No' );
    }

    logIt('SHUTDOWN','tp_ohm is shutting down');

    return 1;
}

exit;

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
            'DEBUG',
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

    foreach my $sensor ( in $sensors) {
        my $type   = $sensor->{SensorType};
        my $name   = $sensor->{Name};
        my $value  = $sensor->{Value};
        my $parent = $sensor->{Parent};

        if (   defined $sensor_config{$type}
            && defined $sensor_config{$type}->{$name} )
        {
            logIt(
                'DEBUG',
                sprintf(
"GOOD: Sensor configured to be handled - Parent: %s Name: %s SensorType: %s Value: %s",
                    $parent, $name, $type, $value
                )
            );
            process_sensor( $type, $name, $value );
        }
        else {
            logIt(
                'DEBUG',
                sprintf(
"Sensor Not configured to be handled - Parent: %s Name: %s SensorType: %s Value: %s",
                    $parent, $name, $type, $value
                )
            );

        }
    }

    return 1;
}

sub process_sensor {
    my ( $type, $name, $value ) = @_;

    $sensor_info = $sensor_config{$type}->{$name};

    foreach my $id ( @{ $sensor_info->{ids} } ) {
        if ( $id->{type} eq "value" ) {

            $socket->state_update( $id->{id}, sprintf( "%.1f", $value ) );
        }
        elsif ( $id->{type} eq "threshold" ) {
            my $useValue = $id->{default};
            foreach my $threshold ( @{ $id->{thresholds} } ) {
                if ( int($value) >= int( $threshold->{threshold} ) ) {
                    $useValue = $threshold->{value};
                    last;
                }
            }
            $socket->state_update( $id->{id}, $useValue );
        }
    }

}

sub _roll_log {

    my $curTime = time;
    if ( ( $curTime - $time ) / SEC_OF_DAY > 1 ) {
        close $debugLog;
        open $debugLog, '>', $dir . '\tpohm.log';
        logIf( 'WARN',
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
                    }
                ]
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
                    }

                ]
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
                ids => [ { id => 'tpohm_gpu_core_load_val', type => 'value' }, ]
            },
            'GPU Memory' => {
                ids =>
                  [ { id => 'tpohm_gpu_memory_load_val', type => 'value' }, ]
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
        },
        'Power' => {
            'CPU Package' => {
                ids =>
                  [ { id => 'tpohm_cpu_package_power_val', type => 'value' } ]
            },
            'GPU Power' => {
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
