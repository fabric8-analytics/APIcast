use lib 't';
use Test::APIcast::Blackbox 'no_plan';

# Test::Nginx does not allow to grep access logs, so we redirect them to
# stderr to be able to use "grep_error_log" by setting APICAST_ACCESS_LOG_FILE
$ENV{APICAST_ACCESS_LOG_FILE} = "$Test::Nginx::Util::ErrLogFile";

sub large_param {
  my $res = "";
  for (my $i=0; $i <= 1024; $i++) {
    $res = $res . "aaaaaaaaaa";
  }
  return $res;
}

$ENV{'LARGE_PARAM'} = large_param();

repeat_each(2);

run_tests();

__DATA__

=== TEST 1: validate that request_id is present.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
--- upstream
  location / {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- response_body env
yay, api backend: test:$TEST_NGINX_SERVER_PORT
--- error_code: 200
--- error_log eval
qr/requestID=[0-9,a-z]{32}/
--- no_error_log
[error]



=== TEST 2: request_id are not present if LOG_LEVEL!=debug.
--- log_level: info
--- env eval
(
  'APICAST_LOG_LEVEL' => 'info',
)
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
--- upstream
  location / {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- response_body env
yay, api backend: test:$TEST_NGINX_SERVER_PORT
--- error_code: 200
--- no_error_log
requestID=
--- no_error_log
[error]

=== TEST 3: Access log has the correct host.
--- configuration
{
  "services": [
    {
      "id": 42,
      "backend_version":  1,
      "backend_authentication_type": "service_token",
      "backend_authentication_value": "token-value",
      "proxy": {
        "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/",
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      ngx.exit(200)
    }
  }
--- upstream
  location / {
     echo 'yay, api backend: $http_host';
  }
--- request
GET /?user_key=value
--- response_body env
yay, api backend: test:$TEST_NGINX_SERVER_PORT
--- error_code: 200
--- error_log eval
qr/\+0000\] localhost\:\d+ 127\.0\.0\.1\:\d+/
--- no_error_log
[error]


=== TEST 4: large URI is handled correctly without leaving variables uninitialized.
--- configuration
{
  "services": [
    {
      "id": 42,
      "proxy": {
        "proxy_rules": [
          { "pattern": "/", "http_method": "GET", "metric_system_name": "hits", "delta": 2 }
        ]
      }
    }
  ]
}
--- request eval
"GET /?user_key=value&large_param=$ENV{LARGE_PARAM}"
--- error_code: 414
--- no_error_log eval
[
  qr/using uninitialized \"\w+\" variable while logging request/
]
