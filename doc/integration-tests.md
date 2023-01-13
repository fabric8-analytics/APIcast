## Integration testing framework

Test framework used for integration testing in APIcast: 
[openresty/test-nginx](https://github.com/openresty/test-nginx): 
Data-driven test scaffold for Nginx C module and OpenResty Lua library development.

Documentation on this framework: 
[Automated Testing · Programming OpenResty (gitbooks.io)](https://openresty.gitbooks.io/programming-openresty/content/testing/index.html).

APIcast specific extension/fork of this framework: [3scale/Test-APIcast](https://github.com/3scale/Test-APIcast):
APIcast testing framework using `Test::Nginx`.

### Run integration tests

Using Docker you just need to run:
```shell
make development
```

That will create a Docker container and run bash inside it. The project's source
code will be available in the container and sync'ed with your local `apicast`
directory, so you can edit files in your preferred environment and still be able
to run whatever you need inside the Docker container.

To install the dependencies inside the container run:
```shell
make dependencies
```

To run the integration tests inside the container:
```shell
make prove
```

### Useful tips/config & commands

To enable debug logs when running the integration tests set `DEBUG=1` before executing the tests.
This will print all the logs in `stderr` which is configured in: `$Test::Nginx::Util::ErrLogFile`.

To run a single file of tests

```shell
make prove PROVE_FILES=path/to/file.t
```

To run a single test within a test file declare the `--- ONLY` flag at the top of the test, for example: 

```
=== TEST 1: some test
--- ONLY
--- configuration
```

By default, the integration test run is randomized. You can disable this behavior setting
the [TEST_NGINX_RANDOMIZE](https://metacpan.org/pod/Test::Nginx::Socket#TEST_NGINX_RANDOMIZE)
env var to `0`.

Some integration tests are run `n` times where `n` is defined at the top of the test file in the
function [repeat_each](https://metacpan.org/pod/Test::Nginx::Socket#repeat_each).
It can be very useful to switch this to 1 when debugging failed tests.

Where env vars such as
[TEST_NGINX_SERVER_PORT](https://metacpan.org/pod/Test::Nginx::Socket#TEST_NGINX_SERVER_PORT)
are used in the test, it’s necessary to declare `env` at the top of that section in the test
as well as in any subsequent sections where that same env var then needs to be reused. For example:

```
=== TEST 1: some test
--- configuration random_port env
```

*AND* then later in 

```
--- upstream env
```

For any env vars that include a random port such as `TEST_NGINX_RANDOM_PORT`
an additional declaration is required; `random_port` only once in the first section of the test
where that env var is declared. After that `env` is sufficient in any subsequent sections in the
test to propagate the variable.

#### Integration testing with an HTTP(S) proxy

Mocking of components, configuration & environment in a reusable way is stored in the
[t/fixtures](https://github.com/3scale/APIcast/tree/master/t/fixtures) directory.
In [here](https://github.com/3scale/APIcast/blob/master/t/fixtures/proxy.lua) is the specific Lua
code for the *http forward proxy* (it’s really just an Nginx reverse proxy).
The logs are forwarded to `stdout` just like the APIcast & test logs.
The Nginx configuration and Perl code to start up the proxy server is
[here](https://github.com/3scale/APIcast/blob/master/t/http_proxy.pl).
You can see that the
[same proxy server](https://github.com/3scale/APIcast/blob/master/t/http_proxy.pl#L5-L8) is used
for both `HTTP_PROXY` & `HTTPS_PROXY` settings.
