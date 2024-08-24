- [Examples](#examples)
  - [Container Run](#container-run)
    - [Run Containers using Detach and Port Mapping](#run-containers-using-detach-and-port-mapping)
    - [Stop Piped containers](#stop-piped-containers)
  - [Container Listing or Info](#container-listing-or-info)

## Examples

Note: These snippets assume you have the module `Rocker` imported.

### Container Run

#### Run Containers using Detach and Port Mapping

```ps1
🐒> Rk.Run.Publish -Port 8080 -ImageName git-logger
🐒> Rk.Run.Publish -Port 8081 -ImageName pssvg
# output: 
    # Invoke Cmd => docker run --detach --publish 8081:80 pssvg
    # Invoke Cmd => docker run --detach --publish 8080:80 git-logger
```

#### Stop Piped containers

```ps1
# Stop everything
🐒> Rk.Container.StopAll

# Stop All or Piped containers
🐒> docker container ls | docker container stop # raw Rocker
🐒> Rk.container.ls     | docker container stop # same with info
```

### Container Listing or Info
```ps1
🐒> Rk.Run.Publish -Port 8081 80 -ImageName pssvg
# out:
    # Invoke Cmd => docker run --detach --publish 8081:80 pssvg
    # 0929ee426732fc20b18fdf63eb74fd8c37eca5596123cbdbb9a3ba5ce334a22d

🐒> Rk.Container.First -AsIdName
'0929ee426732'

🐒> Rk.Container.First -AsImageName
'pssvg'
```