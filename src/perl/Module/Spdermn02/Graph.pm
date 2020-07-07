use strict;
use warnings;

use POSIX qw(floor);
use GD;
use Spdermn02::Dashboard;

use constant {
    WIDTH  => 128,
    HEIGHT => 128
};

sub bar_graph {
    my $config      = shift;
    my $valuesArray = shift;

    my $image = GD::Image->new( WIDTH, HEIGHT );

    my $white = $image->colorAllocate( 255, 255, 255 );
    my $black = $image->colorAllocate( 0,   0,   0 );
    my $defaultColor = [ 0, 0, 255 ];
    my $useColor     = $config->{barGraphColor} // $defaultColor;
    my $barColor =
      $image->colorAllocate( $useColor->[0], $useColor->[1], $useColor->[2] );

    $image->transparent($white);

    $image->interlaced('true');

    #    $image->trueColor(1);
    $image->alphaBlending(0);
    $image->saveAlpha(1);

    my $cur = $#{$valuesArray};
    for ( my $j = 0 ; $j <= $#{$valuesArray} ; $j++ ) {
        my $percentage = $valuesArray->[$j] / 100;
        my $x1         = 126 - $cur;

        my $y1 = 127 - floor( 127 * $percentage );
        my $x2 = $x1 + 1;
        my $y2 = 127;

        #$image->rectangle( 126, 63, 127, 127 )
        #print "$i $percentage image->rectangle( $x1, $y1, $x2, $y2 )\n";
        $image->rectangle( $x1, $y1, $x2, $y2, $barColor );
        $cur--;
    }

    my $img = $image->png(0);

    return $img;
}

sub gauge {
    my $config = shift;

    my $value = shift;

    #my $dash = new GD::Dashboard( FNAME => '.\m1.png' );
    my $dash = new Spdermn02::Dashboard( FNAME => '.\images\m2.png' );

    my $g1 = new Spdermn02::Dashboard::Gauge(
        MIN => 0,
        MAX => 100,

        VAL => $value,

        #VAL => 0,
        #VAL => 100,

        NA1 => 3.14 / 2 + 2.10,
        NA2 => 3.14 / 2 - 2.10,

        #NA1   => 3.14 / 2 + 0.82,
        #NA2   => 3.14 / 2 - 0.82,
        #NX => 64, #for 128x128
        #NY => 70, #for 128x128
        #NLEN => 50,    #for 128x128
        NX   => 128,    #for 256x256
        NY   => 140,    #for 256x256
        NLEN => 100,    #for 256x256

        #NX     => 256,
        #NY     => 300,
        #NLEN   => 50,
        NCOLOR => $config->{needleColor} // [ 0, 0, 255 ],
        NWIDTH => 3
    );

    $dash->add_meter( 'gauge', $g1 );

    return $dash->png();
}

sub gauge_w_config {
    my ( $value, $min, $max, $color, $counterClockwise ) = @_;

    my $dash = new Spdermn02::Dashboard( FNAME => '.\images\m2.png' );

    my $g1 = new Spdermn02::Dashboard::Gauge(
        MIN => 0,
        MAX => 100,

        VAL => $value,

        NA1 => 3.14 / 2 + 2.10,
        NA2 => 3.14 / 2 - 2.10,

        #NX => 64, #for 128x128
        #NY => 70, #for 128x128
        #NLEN => 50,    #for 128x128
        NX   => 128,    #for 256x256
        NY   => 140,    #for 256x256
        NLEN => 100,    #for 256x256

        NCOLOR => [ 0, 0, 255 ],
        NWIDTH => 3
    );

    $dash->add_meter( 'gauge', $g1 );

    return $dash->png();
}

1;
