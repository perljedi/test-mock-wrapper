package Test::Mock::Wrapped::Verify;

use Test::Deep;
use Test::More;
use Clone qw(clone);

=head1 NAME

Test::Mock::Wrapped::Verify - Part of the Test::Mock::Wrapper module

=head1 SYNOPIS

    my $verifier = $wrapper->verify('bar');
    
    $verifier->at_least(2)->at_most(5);
    
    $verifier->with(['zomg'])->never;

=head1 DESCRIPTION

Instances of this class are returned by Test::Mock::Wrapper::verify to allow for
flexible, readible call verification with objects mocked by Test::Mock:Wrapper

=head1 METHODS

=cut

sub new {
    my($proto, $method, $calls) = @_;
    $calls ||= [];
    my $class = ref($proto) || $proto;
    return bless({__calls=>$calls, method=>$method}, $class);
}

sub getCalls {
    my $self = shift;
    return clone($self->{__calls});
}

sub with {
    my $self = shift;
    my $matcher = shift;
    my (@__calls) = grep({eq_deeply($_, $matcher)} @{ $self->{__calls} });
    return bless({__calls=>\@__calls, method=>$self->{method}}, ref($self));
}

sub never {
    my $self = shift;
    ok(scalar(@{ $self->{__calls} }) == 0,
       "$self->{method} should never be called but was called ".scalar(@{ $self->{__calls} })." time".(scalar(@{ $self->{__calls} }) > 1 ? "s":'').".");
    return $self;
}

sub once {
    my $self = shift;
    ok(scalar(@{ $self->{__calls} }) == 1, "$self->{method} should have been called once, but was called ".scalar(@{ $self->{__calls} })." times.");
    return $self;
}

sub at_least {
    my $self = shift;
    my $times = shift;
    ok(scalar(@{ $self->{__calls} }) >= $times, "$self->{method} only called ".scalar(@{ $self->{__calls} })." times, wanted at least $times\n");
    return $self;
}

sub at_most {
    my $self = shift;
    my $times = shift;
    ok(scalar(@{ $self->{__calls} }) <= $times, "$self->{method} called ".scalar(@{ $self->{__calls} })." times, wanted at most $times\n");
    return $self;
}

sub exactly {
    my $self = shift;
    my $times = shift;
    ok(scalar(@{ $self->{__calls} }) == $times, "$self->{method} called ".scalar(@{ $self->{__calls} })." times, wanted exactly $times times");
    return $self;
}

return 42;