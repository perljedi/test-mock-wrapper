package Test::Mock::Wrapped;

use Carp;
use Scalar::Util qw(weaken isweak);

sub new {
    my($proto, $controller, $object) = @_;
    weaken($controller);
    my $class = ref($proto) || $proto;
    my $self = bless({__controller=>$controller, __object=>$object}, $class);
    weaken($self->{__controller});
    return $self;
}

sub AUTOLOAD {
    my $self = shift;
    my(@args) = @_;
    $Test::Mock::Wrapped::AUTOLOAD=~m/::(\w+)$/;
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
	    my $pack = ref($self->{__object});
	    croak qq{Can't locate object method "$method" via package "$pack"};
	}
    }
}

return 42;