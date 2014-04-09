# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl YR.t'

#########################

use Test::More;
use File::Slurp; # required for reading XML file

BEGIN { use_ok('Weather::YR::Locationforecast') };

#########################

my $xml_file    = 'doc/example/locationforecast-oslo.xml';

# Doesn't really matter what coordinates we enter here, we will read the
# XML document from a local file.
my $l_forecast = Weather::YR::Locationforecast->new(
    {
        # Geo codes for Sande (VE.)
        'latitude'  => '59.6327',
        'longitude' => '10.2468',
        'url'       => 'http://api.yr.no/weatherapi/locationforecast/1.8/',
    }
);

is(
    $l_forecast->get_url,
    'http://api.yr.no/weatherapi/locationforecast/1.8/?lon=10.2468&lat=59.6327',
    'Assemble URL with latitude and longitude'
);

ok(
    -f $xml_file,
    'Locationforecast sample XML file exists'
);


my $xml         = read_file($xml_file);
my $parsed_ref  = $l_forecast->parse_weatherdata($xml);

isa_ok(
    $parsed_ref,
    'ARRAY',
    'The parsed data in return is an ARRAYREF'
);


$l_forecast->{forecast}=$parsed_ref;
my $forecast        = $parsed_ref->[0];
my $forecast_precip = $parsed_ref->[6];
my $forecast_symbol = $parsed_ref->[5];

# All forecasts should be of type Weather::YR::Locationforecast::Forecast
isa_ok(
    $forecast,
    'Weather::YR::Locationforecast::Forecast',
    'The first forecast is of type Weather::YR::Locationforecast::Forecast'
);

isa_ok(
    $parsed_ref->[scalar @$parsed_ref - 1],
    'Weather::YR::Locationforecast::Forecast',
    'The last forecast is of type Weather::YR::Locationforecast::Forecast'
);

# The first forecast should be a full forecast
isa_ok(
    $forecast,
    'Weather::YR::Locationforecast::Forecast::Full',
    'The first forecast is of type Weather::YR::Locationforecast::Forecast::Full'
);


#
# Checking the forecast data
#
is(
    $forecast->{'winddirection'}->{'deg'},
    33.2,
    'Parsed wind direction'
);

is(
    $forecast->{'windspeed'}->{'mps'},
    '6.0',
    'Parsed wind speed'
);

is(
    $forecast->{'temperature'}->{'value'},
    '4.8',
    'Parsed temperature'
);

is(
    $forecast->{'pressure'}->{'value'},
    1013.6,
    'Parsed pressure'
);

is(
    $forecast->{'cloudiness'}->{'percent'},
    '100.0',
    'Parsed cloudiness'
);

is(
    $forecast->{'fog'}->{'percent'},
    '0.0',
    'Parsed fog'
);

is(
    $forecast->{'clouds'}->{'low'}->{'percent'},
    99.4,
    'Parsed low clouds'
);

is(
    $forecast->{'clouds'}->{'medium'}->{'percent'},
    99.4,
    'Parsed medium clouds'
);

is(
    $forecast->{'clouds'}->{'high'}->{'percent'},
    '99.4',
    'Parsed medium clouds'
);

is(
    $forecast->{'location'}->{'latitude'},
    '59.9500',
    'Parsed location latitude'
);

is(
    $forecast->{'location'}->{'longitude'},
    '10.7500',
    'Parsed location longitude'
);

is(
    $forecast->{'location'}->{'altitude'},
    107,
    'Parsed location altitude'
);


#
# Testing precipitation
#
is(
    $forecast_precip->unit,
    'mm',
    'Parsed precipitation unit'
);

is(
    $forecast_precip->value,
    0.5,
    'Parsed precipitation value'
);


#
# Testing forecast symbol
#
is (
    $forecast_symbol->number,
    9,
    'Parsed symbol number'
);

is (
    $forecast_symbol->name,
    'LIGHTRAIN',
    'Parsed symbol name/id'
);

# Override the URL
my $forecast_url = Weather::YR::Locationforecast->new(
    {
        # Geo codes for Sande (VE.)
        'latitude'  => '59.6327',
        'longitude' => '10.2468',
        'url'       => 'http://api.yr.no/weatherapi/locationforecast/1.8-someother/',
    }
);

is(
    $forecast_url->get_url,
    'http://api.yr.no/weatherapi/locationforecast/1.8-someother/?lon=10.2468&lat=59.6327',
    'Override the URL'
);

is(
  $l_forecast->high,
  11.1,
  'Max temperature'
);

is(
  $l_forecast->low,
  0.4,
  'Min temperature'
);


is(
  $l_forecast->high('2014-04-09'),
  5.3,
  'Max temperature'
);

is(
  $l_forecast->low('2014-04-09'),
  2.3,
  'Min temperature'
);

undef $forecast_url;

done_testing;
