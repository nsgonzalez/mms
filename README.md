# mod_cluster Management Script

mms is a shell script that allows you to execute some of the functions available on Apache's mod_cluster-manager (web).

  - List all available nodes
  - Enable, Disable and Stop a Context

### Usage
```sh
$ chmod +x mms.sh
$ ./mms.sh --help

 ███╗   ███╗███╗   ███╗███████╗
 ████╗ ████║████╗ ████║██╔════╝
 ██╔████╔██║██╔████╔██║███████╗
 ██║╚██╔╝██║██║╚██╔╝██║╚════██║
 ██║ ╚═╝ ██║██║ ╚═╝ ██║███████║
 ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝

===============================
 MOD_CLUSTER MANAGEMENT SCRIPT
===============================

usage:	./mms.sh [-h|--host <ip address>] [-p|--port <port>] [-s|--show-nodes]
	./mms.sh [-h|--host <ip address>] [-p|--port <port>] [-n|--node <node>] { [--context-stop] | [--context-disable] | [--context-enable] } [<Context>]
	./mms.sh [-h|--host <ip address>] [-p|--port <port>] [-n|--node <node>] [--get-status]
	./mms.sh [-h|--host <ip address>] [-p|--port <port>] [-n|--node <node>] [--get-requests] [<Context>]

where:
    (-h|--host)             set the apache mcm host
    (-p|--port)             set the apache mcm port
    (-n|--node)             set the apache mcm node
    (-s|--show-nodes)       list all the nodes
    (--context-enable)      enable a context
    (--context-disable)     disable a context
    (--context-stop)        stop a context
    (--get-status)          get the status of a node
    (--get-requests)        get the number of requests for a context
    
    --silent    silent mode
    --json      json output
    --help      show this help text
```

#### Examples

- List all the nodes
    ```sh
    $ ./mms.sh --host 192.168.4.12 --show-nodes

    Nodes:

    1) wf411 (ajp://192.168.4.11:8009)

      Ping: 10000000       Status: OK      Read: 74         Transferred: 0

      > /TestApp-war  [ENABLED]       Requests: 0
      > /  [ENABLED]       Requests: 0
      > /wildfly-services  [ENABLED]       Requests: 0

    2) wf410 (ajp://192.168.4.10:8009)

      Ping: 10000000       Status: OK      Read: 1150       Transferred: 0

      > /TestApp-war  [ENABLED]       Requests: 0
      > /  [ENABLED]       Requests: 0
      > /wildfly-services  [ENABLED]       Requests: 0

    ```
    
- List all the nodes (json format)
    ```sh
    $ ./mms.sh --host 192.168.4.12 --json --show-nodes
    [{
            "id": 1,
            "name": "wf411",
            "url": "ajp://192.168.4.11:8009",
            "ping": 10000000,
            "status": "OK",
            "read": 74,
            "transferred": 0,
            "contexts": [{
                    "name": "/TestApp-war",
                    "requests": 0,
                    "status": "ENABLED"
            }, {
                    "name": "/",
                    "requests": 0,
                    "status": "ENABLED"
            }, {
                    "name": "/wildfly-services",
                    "requests": 0,
                    "status": "ENABLED"
            }]
    },
    {
            "id": 2,
            "name": "wf410",
            "url": "ajp://192.168.4.10:8009",
            "ping": 10000000,
            "status": "OK",
            "read": 1150,
            "transferred": 0,
            "contexts": [{
                    "name": "/TestApp-war",
                    "requests": 0,
                    "status": "ENABLED"
            }, {
                    "name": "/",
                    "requests": 0,
                    "status": "ENABLED"
            }, {
                    "name": "/wildfly-services",
                    "requests": 0,
                    "status": "ENABLED"
            }]
    }]
    ```

- Stop a context
    ```sh
    ./mms.sh --host 192.168.4.12 --node 2 --context-stop TestApp-war
    
    Stopping:
    
    2) wf410 (ajp://192.168.4.10:8009)
      > /TestApp-war        [ENABLED]
    
    Disabling from: http://192.168.4.10:5555/mcm?nonce=e87c92bd-195e-4845-91cd-2a192f14a553&Cmd=DISABLE-APP&Range=CONTEXT&JVMRoute=wf410&Alias=default-host&Context=/TestApp-war
    
    Nodes:
    
    1) wf411 (ajp://192.168.4.11:8009)
      > /TestApp-war        [ENABLED]
      > /	[ENABLED]
      > /wildfly-services	[ENABLED]
    
    2) wf410 (ajp://192.168.4.10:8009)
      > /TestApp-war        [STOPPED]
      > /	[ENABLED]
      > /wildfly-services	[ENABLED]

    ```
