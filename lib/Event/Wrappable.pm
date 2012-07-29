# ABSTRACT: Sugar to let you instrument event listeners at a distance
package Event::Wrappable;
use strict;
use warnings;
use Scalar::Util qw( refaddr weaken );
use Sub::Exporter -setup => {
    exports => [qw( event event_method )],
    groups => { default => [qw( event event_method )] },
    };
use Sub::Clone qw( clone_sub );

our %INSTANCES;

our @EVENT_WRAPPERS;

=classmethod method wrap_events( CodeRef $code, @wrappers )

Adds @wrappers to the event wrapper list for the duration of $code.

   Event::Wrappable->wrap_events(sub { setup_some_events() }, sub { wrapper() });

This change to the wrapper list is dynamically scoped, so any events
registered by functions you call will be wrapped as well.

=cut
sub wrap_events {
    my $class = shift;
    my( $todo, @wrappers ) = @_;
    local @EVENT_WRAPPERS = ( @EVENT_WRAPPERS, @wrappers );
    $todo->();
}

my $LAST_ID;


sub _new {
    my $class = shift;
    my( $event, $raw_event ) = @_;
    bless $event, $class;
    my $storage = $INSTANCES{refaddr $event} = {};
    weaken( $storage->{'wrapped'} = $event );
    weaken( $storage->{'base'}    = $raw_event );
    $storage->{'wrappers'} = [ @EVENT_WRAPPERS ];
    $storage->{'id'} = ++ $LAST_ID;
    return $event;
}

=helper sub event( CodeRef $code ) returns CodeRef

Returns the wrapped code ref, to be passed to be an event listener.  This
code ref will be blessed as Event::Wrappable.

=cut

sub event(&) {
    my( $raw_event ) = @_;
    my $event = clone_sub $raw_event;
    if ( @EVENT_WRAPPERS ) {
        for (reverse @EVENT_WRAPPERS) {
            $event = $_->($event);
        }
    }
    return __PACKAGE__->_new( $event, $raw_event );
}

=helper sub event_method( $object, $method ) returns CodeRef

Returns a wrapped code ref suitable for use in an event listener.  The code
ref basically the equivalent of:

    sub { $object->$method(@_) }

Except faster and without the anonymous wrapper sub in the call stack.  Method
lookup is done when you register the event, which means that if you can't
apply any roles to the object after you register event listeners using it.

=cut

sub event_method($$) {
    my( $object, $method ) = @_;
    my $method_sub = ref($method) eq 'CODE' ? $method : $object->can($method);
    return event { unshift @_, $object; goto $method_sub };
}

=method method get_unwrapped() returns CodeRef

Returns the original, unwrapped event handler from the wrapped version.

=cut
sub get_unwrapped {
    my $self = shift;
    return $INSTANCES{refaddr $self}->{'base'};
}

=classmethod method get_wrappers() returns Array|ArrayRef

In list context returns an array of the current event wrappers.  In scalar
context returns an arrayref of the wrappers used on this event.

=method method get_wrappers() returns Array|ArrayRef

In list context returns an array of the wrappers used on this event.  In
scalar context returns an arrayref of the wrappers used on this event.

=cut
sub get_wrappers {
    my $self = shift;
    my $wrappers = ref $self
                 ? $INSTANCES{refaddr $self}->{'wrappers'}
                 : \@EVENT_WRAPPERS;
    return wantarray ? @$wrappers : $wrappers;
}

=method method object_id() returns Int

Returns an invariant unique identifier for this event.  This will not change
even across threads and is suitable for hashing based on an event.

=cut
sub object_id {
    my $self = shift;
    return $INSTANCES{refaddr $self}->{'id'};
}

sub DESTROY {
    my $self = shift;
    delete $INSTANCES{refaddr $self};
}

sub CLONE {
    my $self = shift;
    foreach (keys %INSTANCES) {
        my $object = $INSTANCES{$_}{'wrapped'};
        $INSTANCES{refaddr $object} = $INSTANCES{$_};
        delete $INSTANCES{$_};
    }
}

1;
=head1 SYNOPSIS

    use Event::Wrappable;
    use AnyEvent;
    use AnyEvent::Collect;
    my @wrappers = (
        sub {
            my( $event ) = @_;
            return sub { say "Calling event..."; $event->(); say "Done with event" };
        },
    );

    my($w1,$w2);
    # Collect just waits till all the events registered in its block fire
    # before returning.
    collect {
        Event::Wrappable->wrap_events( sub {
            $w1 = AE::timer 0.1, 0, event { say "First timer triggered" };
        }, @wrappers );
        $w2 = AE::timer 0.2, 0, event { say "Second timer triggered" };
    };

    # Will print:
    #     Calling event...
    #     First timer triggered
    #     Done with event
    #     Second timer triggered

    # The below does the same thing, but using method handlers instead.

    use MooseX::Declare;
    class ExampleClass {
        method listener_a {
            say "First timer event handler";
        }
        method listener_b {
            say "Second timer event handler";
        }
    }

    collect {
        my $listeners = ExampleClass->new;
        Event::Wrappable->wrap_events( sub {
            $w1 = AE::timer 0.1, 0, event_method $listeners=>"listener_a";
        }, @wrappers );
        $w2 = AE::timer 0.2, 0, event_method $listeners=>"listener_b";
    };


=for test_synopsis
use v5.10.0;

=head1 DESCRIPTION

This is a helper for creating globally wrapped events listeners.  This is a
way of augmenting all of the event listeners registered during a period of
time.  See L<AnyEvent::Collect> and L<MooseX::Event> for examples of its
use.

A lexically scoped variant might be desirable, however I'll have to explore
the implications of that for my own use cases first.
