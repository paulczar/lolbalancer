# lolbalancer

A very small (<100 lines) bash script that watches an etcd path and creates IPVS loadbalancing based on the results.

Designed to work with [Registrator](https://github.com/gliderlabs/registrator) style service registration and [etcd](http://coreos.com).

Since IPVS is an in kernel loadbalancer we need to ensure the following modules are enabled in your host OS: `ip_vs`, `ip_vs_rr`, `ip_vs_sh`, you also need to use the `--privileged` and `--net=host` arguments in your `docker run` command.

_Warning: When sent a `kill` command it will attempt to remove the Virtual Server, if you send it a `kill -9` or a `docker rm -f` it may not remove it properly and may need to be removed via `ipvsadm -D`_

## Configuration

lolbalancer is configured via environment variables passed in by Docker.  These are:

* `ETCD_HOST` the ip:port of your etcd server, ex: 127.0.0.1:4001
* `ETCD_PATH` the etcd path of your services, ex: /nginx-80
* `SOURCE` the ip:port that you want to perform the load balancing on
* `TTL` time to wait between polling etcd in seconds. default: 10
* `TYPE` the loadbalancing scheduler. default: rr (supports any of the ipvs lb schedulers as long as the correct kernel modules are loaded)
* `DEBUG` set to enable debug logging 

## Examples

### Web

Ensure ipvs modules are enabled:

```
$ sudo modprobe ip_vs
$ sudo modprobe ip_vs_rr
```

Run an ETCD container:

```
$ docker run -d --net=host \
    --name etcd quay.io/coreos/etcd:v2.2.3 
```

Run registrator and connect it up to the etcd API:

```
$ docker run -d \
    --name=registrator \
    --net=host \
    --volume=/var/run/docker.sock:/tmp/docker.sock:ro \
    gliderlabs/registrator:latest \
      etcd://localhost:4001
```

Run three nginx containers:

```
$ docker run -d -p 80 --name nginx1 nginx
$ docker run -d -p 80 --name nginx2 nginx
$ docker run -d -p 80 --name nginx3 nginx
```

Run the lolbalancer container:

```
$ docker run -d --privileged --net=host \
  -e DEBUG=1 \
  -e ETCD_PATH=/nginx-80 \
  -e ETCD_HOST=127.0.0.1:4001 \
  -e SOURCE=127.0.0.1:8080 \
  -e TYPE=rr \
  --name lolbalancer \
  paulczar/lolbalancer
```

Check that it's working:

```
$ curl localhost:8080
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>

```

View the loadbalancer container logs:

```
$ docker logs lolbalancer               
==> Starting etcd backed IPVS Load Balancing
----> ipvsadm test successful
----> Loading Configuration
ETCD_PATH set to /nginx-80
etcd host: 127.0.0.1:4001
Loadbalancing for 127.0.0.1:8080
Using IPVS Scheduler: rr
Settings TTL: 10 seconds
----> Creating Virtual Server 127.0.0.1:8080
----> Adding 127.0.1.1:32769
----> Adding 127.0.1.1:32770
----> Adding 127.0.1.1:32768
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  localhost:http-alt rr
  -> paulczarlaptop:32768         Masq    1      0          1         
  -> paulczarlaptop:32769         Masq    1      0          1         
  -> paulczarlaptop:32770         Masq    1      0          0         
```

Get load balancer statistics:

```
$ docker exec lolbalancer ipvsadm -L -n --stats
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port               Conns   InPkts  OutPkts  InBytes OutBytes
  -> RemoteAddress:Port
TCP  127.0.0.1:8080                      1        6        4      398     1065
  -> 127.0.1.1:32776                     1        6        4      398     1065
  -> 127.0.1.1:32777                     0        0        0        0        0

$ docker exec lolbalancer ipvsadm -L -n --rate 
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port                 CPS    InPPS   OutPPS    InBPS   OutBPS
  -> RemoteAddress:Port
TCP  127.0.0.1:8080                      0        0        0        0        0
  -> 127.0.1.1:32776                     0        0        0        0        0
  -> 127.0.1.1:32777                     0        0        0        0        0
  -> 127.0.1.1:32778                     0        0        0        0        0
```

Cleanup:

_Stop lolbalancer without using `-f` to ensure the loadbalancer is stopped gracefully._

```
$ docker stop lolbalancer && docker rm lolbalancer
$ docker rm -f nginx1 nginx2 nginx3 etcd registrator

```

### MySQL

If you are running [Percona Galera](http://github.com/paulczar/percona-galera) across several CoreOS nodes the following will Load Balance them with Source Hashing: 


```
$ sudo modprobe ip_vs
$ sudo modprobe ip_vs_sh

$ docker run -d --privileged \
  -e DEBUG=1 \
  -e ETCD_PATH=/services/database_port \
  -e ETCD_HOST=172.17.8.102:4001 \
  -e SOURCE=172.17.8.102:3307 \
  -e TYPE=sh \
  --name lolbalancer \
  paulczar/lolbalancer
```
