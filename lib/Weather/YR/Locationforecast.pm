package Weather::YR::Locationforecast;

use strict;
use warnings;

use Weather::YR::Parser;
use Weather::YR::Locationforecast::Forecast;
use Weather::YR::Locationforecast::Forecast::Full;
use Weather::YR::Locationforecast::Forecast::Precip;
use Weather::YR::Locationforecast::Forecast::Symbol;

use List::Util qw/max min/;

use Data::Dumper;

use Mojo::Base qw/Weather::YR::Base/;

has 'latitude';
has 'longitude';

=head1 NAME

Weather::YR::Locationforecast - Used to fetch forecast from a geo position from YR

=head1 SYNOPSIS

  use Weather::YR::Locationforecast

  my $loc   = Weather::YR::Locationforecast->new(
    {
        'latitude'      => '59.6327',
        'longitude'     => '10.2468',
    }
  );

  my $loc_forecast = $loc->forecast;

  print $loc_forecast->[0]->{'temperature'}->{'value'} . " degrees celcius";

=head1 DESCRIPTION

This module returns textforecasts from YR according to specified parameters.

This module uses the data from URLs such as these:
 http://api.yr.no/weatherapi/locationforecast/1.5/?lat=60.10;lon=9.58

=head2 DESCRIPTION FROM YR API

This modules implements a full forecast for one location, that is, a forecast
with five parameters for a seven-day period.

The five parameters are temperature, wind speed, wind direction, pressure and
precipitation.

For the first 48 hours, the datapoints are spaces one hour apart, and for the
remaining five 24-hour periods, they are spaces three hours apart.

=head1 CONFIGURATION

=head2 url

The URL to the web service for getting the textforecasts. Defaults to version
1.8 of the API: B<http://api.yr.no/weatherapi/locationforecast/1.8/>.

=head2 latitude

The latitude of the location. No default, must be applied in constructor.

=head2 longitude

The longitude of the location. No default, must be applied in constructor.

=cut

__PACKAGE__->config(
    'url'       => 'http://api.yr.no/weatherapi/locationforecast/1.8/',
);


=head1 METHODS


=head2 forecast

Retrieves the forecast in a data structure representing the XML document.

=cut

sub forecast {
    my ( $self ) = @_;

    if(!$self->{forecast}) { 
      my $url     = $self->get_url();
      my $content = $self->fetch($url);

      $self->{forecast} = $self->parse_weatherdata($content);
    }

    return $self->{forecast};
}

=head2 high [<dmy>]

High temperature, optionally filtered by day

=cut

sub high { max shift->temperatures(shift) } 

=head2 low [<dmy>]

Low temperature, optionally filtered by day

=cut

sub low { min shift->temperatures(shift) }

=head2 temperatures [<dmy>]

Temperatures, optionally filtered by day

=cut

sub temperatures { map { $_->temperature->attr('value') }  shift->full_forecasts(shift) } 

sub full_forecasts {
  my ($self,$date)=@_;
  grep { $_->isa('Weather::YR::Locationforecast::Forecast::Full') &&
   ( $date ? $_->from->ymd eq $date : 1 ) }  
  @{$self->forecast} 
}

=head2 parse_weatherdata(C<$xml>)

This method parses the response from YR and returns a structure of objects.

=cut

sub parse_weatherdata {
    my ( $self, $xml ) = @_;


    my $dom=Mojo::DOM->new($xml);
    my @forecasts = ();
    
    my $meta = $dom->at('meta');

    for my $time ($dom->find('product time')->each) {
        my @forecast_refs = $self->parse_forecast_time($time);
        for my $forecast_ref (@forecast_refs) {
            $forecast_ref->meta($meta);
            push @forecasts, $forecast_ref;
        }
    }

    return \@forecasts;
}

=head2 parse_forecast_time(C<$time_ref>)

This method parses each time element in the forecast XML document.

=cut

sub parse_forecast_time {
    my ( $self, $time_ref ) = @_;

    my $to          = Weather::YR::Parser::parse_date_iso8601($time_ref->attr('to'));
    my $from        = Weather::YR::Parser::parse_date_iso8601($time_ref->attr('from'));
    my $type        = $time_ref->attr('datatype');
    my $location    = $time_ref->at('location');
    
    my %forecast    = (
        'type'          => $type,
        'to'            => $to,
        'from'          => $from,
        'location'      => {
            'latitude'      => $location->attr('latitude'),
            'longitude'     => $location->attr('longitude'),
            'altitude'      => $location->attr('altitude'),
        },
    );


    my @forecasts;
    
    my $forecast_ref = Weather::YR::Locationforecast::Forecast->new(\%forecast);
    
    if ($location->at('symbol')) {
        push @forecasts, parse_forecast_symbol($forecast_ref, $location);
    }

    if ($location->at('precipitation')) {
        push @forecasts, parse_forecast_precip($forecast_ref, $location);
    }

    if ($location->at('fog')) { # just to test a value
        $forecast_ref = parse_forecast_full($forecast_ref, $location);
        push @forecasts, $forecast_ref;
    }

    push @forecasts, $forecast_ref unless @forecasts;
    
    return @forecasts;
}

=head2 parse_forecast_full(C<$location>)

This method parses full/complete forecasts which contains different types of
data.

=cut

sub parse_forecast_full {
    my ($forecast_ref, $location) = @_;
    my %forecast    = %$forecast_ref;
    my %full        = (
        'fog'           => $location->at('fog'),
        'pressure'      => $location->at('pressure'),
        'clouds'        => {
            'low'           => $location->at('lowclouds'),
            'medium'        => $location->at('mediumclouds'),
            'high'          => $location->at('highclouds'),
    },
        'cloudiness'    => $location->at('cloudiness'),
        'winddirection' => $location->at('winddirection'),
        'windspeed'     => $location->at('windspeed'),
        'temperature'   => $location->at('temperature'),
    );
    
    @forecast{keys %full} = values %full;

    
    return Weather::YR::Locationforecast::Forecast::Full->new(\%forecast);
    
}

=head2 parse_forecast_symbol(C<$location>)

This method parses forecasts that contains symbol data.

=cut

sub parse_forecast_symbol {
    my ($forecast_ref, $location) = @_;
    my $symbol=$location->at('symbol');
    my %symbol      = (
        'number'        => $symbol->attr('number'),
        'name'          => $symbol->attr('id'),
    );
    
    
    Weather::YR::Locationforecast::Forecast::Symbol->new(\%symbol);
    
}

=head2 parse_forecast_precip(C<$location>)

This method parses forecasts that contains precipitation data.

=cut

sub parse_forecast_precip {
    my ($forecast, $location) = @_;
    my $precipitation=$location->at('precipitation');
    
    my %precip      = (
        'unit'  => $precipitation->attr('unit'),
        'value' => $precipitation->attr('value')
    );
    
    
    return Weather::YR::Locationforecast::Forecast::Precip->new(\%precip);
}

=head2 get_url

Assembles the complete URL for the textforecast service with
the forecast type and language.

=cut

sub get_url {
    my ( $self ) = @_;

    my $baseurl = $self->SUPER::get_url;
    my $lat     = $self->latitude;
    my $lon     = $self->longitude;
    
    my $url = "$baseurl?lon=$lon&lat=$lat";
    return $url;
}


=head1 SEE ALSO

L<Weather::YR>, L<Weather::YR::Base>

=head1 AUTHOR

Knut-Olav, E<lt>knut-olav@hoven.wsE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by Knut-Olav Hoven

This library is free software; you can redireibute it and/or modify it under the
terms as GNU GPL version 2.

=cut

1;
