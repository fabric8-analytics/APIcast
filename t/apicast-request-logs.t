use lib 't';
use Test::APIcast::Blackbox 'no_plan';

repeat_each(1);

run_tests();

__DATA__

=== TEST 1: request logs and response codes are not sent unless opt-in
Response codes cannot be sent when the request is not cached. In that
case, the authrep is called before calling the upstream, so the
response code is not available. Response codes are only sent in the
post-action phase.
--- configuration
{
    "services" : [
        {
            "id": 42,
            "backend_version": 1,
            "proxy" : {
                "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api/",
                "proxy_rules": [
                    { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "bar", "delta" : 1}
                ]
            }
        }
    ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local args = ngx.req.get_uri_args()
      ngx.log(ngx.DEBUG, "======= BACKEND_ARGS =========== ")
      for key, val in pairs(args) do
        ngx.log(ngx.DEBUG, key, ": ", val)
      end
      ngx.log(ngx.DEBUG, "======= BACKEND_ARGS END =========== ")
      ngx.exit(200)
    }
  }
--- upstream
  location /api/ {
    echo "api response";
  }
--- pipelined_requests eval
["GET /foo?user_key=somekey","GET /foo?user_key=somekey"]
--- response_body eval
["api response\n","api response\n"]
--- error_code eval
["200","200"]
--- grep_error_log
qr/log\[\w+\]:.+/
--- grep_error_log_out
--- no_error_log
[error]

=== TEST 2: response codes are sent when opt-in
--- env eval
(
  'APICAST_RESPONSE_CODES' => '1'
)

--- configuration
{
    "services" : [
        {
            "id": 42,
            "backend_version": 1,
            "proxy" : {
                "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api/",
                "proxy_rules": [
                    { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "bar", "delta" : 1}
                ]
            }
        }
    ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local args = ngx.req.get_uri_args()
      ngx.log(ngx.DEBUG, "======= BACKEND_ARGS ===========")
      for key, val in pairs(args) do
        ngx.log(ngx.DEBUG, key, ": ", val)
      end
      ngx.log(ngx.DEBUG, "======= BACKEND_ARGS END ===========")
      ngx.exit(200)
    }
  }
--- upstream
  location /api/ {
    echo "api response";
    echo_status 201;
  }
--- pipelined_requests eval
["GET /foo?user_key=somekey","GET /foo?user_key=somekey"]
--- response_body eval
["api response\n","api response\n"]
--- error_code eval
["201","201"]
--- grep_error_log
qr/log\[\w+\]:.+/
--- grep_error_log_out eval
["", "log[code]: 201"]
--- no_error_log
[error]

=== TEST 3: response codes with multiple reporting threads
--- env eval
(
  'APICAST_RESPONSE_CODES' => '1',
  'APICAST_REPORTING_THREADS' => '4'
)

--- configuration
{
    "services" : [
        {
            "id": 42,
            "backend_version": 1,
            "proxy" : {
                "api_backend": "http://test:$TEST_NGINX_SERVER_PORT/api/",
                "proxy_rules": [
                    { "pattern" : "/", "http_method" : "GET", "metric_system_name" : "bar", "delta" : 1}
                ]
            }
        }
    ]
}
--- backend
  location /transactions/authrep.xml {
    content_by_lua_block {
      local args = ngx.req.get_uri_args()
      ngx.log(ngx.DEBUG, "======= BACKEND_ARGS ===========")
      for key, val in pairs(args) do
        ngx.log(ngx.DEBUG, key, ": ", val)
      end
      ngx.log(ngx.DEBUG, "======= BACKEND_ARGS END ===========")
      ngx.exit(200)
    }
  }
--- upstream
  location /api/ {
    echo "api response";
    echo_status 201;
  }
--- pipelined_requests eval
[
    "GET /bar?user_key=somekey",
    "GET /test?user_key=somekey",
    "GET /foo?user_key=somekey",
    "GET /?user_key=somekey"
]
--- response_body eval
[
    "api response\n",
    "api response\n",
    "api response\n",
    "api response\n"
]
--- error_code eval
["201","201","201","201"]
--- grep_error_log
qr/log\[\w+\]:.+/
--- grep_error_log_out eval
["", "log[code]: 201", "log[code]: 201", "log[code]: 201"]
--- no_error_log
[error]
