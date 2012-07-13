use strict;
use warnings;
use Test::More tests => 4;
use Event::Wrappable;

my $event_wrapper_counter = 0;
my $wrapper = Event::Wrappable->add_event_wrapper( sub { 
    my( $event ) = @_;
    return sub { ++ $event_wrapper_counter; $event->() };
    } );

my $wrapped = event { diag("Wrapped event triggered"); };

Event::Wrappable->remove_event_wrapper($wrapper);

my $unwrapped = event { diag("Unwrapped event triggered"); };

$wrapped->();
is( $event_wrapper_counter, 1, "Event wrapper triggered" );

$unwrapped->();
is( $event_wrapper_counter, 1, "Removing event wrapper worked" );

$wrapped->();
is( $event_wrapper_counter, 2, "Event wrapper triggered again" );

is( ref($wrapped), "Event::Wrappable", "Returned event sub is blessed");
