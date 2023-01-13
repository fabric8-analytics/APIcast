## APIcast Development

### Inspecting an element

```
ngx.log(ngx.DEBUG, require("inspect")(object))
```

### Liquid-lua

Clone [liquid-lua](https://github.com/3scale/liquid-lua) repo.

```
git clone https://github.com/3scale/liquid-lua
cd liquid-lua
```

Create the following *Dockerfile*

```
FROM ubuntu
USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    vim \
    lua5.2 \
    liblua5.2-dev \
    luarocks
RUN luarocks install lua-cjson 2.1.0-1
RUN echo 'alias lua=lua5.2' >> ~/.bashrc
ADD ./lib /home/development/lib
WORKDIR "/home/development"
CMD ["/bin/bash"]
```

Run the following:

```
docker build --tag lua_test .
docker run --name luatest -d lua_test sleep infinity
docker exec -it luatest /bin/bash
$ vi test01.lua
[paste one of the examples from https://github.com/3scale/liquid-lua]
$ lua test01.lua
```
