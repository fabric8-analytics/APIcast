## Unit testing framework

[busted](https://github.com/Olivine-Labs/busted) is the framework used for the unit tests.

### Run unit tests

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

To run the unit tests inside the container:
```shell
make busted
```

To run a single file of tests

```shell
make busted BUSTED_FILES=path/to/file_spec.lua
```

To run a specific set of `it` tests, i.e. a contextual description defined
by the `describe` function, add some unique token, for instance `ONLY`, to the `describe` function.

```
describe("ONLY should be awesome", function()
```

then, add `BUSTED_ARGS` with `--filter` param

```shell
make busted BUSTED_FILES=path/to/file_spec.lua BUSTED_ARGS="--filter='ONLY'"
```
