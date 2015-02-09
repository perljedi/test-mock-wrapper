package Test::Mock::Wrapper;
use base qw(Exporter);
use Data::Dumper;
use Test::Deep;
use Test::More;
our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);

BEGIN {
    @EXPORT_OK = qw(&once &at_least &at_most &exactly &never);
    %EXPORT_TAGS = ( all=> \@EXPORT_OK );
}

sub new {
    my($proto, $object) = @_;
    my $class = ref($proto) || $proto;
    my $controll = bless({__object=>$object, __mocks=>{}, __calls=>{}}, $class);
    $controll->{mocked} = Test::Mock::Wrapped->new($controll, $object);
    return $controll;
}
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
    

sub getObject {
    my $self = shift;
    return $self->{mocked};
}

sub call {
    my $self = shift;
    my $method = shift;
    push @{ $self->{__calls}{$method} }, [@_];
    if (exists $self->{__mocks}{$method}{with}) {
	my $return_offset = 0;
	foreach my $test_set (@{ $self->{__mocks}{$method}{with} }){
	    if(eq_deeply(\@_, $test_set)){
		return $self->{__mocks}{$method}{conditional_return}[$return_offset];
	    }
	    $return_offset++;
	}
    }
    return $self->{__mocks}{$method}{returns};
}

sub is_mocked {
    my $self = shift;
    my $method = shift;
    my(@args) = @_;
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

sub getCallsTo {
    my $self = shift;
    my $method = shift;
    if (exists $self->{__mocks}{$method}) {
	return $self->{__calls}{$method} || [];
    }
    return;
}

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
    ok(scalar(@{ $self->{__calls} }) == 0);
    return $self;
}

sub once {
    my $self = shift;
    ok(scalar(@{ $self->{__calls} }) == 1);
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
    ok(scalar(@{ $self->{__calls} }) == $times);
    return $self;
}


package Test::Mock::Wrapped;

sub new {
    my($proto, $controller, $object) = @_;
    my $class = ref($proto) || $proto;
    return bless({controller=>$controller, __object=>$object}, $class);
}

sub AUTOLOAD {
    my $self = shift;
    my(@args) = @_;
    $AUTOLOAD=~m/::(\w+)$/;
    my $method = $1;
    if ($self->{controller}->is_mocked($method, @args)) {
	return $self->{controller}->call($method, @args);
    }
    else {
	if ($self->{__object}->can($method)) {
	    unshift @_, $self->{__object}; 
	    goto &{ ref($self->{__object}).'::'.$method };
	}
	else {
	    die "No such method";
	}
    }
}


return 42;