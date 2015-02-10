package Test::Mock::Wrapper;
use base qw(Exporter);
use Test::Deep;
use Test::More;
use Clone qw(clone);

=head1 NAME

Test::Mock::Wrapper

=head1 DESCRIPTION

This is another module for mocking objects in perl.  It will wrap around an existing object, allowing you to mock any calls
for testing purposes.  It also records the arguments passed to the mocked methods for later examination. The verification
methods are designed to be chainable for easily readable tests for example:

  # Verify method foo was called with argument 'bar' at least once.
  $mockWrapper->verify('foo')->with('bar')->at_least(1);
  
  # Verify method 'baz' was called at least 2 times, but not more than 5 times
  $mockWrapper->verify('baz')->at_least(2)->at_most(5);


=head1 METHODS

=over

=item Test::Mock::Wrapper->new($object, [%options])

Creates a new wrapped mock object and a controller/accessor object used to manipulate the mock without poluting the
namespace of the object being mocked.

Valid options:

=over 2

=item B<type>=>(B<mock>|B<stub>|B<wrap>): Type of mocking to use.

=over 3

=item B<mock>:  All methods available on the underlying object will be available, and all will be mocked

=item B<stub>:  Any method called on the mock object will be stubbed, even those which do not exist in the original
object

=item B<wrap> (default): Only methods which have been specifically set up with B<addMock> will be mocked
all others will be passed through to the underlying object.

=back

=item recordAll=>BOOLEAN (default B<false>)

If set to true, this will record the arguments to all calls made to the object, regardless of the method being
mocked or not.

=item recordMethod=>(B<copy>|B<clone>)

By default arguments will be a simple copy of @_, use B<clone> to make a deep copy of all data passed in. If references are being
passed in, the default will not trap the state of the object or reference at the time the method was called, though clone will.
Naturally using clone will cause a larger memory foot print.

=back

=cut


sub new {
    my($proto, $object, %options) = @_;
    $options{type} ||= 'wrap';
    $options{recordType} ||= 'copy';
    my $class = ref($proto) || $proto;
    my $controll = bless({__object=>$object, __mocks=>{}, __calls=>{}, __options=>\%options}, $class);
    $controll->{__mocked} = Test::Mock::Wrapped->new($controll, $object);
    return $controll;
}

=item $wrapper->getObject

This method returns the wrapped 'mock' object.  The object is actually a Test::Mock::Wrapped object, however it can be used
exactly as the object originally passed to the constructor would be, with the additional hooks provieded by the wrapper
baked in.

=cut

sub getObject {
    my $self = shift;
    return $self->{__mocked};
}

sub _call {
    my $self = shift;
    my $method = shift;
    my $copy = $self->{options}{recordMethod} eq 'copy' ? [@_] : clone(@_);
    push @{ $self->{__calls}{$method} }, $copy;
    
    # Check to see if we have an argument specific return value
    if (exists $self->{__mocks}{$method}{with}) {
	my $return_offset = 0;
	foreach my $test_set (@{ $self->{__mocks}{$method}{with} }){
	    if(eq_deeply(\@_, $test_set)){
		return $self->{__mocks}{$method}{conditional_return}[$return_offset];
	    }
	    $return_offset++;
	}
    }
    
    
    # If we've gotten here, we did not find an argument specific return
    if(exists $self->{__mocks}{$method}{returns}){
	# I we have a default, use it
	return $self->{__mocks}{$method}{returns};
    }
    elsif($self->{__options}{type} ne 'wrap'){
	# No default, type equals stub or mock, return undef.
	return undef;
    }
    else{
	# We do not have a default, and our mock type is not stub, try to call underlying object.
	unshift @_, $self->{__object}; 
	goto &{ ref($self->{__object}).'::'.$method };
    }
}

=item $wrapper->addMock($method, [OPTIONS])

This method is used to add a new mocked method call. Currently supports two optional parameters:

=over 2

=item * B<returns> used to specify a value to be returned when the method is called.

    $wrapper->addMock('foo', returns=>'bar')

=item * B<with> used to limit the scope of the mock based on the value of the arguments.  Test::Deep's eq_deeply is used to
match against the provided arguments, so any syntax supported there will work with Test::Mock::Wrapper;

    $wrapper->addMock('foo', with=>['baz'], returns=>'bat')

=back

The B<with> option is really only usefull to specify a different return value based on the arguments passed to the mocked method.
When addMock is called with no B<with> option, the B<returns> value is used as the "default", meaning it will be returned only
if the arguments passed to the mocked method do not match any of the provided with conditions.

For example:

    $wrapper->addMock('foo', returns=>'bar');
    $wrapper->addMock('foo', with=>['baz'], returns=>'bat');
    $wrapper->addMock('foo', with=>['bam'], returns=>'ouch');
    
    my $mocked = $wrapper->getObject;
    
    print $mocked->foo('baz');  # prints 'bat'
    print $mocked->foo('flee'); # prints 'bar'
    print $mocked->foo;         # prints 'bar'
    print $mocked->foo('bam');  # prints 'ouch'
    

=cut

sub addMock {
    my $self = shift;
    my($method, %options) = @_;
    if (exists $self->{__mocks}{$method}) {
	if ($options{with}) {
	    $self->{__mocks}{$method}{conditional_return} ||= [];
	    $self->{__mocks}{$method}{with}               ||= [];
	    push @{ $self->{__mocks}{$method}{conditional_return} }, $options{returns};
	    push @{ $self->{__mocks}{$method}{with} }, $options{with};
	}
	else{
	    $self->{__mocks}{$method}{returns} = $options{returns};
	}
    }else{
	if ($options{with}) {
	    $self->{__mocks}{$method} = {};
	    $self->{__mocks}{$method}{conditional_return} = [$options{returns}];
	    $self->{__mocks}{$method}{with}               = [$options{with}];
	}
	else{
	    $self->{__mocks}{$method} = \%options;	    
	}
    }
}


=item $wrapper->isMocked($method, $args)

This is a boolean method which returns true if a call to the specified method on the underlying wrapped object would be handled by a mock,
and false otherwise. Any conditional mocks specified with the B<with> option will be evaluated accordingly.

    $wrapper->addMock('foo', with=>['bar'], returns=>'baz');
    $wrapper->isMocked('foo', ['bam']); # False
    $wrapper->isMocked('foo', ['bar']); # True

=cut

sub isMocked {
    my $self = shift;
    my $method = shift;
    my(@args) = @_;
    if ($self->{__options}{type} eq 'stub') {
	return 1;
    }
    elsif ($self->{__options}{type} eq 'mock') {
	return $self->{__object}->can($method);
    }
    else {
	if ($self->{__mocks}{$method}) {
	    if (exists $self->{__mocks}{$method}{with}) {
		foreach my $test_set (@{ $self->{__mocks}{$method}{with} }){
		    if(eq_deeply(\@args, $test_set)){
			return 1;
		    }
		}
		if ($self->{__mocks}{$method}{returns}) {
		    return 1;
		}
		
		return;
	    }
	    else {
		return 1;
	    }
	}
	else {
	    return;
	}
    }
}

=item $wrapper->getCallsTo($method)

This method wil return an array of the arguments passed to each call to the specified method, in the order they were recieved.

=cut

sub getCallsTo {
    my $self = shift;
    my $method = shift;
    if (exists $self->{__mocks}{$method}) {
	return $self->{__calls}{$method} || [];
    }
    return;
}

=item $wrapper->verify($method)

This call returns a Test::Mock::Wrapper::Verify object, which can be used to examine any calls which have been made to the
specified method thus far.  These objects are intended to be used to simplify testing, and methods called on the it
are I<chainable> to lend to more readable tests.

=back

=cut

sub verify {
    my($self, $method, %options) = @_;
    return Test::Mock::Wrapped::Verify->new($method, $self->{__calls}{$method});    
}

package Test::Mock::Wrapped::Verify;
use Test::Deep;
use Test::More;

sub new {
    my($proto, $method, $calls) = @_;
    my $class = ref($proto) || $proto;
    return bless({__calls=>$calls, method=>$method}, $class);
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

package Test::Mock::Wrapped;
use Carp;

sub new {
    my($proto, $controller, $object) = @_;
    my $class = ref($proto) || $proto;
    return bless({__controller=>$controller, __object=>$object}, $class);
}

sub AUTOLOAD {
    my $self = shift;
    my(@args) = @_;
    $AUTOLOAD=~m/::(\w+)$/;
    my $method = $1;
    if ($self->{__controller}->isMocked($method, @args)) {
	return $self->{__controller}->_call($method, @args);
    }
    else {
	if ($self->{__object}->can($method)) {
	    unshift @_, $self->{__object}; 
	    goto &{ ref($self->{__object}).'::'.$method };
	}
	else {
	    croak qq{Can't locate object method "$method" via package "LWP::UserAgent"};
	}
    }
}


return 42;