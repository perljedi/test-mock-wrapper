#!/usr/local/bin/perl
use strict;
use warnings;
use Test::Spec;
use Test::More;
use Test::Deep;
use lib qw(..);
use Test::Mock::Wrapper;
use base qw(Test::Spec);
use Scalar::Util qw(weaken isweak);

describe "Test::Mock::Wrapper" => sub {
    describe "basic functionality" => sub {
	my($mock);
	before sub {
	    $mock = Test::Mock::Wrapper->new(UnderlyingObjectToTest->new());  
	};
	it "uses mocked response for basic mocked method" => sub {
	    $mock->addMock('foo', returns=>'bam');
	    is($mock->getObject->foo(), 'bam');
	};
	it "returns a conditional return value if the with condition is met" => sub {
	    $mock->addMock('foo', with=>['man'], returns=>'choo');
	    $mock->addMock('foo', returns=>'bam');
	    is($mock->getObject->foo('man'), 'choo');
	};
	it "returns default return value if no with condition is met" => sub {
	    $mock->addMock('foo', with=>['man'], returns=>'choo');
	    $mock->addMock('foo', returns=>'bam');
	    is($mock->getObject->foo('who'), 'bam');
	};
	it "returns first provided return value if multiple conditions are met" => sub {
	    $mock->addMock('foo', with=>['man', ignore()], returns=>'choo');
	    $mock->addMock('foo', with=>[ignore(), 'bat'], returns=>'foo');
	    is($mock->getObject->foo('man', 'bat'), 'choo');
	};
    };
    describe "type=wrap" => sub {
	my($mock);
	before sub {
	    $mock = Test::Mock::Wrapper->new(UnderlyingObjectToTest->new());  
	};
	it "calls the original object for non-mocked method" => sub {
	    is($mock->getObject->baz, 'bat');
	};
	it "dies when calling a method not available on original object" => sub {
	    eval {
		$mock->getObject->far;
		fail("should have thrown exception for non-existent method");
	    };
	    ok(defined $@);
	};
    };
    describe "type=stub" => sub {
	my($mock);
	before sub {
	    $mock = Test::Mock::Wrapper->new(UnderlyingObjectToTest->new(), type=>'stub');  
	};
	it "returns undef for non mocked method" => sub {
	    is($mock->getObject->baz, undef);
	};
	it "returns undef when calling a method not available on original object" => sub {
	    eval {
		$mock->getObject->far;
		ok("should have trapped unknow method call");
	    };
	    is($@, '', 'eval error should be null');
	};
    };
    describe "type=mock" => sub {
	my($mock);
	before sub {
	    $mock = Test::Mock::Wrapper->new(UnderlyingObjectToTest->new(), type=>'mock');  
	};
	it "returns undef for non mocked method" => sub {
	    is($mock->getObject->baz, undef);
	};
	it "dies when calling a method not available on original object" => sub {
	    eval {
		$mock->getObject->far;
		fail("should have thrown exception for non-existent method");
	    };
	    ok(defined $@);
	};
    };
    describe "Package Mocking" => sub {
	it "returns a mocked object from a call to new in the mocked package" => sub {
	    my $mocker = Test::Mock::Wrapper->new('UnderlyingObjectToTest');
	    my $test_object = UnderlyingObjectToTest->new(type=>'stub');
	    isa_ok($test_object, 'Test::Mock::Wrapped');
	    is($test_object->foo, undef);
	    $mocker->DESTROY();
	};
	it "restores underlying object after destroy" => sub {
	    my $test_object = UnderlyingObjectToTest->new();
	    isa_ok($test_object, 'UnderlyingObjectToTest');
	    is($test_object->foo, 'bar');
	};
    };

    describe "Call verification" => sub {
	my($mock);
	before sub {
	    $mock = Test::Mock::Wrapper->new(UnderlyingObjectToTest->new(), type=>'mock');  
	};
	it "suppports exact call number verification" => sub {
	    $mock->addMock('foo');
	    $mock->getObject->foo;
	    $mock->verify('foo')->exactly(1);
	    $mock->addMock('baz');
	    $mock->getObject->baz;
	    $mock->getObject->baz;
	    $mock->getObject->baz;
	    $mock->verify('baz')->exactly(3);
	};
	it "suppports never" => sub {
	    $mock->addMock('foo');
	    $mock->verify('foo')->never;
	};
	it "suppports once" => sub {
	    $mock->addMock('foo');
	    $mock->getObject->foo;
	    $mock->verify('foo')->once;
	};
	it "suppports at least" => sub {
	    $mock->addMock('foo');
	    $mock->getObject->foo;
	    $mock->getObject->foo;
	    $mock->getObject->foo;
	    $mock->verify('foo')->at_least(1);
	};
	it "suppports at most" => sub {
	    $mock->addMock('foo');
	    $mock->getObject->foo;
	    $mock->getObject->foo;
	    $mock->getObject->foo;
	    $mock->verify('foo')->at_most(4);
	};
	it "is chainable" => sub {
	    $mock->addMock('foo');
	    $mock->getObject->foo;
	    $mock->verify('foo')->once->at_least(1)->at_most(1);
	};
	it "can be queried by 'with'" => sub {
	    $mock->addMock('foo');
	    $mock->getObject->foo({name=>'dave', status=>'cool'});
	    $mock->getObject->foo({name=>'dave', status=>'smart'});
	    $mock->getObject->foo({name=>'juli', status=>'cute'});
	    $mock->getObject->foo({name=>'tom', status=>'smart'});
	    $mock->getObject->foo({name=>'dan', status=>'lazy'});
	    $mock->verify('foo')->with([{name=>'dave', status=>ignore()}])->exactly(2);
	    $mock->verify('foo')->with([{name=>'dave', status=>ignore()}])->at_least(1)->with([{name=>ignore(), status=>'cool'}])->once;
	};
	it "retains call list at each distinct state" => sub {
	    $mock->addMock('foo');
	    $mock->getObject->foo({name=>'dave', status=>'cool'});
	    $mock->getObject->foo({name=>'dave', status=>'smart'});
	    $mock->getObject->foo({name=>'juli', status=>'cute'});
	    $mock->getObject->foo({name=>'tom', status=>'smart'});
	    $mock->getObject->foo({name=>'dan', status=>'lazy'});
	    my $verifier = $mock->verify('foo');
	    $verifier->with([{name=>'dave', status=>ignore()}])->exactly(2);
	    $verifier->with([{name=>'juli', status=>ignore()}])->once;
	}
    };
};

runtests;

package UnderlyingObjectToTest;

sub new {
    return bless({}, __PACKAGE__);
}

sub foo {
    return 'bar';
}

sub baz {
    return 'bat';
}

