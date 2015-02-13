Test::Mock::Wrapper
===================

This is another module for mocking objects in perl. It will wrap around
an existing object, allowing you to mock any calls for testing purposes.
It also records the arguments passed to the mocked methods for later
examination. The verification methods are designed to be chainable for
easily readable tests.

See `perldoc Test::Mock::Wrapper` for syntax example and usage information.

## Examples

### Mocking an instance
```perl
my $ua = LWP::UserAgent->new();
my $control = Test::Mock::Wrapper($ua);
my $mockedResponse = HTTP::Response->new(200, 
                                         'OK', 
                                         ['Content-Type' => 'text/plain'], 
                                         'this is not metacpan');
$control->addMock('request', with=>[HTTP::Request->new(GET=>'http://metacpan.org')], 
                             returns=>$mockedResponse);

my $res = $control->getObject->request(HTTP::Request->new(GET=>'http://metacpan.org'));
is($res, $mockedResponse);
$control->verify('request')->exactly(1);
```

### Mocking the entire package

```perl
my $control = Test::Mock::Wrapper('LWP::UserAgent');
my $mockedResponse = HTTP::Response->new(200,
                                         'OK', 
                                         ['Content-Type' => 'text/plain'],
                                         'this is not metacpan');
$control->addMock('request', with=>[HTTP::Request->new(GET=>'http://metacpan.org')], 
                             returns=>$mockedResponse);

my $ua = LWP::UserAgent->new();
my $res = $ua->request(HTTP::Request->new(GET=>'http://metacpan.org'));
is($res, $mockedResponse);
$control->verify('request')->exactly(1);

$control->DESTROY();

my $realAgent = LWP::UserAgent->new();
# Actually Fetch metacpan!
my $res = $realAgent->request(HTTP::Request->new(GET=>'http://metacpan.org'));

