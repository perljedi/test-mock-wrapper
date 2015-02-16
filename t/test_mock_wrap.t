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

