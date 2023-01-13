# Run the policy locally

When you have completed development and unit testing of the policy, it is time to start APIcast with the policy. This way you can verify the policy works inside the NGINX process. You are going to use the APIcast development Docker image to run APIcast with the created policy.

## Create APIcast configuration

You can provision APIcast in two ways, either automatically from the 3scale APIManager or via a JSON configuration file. Since the custom policy is not available in the 3scale APIManager,  you will configure APIcast with the JSON configuration file. In the configuration file you will leverage the built-in echo service of APIcast to test the policy and receive an upstream response without running a full 3scale APIManager configuration.

The part of the JSON configuration file detailing the configuration of our policy needs to adhere to the JSON schema we defined earlier.

The location of the configuration file is arbitrary as long as the APIcast process can access the file. In this example, you will create the following file: **‘hello_world_config.json’** in the **apicast/examples/configuration** directory.

The contents of the configuration file is:

```json
{
  "services": [
    {
      "proxy": {
        "policy_chain": [
          {
            "name": "hello_world",
            "version": "builtin",
            "configuration": {
              "overwrite": true,
              "secret": "mysecret"
            }
          },
          {
            "name": "apicast.policy.upstream",
            "configuration": {
              "rules": [
                {
                  "regex": "/",
                  "url": "http://echo:8081"
                }
              ]
            }
          }
        ]
      }
    }
  ]
}
```

First, configure the hello_world policy inside the policy chain with overwrite and secret properties. Second, the upstream policy acts as an echo mock service in the policy chain, so you can receive a response.

### Starting the APIcast server
To start the APIcast server with the hello_world_configuration.json file inside the development container, run the following command:

```shell
bash-4.2$ bin/apicast --log-level=debug --dev -c examples/configuration/hello_world_config.json
```

The bin/apicast executable starts the APIcast server. Set log-level to debug which results in a large amount of debug logging.
If the amount of debug logging is too large, you can set the log-level to **notice**. This results in fewer log lines, but custom log entries in the policy are still logged.

### Executing test requests
Now that you have the APIcast server up and running, you can test if the hello_world policy works.

To test this, you must issue an HTTP request to the APIcast server, but the development Docker container does not expose any ports. You can alter the makefile or the Docker Compose file to expose the ports. In this example you will create another bash session in the development container and issue a curl request from inside the container.

Create a second bash session in a new terminal window and find the Docker container ID of the APIcast development image using the following command:

```shell
$ docker ps
CONTAINER ID        IMAGE                                         COMMAND                  CREATED             STATUS              PORTS               NAMES
5a72c49671c5        quay.io/3scale/s2i-openresty-centos7:master   "container-entrypoin…"   2 hours ago         Up 2 hours          8080/tcp            apicast_build_0_development_1_802efce654d5
366c62d0bccf        redis                                         "docker-entrypoint.s…"   2 hours ago         Up 2 hours          6379/tcp            apicast_build_0_redis_1_469bce65a85a
```

The make development command used to start the APIcast development container starts two containers. One with the APIcast development environment and another with a Redis cache. You need the container with the following image: **quay.io/3scale/s2i-openresty-centos7:master**.

In the above example, it has the ID of **5a72c49671c5**. Yours will be different. Now that you know the ID of the container, create a new bash session using the following command:

```shell
$ docker exec -it 5a72c49671c5 /bin/bash
```

Now you have another interactive bash shell in the APIcast development container, you can issue the HTTP request to test the policy from there.

In the container issue the following HTTP request:

```shell
$ curl localhost:8080
<html>
<head><title>403 Forbidden</title></head>
<body bgcolor="white">
<center><h1>403 Forbidden</h1></center>
<hr><center>openresty/1.13.6.2</center>
</body>
</html>
```

The response will be a 403 Forbidden. Look at the logs to see what has happened.

```shell
$ bin/apicast --log-level=notice --dev -c examples/configuration/hello_world_config.json
loading production environment configuration: /home/centos/gateway/config/production.lua
loading development environment configuration: /home/centos/gateway/config/development.lua
2019/04/29 09:32:33 [notice] 257#257: [lua] environment.lua:194: add(): loading environment configuration: /home/centos/gateway/config/production.lua
2019/04/29 09:32:33 [notice] 257#257: [lua] environment.lua:194: add(): loading environment configuration: /home/centos/gateway/config/development.lua
2019/04/29 09:32:33 [notice] 257#257: using the "epoll" event method
2019/04/29 09:32:33 [notice] 257#257: openresty/1.13.6.2
2019/04/29 09:32:33 [notice] 257#257: built by gcc 4.8.5 20150623 (Red Hat 4.8.5-28) (GCC)
2019/04/29 09:32:33 [notice] 257#257: OS: Linux 4.4.0-146-generic
2019/04/29 09:32:33 [notice] 257#257: getrlimit(RLIMIT_NOFILE): 1048576:1048576
2019/04/29 09:43:17 [notice] 257#257: *6 [lua] hello_world.lua:53: request is not authorized, secrets do not match, client: 127.0.0.1, server: _, request: "GET / HTTP/1.1", host: "localhost:8080"
[29/Apr/2019:09:43:17 +0000] localhost:8080 127.0.0.1:40946 "GET / HTTP/1.1" 403 175 (0.000) 0
```

APIcast is running with the notice log-level, when started with the debug log-level considerable more log events will be present. The one you need is the second from the bottom.

Which states: **‘request is not authorized, secrets do not match’**. This is put in the log by the following line in the policy code:

```lua
if secret_header ~= self.secret then
 ngx.log(ngx.NOTICE, "request is not authorized, secrets do not match")
 ngx.status = 403
 return ngx.exit(ngx.status)
```

The policy is now executing. You must provide the secret header in the request to pass the validation. Issue the following HTTP request:

```shell
$ curl localhost:8080 -H 'secret: mysecret'
GET / HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
User-Agent: curl/7.29.0
Accept: */*
secret: mysecret
```

You should receive a valid 200 response from the echo server. The rewrite of query parameters to header is not tested, since the request did not contain any query parameters. Issue a new request with a query parameter to see the transformation at work. Issue the following request:

```shell
$ curl localhost:8080?myparam=myvalue -H 'secret: mysecret'
GET /?myparam=myvalue HTTP/1.1
X-Real-IP: 127.0.0.1
Host: echo
User-Agent: curl/7.29.0
Accept: */*
secret: mysecret
myparam: myvalue
```

You will see in the response, the header: myparam:myheader