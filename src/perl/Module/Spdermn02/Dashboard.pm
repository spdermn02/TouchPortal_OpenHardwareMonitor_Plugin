package Spdermn02::Dashboard;

use strict;

use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

$Spdermn02::Dashboard::VERSION = '0.04';

# Preloaded methods go here.

#
# Constructor options:
#
# FNAME
# QUALITY
#
sub new {
    my $proto = shift;

    my $self = {
        METERS  => {},
        FNAME   => '',
        QUALITY => 100
    };

    # load in options supplied to new()
    for ( my $x = 0 ; $x <= $#_ ; $x += 2 ) {
        my $opt = uc( $_[$x] );

        defined( $_[ ( $x + 1 ) ] )
          or die
"Dashboard->new() called with odd number of option parameters - should be of the form option => value";
        $self->{$opt} = $_[ ( $x + 1 ) ];
    }

    bless($self);
    return $self;
}

#
# There can be many meters on a graphic.  To specify them,
# you create a new meter, then pass it to this function,
# along with its name.  All meters will be referred to by
# name.
#
sub add_meter {
    my ( $self, $name, $meter ) = @_;
    $self->{METERS}->{$name} = $meter;
}

#
# Why would you want to use get_meter?  A couple of reasons.
# First, you might have called add_meter(new Dashboard::Gauge()).
# Second, if you have multiple dash layouts, you have probably
# written the code so that you don't have access to the original
# meter variables at the point where you need to set them.
#
sub get_meter {
    my ( $self, $name ) = @_;
    $self->{METERS}->{$name};
}

sub gdimage {
    my ($self) = @_;
    my ($aref) = $self->{METERS};
    my $fname  = $self->{FNAME};

    if ( !defined($fname) || $fname eq '' ) {
        warn(
"Spdermn02::Dashboard::gdimage(): You must set FNAME in constructor first!"
        );
        return undef;
    }

    # Get canvas from specified background graphics
    my $im;

    if ( $self->{FNAME} =~ /png$/ ) {
        $im = GD::Image->newFromPng( $self->{FNAME}, 1 );
    }
    else {
        $im = GD::Image->newFromJpeg( $self->{FNAME} );
    }

    my $black = $im->colorAllocate( 0, 0, 0 );

    $im->transparent($black);

    $im->interlaced('true');
    $im->alphaBlending(0);
    $im->saveAlpha(1);

    # Draw all my meters
    for my $m ( keys( %{$aref} ) ) {
        my $m2 = $aref->{$m};
        $m2->write_gdimagehandle($im);
    }

    $im;
}

sub png {
    my ($self) = @_;

    my $im = $self->gdimage;

    return $im->png(0);
}

sub jpeg {
    my ($self) = @_;

    my $im = $self->gdimage;

    return $im->jpeg( $self->{QUALITY} );
}

#
# Is anything wrong with me using this filehandle (HG1) ?
#
sub write_jpeg {
    my ( $self, $fname ) = @_;

    open( HG1, '>' . $fname );
    binmode HG1;
    print HG1 $self->jpeg();
    close HG1;
}

sub write_png {
    my ( $self, $fname ) = @_;

    open( HG1, '>' . $fname );
    binmode HG1;
    print HG1 $self->png();
    close HG1;
}

package Spdermn02::Dashboard::Base;

# insert base class for meters here.....

# All meters should support:
#      MIN => 0,
#      MAX => 100,
#      VAL => 50,
#      NX => 0,
#      NY => 0,
#      QUALITY => 100,

sub jpeg {
}

sub write_jpeg {
}

package Spdermn02::Dashboard::Gauge;

use GD;

#  use GD::Image qw( gdMediumBoldFont  gdGiantFont);

#
# Constructor Options
#
# MIN
# MAX
# VAL
# NX
# NY
# NLEN
# NWIDTH
# NA1
# NA2
# NCOLOR
# QUALITY
# FNAME
# COUNTERCLOCKWISE
#
sub new {
    my $proto = shift;

    my $self = {
        FNAME            => '',
        MIN              => 0,
        MAX              => 100,
        VAL              => 50,
        NX               => 0,
        NY               => 0,
        NLEN             => 0,
        NWIDTH           => 2,
        NA1              => 0,
        NA2              => 0,
        NCOLOR           => [ 0, 0, 255 ],
        QUALITY          => 100,
        COUNTERCLOCKWISE => 0
    };

    # load in options supplied to new()
    for ( my $x = 0 ; $x <= $#_ ; $x += 2 ) {
        my $opt = uc( $_[$x] );

        defined( $_[ ( $x + 1 ) ] )
          or die
"Dashboard::Gauge->new() called with odd number of option parameters - should be of the form option => value";
        $self->{$opt} = $_[ ( $x + 1 ) ];
    }

    bless($self);
    return $self;
}

sub write_gdimagehandle {
    my ( $self, $im ) = @_;
    $self->_draw_needle($im);

    my $color = $im->colorAllocate( 255, 255, 255 );

# TODO: Saving this for later
#$im->useFontConfig(1);
#$im->stringFT($color,'..\..\digital-7.ttf',25,0,$self->{'NX'} - 30, $self->{'NY'} + 20 , sprintf("%5s%%",$self->{'VAL'}));

    #$im->string( gdGiantFont,
    #    ( $self->{'NX'} - 30 ),
    #    ( $self->{'NY'} + 10 ),
    #    sprintf( "%5s%%", $self->{'VAL'} ), $color
    #);
}

#sub jpeg
#{
#   my ($self) = @_;
#
#   my $im = GD::Image->newFromJpeg($self->{FNAME});
#
#   $self->write_gdimagehandle($im);
#
#   return $im->jpeg(100);
#}
#
#sub write_jpeg
#{
#   my ($self,$fname) = @_;
#
#   open (HG1,'>'.$fname);
#   binmode HG1;
#   print HG1 $self->jpeg();
#   close HG1;
#}

sub set_reading {
    my ( $self, $val ) = @_;

    warn "Warning: set_reading called with value less than minimum."
      if $val < $self->{MIN};
    warn "Warning: set_reading called with value greater than maximum."
      if $val > $self->{MAX};

    $self->{VAL} = $val;
}

sub _draw_needle {
    my ( $self, $im ) = @_;
    my ( $x, $y );
    my $pi = 3.141592;

    # Must compute x,y coords for tip of needle.
    # Angle system for GD is in degrees, 0 is straight up,
    # and they increase clockwise.  Sigh.  Angle system
    # for perl is in radians, 0 is as it is defined
    # traditionally in math, angles increase counterclockwise.
    #

    my $norm =
      ( $self->{VAL} - $self->{MIN} ) / ( $self->{MAX} - $self->{MIN} );
    my $angle_width;

    if ( $self->{NA1} > $self->{NA2} ) {
        if ( $self->{COUNTERCLOCKWISE} ) {
            $angle_width = ( 2 * $pi ) - ( $self->{NA1} - $self->{NA2} );
        }
        else {
            $angle_width = ( $self->{NA1} - $self->{NA2} );
        }
    }
    else {
        if ( $self->{COUNTERCLOCKWISE} ) {
            $angle_width = ( $self->{NA2} - $self->{NA1} );
        }
        else {
            $angle_width = ( 2 * $pi - ( $self->{NA2} - $self->{NA1} ) );
        }
    }

    my $angle;
    if ( $self->{COUNTERCLOCKWISE} == 1 ) {
        $angle = $self->{NA1} + $norm * $angle_width;
    }
    else {
        $angle = $self->{NA1} - $norm * $angle_width;
    }

    $x = $self->{NX} + $self->{NLEN} * cos($angle);
    $y = $self->{NY} - $self->{NLEN} * sin($angle);

    # To draw a line with a width other than 1, you actually need
    # to create an image brush.  Sigh.
    #
    my $brush = _prepare_brush( $self->{NWIDTH}, $self->{NCOLOR} );
    $im->setBrush($brush);

    # draw the needle!
    #
    $im->line( $self->{NX}, $self->{NY}, $x, $y, gdBrushed );

    # how to clean up the brush?
}

#####################
#
# Private functions
#
#####################

##  set the gdBrush object to trick GD into drawing fat lines
sub _prepare_brush {
    my ( $radius, $ref_color ) = @_;
    my ( @rgb, $brush, $white, $newcolor );

    # get the rgb values for the desired color
    #  @rgb = (0,0,255);
    #  @rgb = (255,0,128);
    @rgb = @{$ref_color};

    # create the new image
    $brush = GD::Image->new( $radius * 2, $radius * 2 );

    # get the colors, make the background transparent
    #  $white = $brush->colorAllocate (255,255,255);
    $white    = $brush->colorAllocate( 0, 0, 0 );
    $newcolor = $brush->colorAllocate(@rgb);
    $brush->transparent($white);

    # draw the circle
    $brush->arc( $radius - 1, $radius - 1, $radius, $radius, 0, 360,
        $newcolor );

    # set the new image as the main object's brush
    return $brush;
}

package Spdermn02::Dashboard::WarningLight;

#
# TRANSPARENT
# NX
# NY
# FNAME
# VAL
#
sub new {
    my $proto = shift;

    my $self = {
        VAL   => 0,    # 0=off, 1=on
        NX    => 0,
        NY    => 0,
        FNAME => ''
    };

    # load in options supplied to new()
    for ( my $x = 0 ; $x <= $#_ ; $x += 2 ) {
        my $opt = uc( $_[$x] );

        defined( $_[ ( $x + 1 ) ] )
          or die
"Dashboard::WarningLight->new() called with odd number of option parameters - should be of the form option => value";
        $self->{$opt} = $_[ ( $x + 1 ) ];
    }

    bless($self);
    return $self;
}

sub write_gdimagehandle {
    my ( $self, $im ) = @_;

    if ( $self->{VAL} == 1 ) {

        # load the current image
        my $im2 = GD::Image->newFromJpeg( $self->{FNAME} );
        my ( $w, $h ) = $im2->getBounds();

        if ( defined( $self->{TRANSPARENT} ) ) {
            my $white =
              $im2->colorClosest( 255, 255, 255 );  #TODO this should be a param
            $im2->transparent($white);
        }
        $im->copy( $im2, $self->{NX}, $self->{NY}, 0, 0, $w, $h );
    }
}

sub set_reading {
    my ( $self, $val ) = @_;

    $self->{VAL} = $val;
}

package Spdermn02::Dashboard::HorizontalBar;

# Options:
#   TRANSPARENT = [ r,g,b ]
#   SPACING = N
#   MIN
#   MAX
#
sub new {
    my $proto = shift;

    my $self = {
        MIN       => 0,
        MAX       => 100,
        VAL       => 50,
        NX        => 0,
        NY        => 0,
        QUALITY   => 100,
        DIRECTION => 0,
        BARS      => [],
        SPACING   => 0
    };

    # load in options supplied to new()
    for ( my $x = 0 ; $x <= $#_ ; $x += 2 ) {
        my $opt = uc( $_[$x] );

        defined( $_[ ( $x + 1 ) ] )
          or die
"Dashboard::HorizontalBar->new() called with odd number of option parameters - should be of the form option => value";
        $self->{$opt} = $_[ ( $x + 1 ) ];
    }

    bless($self);
    return $self;
}

sub add_bars {
    my ( $self, $cnt, $fname, $fnameoff ) = @_;
    if ( !defined($fnameoff) ) { $fnameoff = ''; }
    push @{ $self->{BARS} },
      { CNT => $cnt, FNAME => $fname, FNAME_OFF => $fnameoff };
}

sub set_reading {
    my ( $self, $val ) = @_;

#   warn "Warning: set_reading called with value less than minimum." if $val < $self->{MIN};
#   warn "Warning: set_reading called with value greater than maximum." if $val > $self->{MAX};

    $self->{VAL} = $val;
}

sub write_gdimagehandle {
    my ( $self, $im ) = @_;

    # How many bars do we have?
    my $barcnt = 0;
    for my $href ( @{ $self->{BARS} } ) { $barcnt += $href->{CNT}; }

    # How many must we display?
    my $norm = $self->{VAL} / ( $self->{MIN} + $self->{MAX} );
    my $disp = int( $barcnt * $norm );

    # OK copy the graphics as necessary
    my $x = $self->{NX};
    for my $href ( @{ $self->{BARS} } ) {

        # load the current image
        my $im2 = GD::Image->newFromJpeg( $href->{FNAME} );

        if ( defined( $self->{TRANSPARENT} ) ) {
            my $white =
              $im2->colorClosest( 255, 255, 255 );  #TODO this should be a param
            $im2->transparent($white);
        }

        my ( $w, $h ) = $im2->getBounds();

        my $cnt = $href->{CNT};
        while ( $disp > 0 && $cnt > 0 ) {
            $im->copy( $im2, $x, $self->{NY}, 0, 0, $w, $h );
            $x += $w + $self->{SPACING};
            $disp--;
            $barcnt--;
            $cnt--;
        }

        # Now load up dark image and use it if necessary
        my $fn2 = $href->{FNAME_OFF};
        if ( defined($fn2) && $fn2 ne '' ) {
            my $im3 = GD::Image->newFromJpeg($fn2);

            if ( defined( $self->{TRANSPARENT} ) ) {
                my $wt = $im2->colorClosest( 255, 255, 255 )
                  ;    #TODO this should be a param
                $im3->transparent($wt);
            }
            my ( $w, $h ) = $im2->getBounds();

            while ( $cnt > 0 ) {
                $im->copy( $im3, $x, $self->{NY}, 0, 0, $w, $h );
                $x += $w + $self->{SPACING};
                $cnt--;
            }
        }
    }

}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

=head1 NAME

Spdermn02::Dashboard - Perl module to create JPEG graphics of meters and dials

=head1 SYNOPSIS

   my $dash = new Spdermn02::Dashboard();

   my $g1 = new Spdermn02::Dashboard::Gauge(
                      MIN=>0,
                      MAX=>$empcnt,
                      VAL=>$nopwp_cnt,
                      NA1=>3.14/2+0.85,
                      NA2=>3.14/2-0.85,
                      NX=>51,NY=>77,NLEN=>50                      
            );

   $dash->add_meter('RPM', $g1);
   $dash->write_jpeg('dash.jpg');

The Dashboard module aims at providing users with a quick and
easy way to create dashboard or cockpit like JPGs to display
key information.

Dashboard supports the following instruments:

  * Gauges with needles
  * Bar type gauges
  * Warning Lights

Dashboard is built on top of GD.pm, Licoln Stein's interface
to the GD library.

=head1 Classes

The dashboard module contains several classes.  These classes
typically represent either a dashboard or an instrument on 
the dashboard.  The Dashboard object serves as a collection
for the instruments.

=head2 Dashboard

The Dashboard object serves as the collection object that contains
the various instruments in the display.  You can add instruments
to the dashboard, access instruments through it, or tell it to draw
itself.

   my $dash = new Dashboard();
   $dash->add_meter('RPM', $g1);
   $dash->add_meter('Speedo', $g2);
   $dash->write_jpeg('dash.jpg');

=over 4

=item *
FNAME

This is the name of a JPG file to use for the background.  This 
graphic will typically have one or more gauges on it, upon which
this module will draw needles or other indicators.

=item *
QUALITY

The quality of the output JPEG, from 1 (low) to 100 (high).  Defaults to
100.  This value is passed directly to GD.

=back 4

=head3 add_meter(name, meter)

Adds a meter to the dash.  Create the meter using one of the
new() constructors first.  You can add Gauges, HorizontalBars, and
WarningLights.  The name is used by the get_meter() 
function if you need to access the meter later.

=head3 get_meter()

Gets a meter by name.  When adding a meter, you must give it a name.
You can then use get_meter to get the meter object.  This is useful
when you want to change a setting later, such as the meter's value.

=head3 jpeg()

Returns a JPG as a scalar value.

=head3 write_jpeg(fname)

Draws the dashboard to a jpg file given by fname.

=head3 png()

Returns a PNG as a scalar value.

=head3 write_png(fname)

Draws the dashboard to a PNG file given by fname.

=head2 Dashboard::Gauge

This class describes a typical dashboard gauge; that is, an 
instrument that has a needle that rotates.  The needle may
rotate clockwise or counterclockwise.  This gauge is similar
to a car speedometer or and airspeed indicator.

=head3 new()

Most gauge configuration is done in the constructor.  Here is a sample
for the gauge included with this package (m1.jpg):

   my $g1 = new GD::Dashboard::Gauge(FNAME=>base_path().'\icons\m1.jpg',
                      MIN=>0,
                      MAX=>$empcnt,
                      VAL=>$nopwp_cnt,
                      NA1=>3.14/2+0.85,
                      NA2=>3.14/2-0.85,
                      NX=>51,NY=>77,NLEN=>50                      
            );

=over 4

=item *
VAL

This indicates where the needle is pointing.  Generally it should
be somewhere between MIN and MAX.

=item *
MIN

This is the minimum VAL is ever expected to reach.  It corresponds
to a needle position of NA1.  Lower values are not truncated; however,
they will generate warnings.

=item *
MAX

This is the maximum VAL is ever expected to reach.  It corresponds
to a needle position of NA2.  Higher values are not truncated; however,
they will generate warnings.

=item *
NX

This is the X coordinate of the base of the needle.

=item *
NY

This is the Y coordinate of the base of the needle.

=item *
NLEN

This is the length of the needle to draw.

=item *
NWIDTH

This is the width of the needle.

=item *
NA1

NA1 and NA2 are potentially the most confusing parameters.  They
represent the angle of the needle at its MIN and MAX points.  NA1
is the angle that corresponds to VAL=MIN, while NA2 is VAL=MAX.  The
angle is expressed in radians, the same way you would express an angle
to one of perl's trigonometric functions.

=item *
NA2

See NA1.

=item *
NCOLOR

This is the color of the needle.  This value should be passed as a 
reference to an array of RGB values.

=item *
COUNTERCLOCKWISE

Set to 1 if needle moves from MIN to MAX in a counterclockwise direction.
Otherwise you can ignore it.

=back 4

=head2 Dashboard::HorizontalBar

This class describes an LED bargraph display of the type often
found in a graphical equalizer or, on some cars, the oil condition
indicator.  It may be all one color, or it may use different colors
in different ranges.

The graph goes from left to right and consists of a number of bars, meant
to represent LEDs.  Bars can be identical or you can configure different
bars, for example to have the last couple of bars be red instead of green.

   my $m1 = new GD::Dashboard::HorizontalBar(
                  NX => 235,
                  NY => 348,
                  SPACING => 1
                  );
   $m1->add_bars(20,base_path().'\icons\barlight_on.jpg','\icons\barlight_off.jpg');
   $dash->add_meter('m1',$m1);

=head3 new()

=over 4

=item * 
MIN = N
The value representing zero bars illuminated.  Defaults to 0.

=item *
MAX = N
The value representing all bars illuminated.  Defaults to 100.

=item * 
VAL = N
The value to display.  Number of bars illuminated will be 
val / (max-min) percent of total.

=item *
   TRANSPARENT = [ r,g,b ]

This is currently not implemented correctly.  If you pass any array 
reference to this parameter, WHITE will be transparent.  This allows
you to have non-rectangular bars.  Email me if the white bit is a problem.

=item *
   SPACING = N

If you would like bars to be separated by a number of pixles, specify
the number in this parameter.

=back 4

=head3 add_bars(count, fname, fnameoff)

Call this for each different group of bars you would like to add.  Count
is the number of bars.  Fname is the path to a JPG that represents the
bars in their ON state.  Fnameoff is an optional filename to a JPG
that represents the bar in the off state (these are often just built
into the dashboard background, however).

=head3 set_reading(val)

Sets the number of bars that are illuminated.  So if you have 20 bars
defined, 'val' should be between 0 and 20 inclusive.

=head2 Dashboard::WarningLight

This behaves like a warning light on a car dashboard.  It can be turned
on or off.  When VAL is 0, this gauge has basically no effect.  When
VAL is 1, it draws another graphic on the dashboard (this would typically
be the warning light on graphic).  Consequently, the dashboard graphic
should contain the warning light in its "off" state.

=head3 new()

Most configuration of the warning light is done via the constructor.

=over 4

=item * 
FNAME

This is a JPG file that will be drawn at NX,NY when the warning light
is turned on.

=item * 
VAL 

This can be 0 or 1.  A value of 1 turns the warning light on, i.e., it
causes the graphic FNAME to be drawn at NX,NY.

=item *
NX

X position of lower right of graphic FNAME.

=item *
NY

Y position of lower right of graphic FNAME.

=item *
TRANSPARENT

Currently, set this to 1 to make WHITE transparent.  I probably
should make this take an RGB array ref.  Email me if you want it.

=back 4

=head3 set_reading(val)

Sets the VAL parameter.  This can be 0 (warning light off) or 1 (warning
light on).

=head1 NOTES

This is the first release.  There are a few things on my mind for 0.02.  
First, PNG support would be easy to add in.  I don't use it so I haven't
added it (yet).  Email if you want it.  Second, all of the meters are 
probably going to derive from a base class.  Haven't had time to change
it yet.

Eventually I should pay more attention to the needle drawing in the
Gauge class.  If your art is really good, the needles bring it down :(

I'm sure the docs could be better.

=head1 AUTHOR

David Ferrance (dave@ferrance.com)
Enhanced by Jameson allen (spdermn02@gmail.com)

=head1 LICENSE

Dashboard: A module for creating dashboard graphics.

Copyright (C) 2002 David Ferrance (dave@ferrance.com).  All Rights Reserved. 

This module is free software. It may be used, redistributed and/or modified under the same terms as perl itself. 

Sample graphics provided by rabia@rabia.com.  This module isn't worth much
without a good graphics person to provide you with sweet dashboard layouts.


=cut
