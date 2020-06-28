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
    my $valuesArray = shift;

    my $image = GD::Image->new( WIDTH, HEIGHT );

    my $white = $image->colorAllocate( 255, 255, 255 );
    my $black = $image->colorAllocate( 0,   0,   0 );
    my $blue  = $image->colorAllocate( 0,   0,   255 );

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
        $image->rectangle( $x1, $y1, $x2, $y2, $blue );
        $cur--;
    }

    #my $count = $#{$valuesArray};

    #open my $out, '> ', "graph.png" or die;
    #binmode $out;
    #print $out $image->png(0);
    #close $out;

    my $img = $image->png(0);

    #use MIME::Base64
    #  qw(encode_base64url encode_base64 decode_base64 decode_base64url);

    #open my $im, '< ', 'test.png' or die;
    #binmode $im;
    #my $file;
    #while (<$im>) { $file .= $_; }
    #close $im;
    #chomp $file;
    #my $file = encode_base64( $img, '' );
    #my $file = encode_base64url($img);

    #open my $outf, '> ', "test1.png" or die;
    #binmode $outf;
    #print $outf decode_base64url($file);
    #close $outf;

    return $img;

}

our $count = 0;

sub gauge {

    my $value = shift;

    #my $dash = new GD::Dashboard( FNAME => '.\m1.png' );
    my $dash = new Spdermn02::Dashboard( FNAME => '.\m2.png' );

    my $g1 = new Spdermn02::Dashboard::Gauge(
        FNAME => '.\base.png',
        MIN   => 0,
        MAX   => 100,

        #VAL => $value,
        #VAL => 0,
        VAL => 100,

        NA1 => 3.14 / 2 + 2.10,
        NA2 => 3.14 / 2 - 2.10,

        #NA1   => 3.14 / 2 + 0.82,
        #NA2   => 3.14 / 2 - 0.82,
        #NX => 64,
        #NY => 70,
        NX   => 128,
        NY   => 140,
        NLEN => 100,

        #NX     => 256,
        #NY     => 300,
        #NLEN   => 50,
        NCOLOR => [ 0, 0, 255 ],
        NWIDTH => 3
    );

    $dash->add_meter( 'gauge', $g1 );

    return $dash->png();
}

1;
