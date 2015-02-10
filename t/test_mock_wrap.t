#!/usr/local/bin/perl
use strict;
use warnings;
use Test::Spec;
use Test::More;
use lib qw(..);
use Test::Mock::Wrapper;
use base qw(Test::Spec);

describe "Test::Mock::Wrapper" => sub {
    describe "type=wrap" => sub {
	my($mock);
	before sub {
	    $mock = Test::Mock::Wrapper->new(UnderlyingObjectToTest->new());  
	};
	it "uses mocked response for basic mocked method" => sub {
	    $mock->addMock('foo', returns=>'bam');
	    is($mock->getObject->foo(), 'bam');
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
	it "uses mocked response for basic mocked method" => sub {
	    $mock->addMock('foo', returns=>'bam');
	    is($mock->getObject->foo(), 'bam');
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
	it "uses mocked response for basic mocked method" => sub {
	    $mock->addMock('foo', returns=>'bam');
	    is($mock->getObject->foo(), 'bam');
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