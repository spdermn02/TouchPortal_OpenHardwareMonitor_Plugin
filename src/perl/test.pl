#!C:\Strawberry\bin\perl

use Spdermn02::Dashboard();

my $dash = new Spdermn02::Dashboard( FNAME => 'images\gaugeBackground.png' );

my $g1 = new Spdermn02::Dashboard::Gauge(
    MIN    => 0,
    MAX    => 100,
    VAL    => 100,
    NA1    => 3.14 / 2 + 1.95,
    NA2    => 3.14 / 2 - 1.95,
    NX     => 950,
    NY     => 600,
    NLEN   => 300,
    NWIDTH => 20
);

$dash->add_meter( 'RPM', $g1 );

my $g2 = new Spdermn02::Dashboard::Gauge(
    MIN  => 0,
    MAX  => 100,
    VAL  => 0,
    NA1  => 3.14 / 2 + 1.95,
    NA2  => 3.14 / 2 - 1.95,
    NX   => 350,
    NY   => 600,
    NLEN => 300
);

$dash->add_meter( 'SPEED', $g2 );
$dash->write_jpeg('dash.jpg');
