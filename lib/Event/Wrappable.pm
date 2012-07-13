# ABSTRACT: Create a registry of filters to pass event listeners through
package Event::Wrappable;
use strict;
use warnings;
use Scalar::Util qw( refaddr );
use Sub::Exporter -setup => {
    exports => [qw( event )],
    groups => { default => [qw( event )] },
    };

our %INSTANCES;

our @EVENT_WRAPPERS;

=classmethod method add_event_wrapper( CodeRef $wrapper ) returns CodeRef

Wrappers are called in reverse declaration order.  They take a the event
to be added as an argument, and return a wrapped event.

=cut

sub add_event_wrapper {
    my( $wrapper ) = @_[1..$#_];
    push @EVENT_WRAPPERS, $wrapper;
    return $wrapper;
}

=classmethod method remove_event_wrapper( CodeRef $wrapper )

Removes a previously added event wrapper.

=cut

sub remove_event_wrapper {
    my( $wrapper ) = @_[1..$#_];
    @EVENT_WRAPPERS = grep { $_ != $wrapper } @EVENT_WRAPPERS;
    return;
}

=helper sub event( CodeRef $code ) returns CodeRef

Returns the wrapped code ref, to be passed to an event handler

=cut

sub event(&) {
    my( $raw_event ) = @_;
    my $event = $raw_event;
    for (reverse @EVENT_WRAPPERS) {
        $event = $_->($event);
    }
    bless $event, __PACKAGE__;
    my $storage = $INSTANCES{refaddr $event};
    $storage->{'raw'} = $raw_event;
    $storage->{'wrappers'} = [ @EVENT_WRAPPERS ];
    return $event;
}

=method method get_unwrapped() returns CodeRef
Returns the original, unwrapped event handler from the wrapped version.
=cut
sub get_unwrapped {
    my $self = shift;
    return $INSTANCES{refaddr $self}->{'raw'};
}

=method method get_wrappers() returns Array|ArrayRef
In list context returns an array of the wrappers used on this event.  In
scalar context returns an arrayref of the wrappers used on this event.
=cut
sub get_wrappers {
    my $self = shift;
    my $wrappers = $INSTANCES{refaddr $self}->{'wrappers'};
    return wantarray ? @$wrappers : $wrappers;
}

sub DESTROY {
    my $self = shift;
    delete $INSTANCES{refaddr $self};
}

1;
=head1 SYNOPSIS

    use Event::Wrappable;
    use AnyEvent;
    use EV;
    
    my $wrapper = Event::Wrappable->add_event_wrapper( sub { 
        my( $event ) = @_;
        return sub { say "Calling event..."; $event->(); say "Done with event" };
        } );
    my $w = AE::timer 1, 0, event { say "First timer triggered" };
    Event::Wrappable->remove_event_wrapper($wrapper);
    my $w2 = AE::timer 2, 0, event { say "Second timer triggered" };
    EV::loop;

    # Will print:
    #     Calling event...
    #     First timer triggered
    #     Done with event
    #     Second timer triggered

=head1 DESCRIPTION

This is a helper for creating globally wrapped events listeners.  This is a
way of augmenting all of the event listeners registered during a period of
time.  See L<AnyEvent::Collect> and L<MooseX::Event> for examples of its
use.  A lexically scoped variant might be desirable, however I'll have to
explore the implications of that for my own use cases first.
