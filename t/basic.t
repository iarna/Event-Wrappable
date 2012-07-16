use strict;
use warnings;
use Test::More tests => 8;
use Event::Wrappable;
use 5.16.0;

{
    my $event_wrapper_counter = 0;
    my $wrapper = Event::Wrappable->add_event_wrapper( sub {
        my( $listener ) = @_;
        return sub { ++ $event_wrapper_counter; $listener->() };
        } );

    my $wrapped = event { note("Wrapped event triggered"); };

    Event::Wrappable->remove_event_wrapper($wrapper);

    my $unwrapped = event { note("Unwrapped event triggered"); };

    $wrapped->();
    is( $event_wrapper_counter, 1, "Event wrapper triggered" );

    $unwrapped->();
    is( $event_wrapper_counter, 1, "Removing event wrapper worked" );

    $wrapped->();
    is( $event_wrapper_counter, 2, "Event wrapper triggered again" );

    is( ref($wrapped), "Event::Wrappable", "Returned event sub is blessed");
}

{
    my $event_wrapper_counter = 0;

    my $wrapped;

    Event::Wrappable->wrap_events( sub {
        $wrapped = event { note("Wrapped event triggered") };
    }, sub {
        my( $listener ) = @_;
        return sub { ++ $event_wrapper_counter; $listener->() };
    });

    my $unwrapped = event { note("Unwrapped event triggered"); };

    $wrapped->();
    is( $event_wrapper_counter, 1, "Event wrapper triggered" );

    $unwrapped->();
    is( $event_wrapper_counter, 1, "Removing event wrapper worked" );

    $wrapped->();
    is( $event_wrapper_counter, 2, "Event wrapper triggered again" );

    is( ref($wrapped), "Event::Wrappable", "Returned event sub is blessed");
}
