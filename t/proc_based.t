use strict;
use warnings;
use Test::More tests => 7;
use Event::Wrappable;

my $event_wrapper_counter = 0;
my $event1_ctr = 0;
my $event2_ctr = 0;
my $wrapper = Event::Wrappable->add_event_wrapper( sub {
    my( $listener ) = @_;
    return sub { ++ $event_wrapper_counter; $listener->() };
    } );

my $wrapped = event { ++ $event1_ctr; note("Wrapped event triggered"); };

Event::Wrappable->remove_event_wrapper($wrapper);

my $unwrapped = event { ++ $event2_ctr; note("Unwrapped event triggered"); };

$wrapped->();
is( $event_wrapper_counter, 1, "Event wrapper triggered" );
is( $event1_ctr, 1, "First event triggered" );

$unwrapped->();
is( $event_wrapper_counter, 1, "Removing event wrapper worked" );
is( $event2_ctr, 1, "Second event triggered" );

$wrapped->();
is( $event_wrapper_counter, 2, "Event wrapper triggered again" );
is( $event1_ctr, 2, "First event triggered again" );

is( ref($wrapped), "Event::Wrappable", "Returned event sub is blessed");
