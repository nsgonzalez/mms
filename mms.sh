#!/bin/sh

cat << EOF

 ███╗   ███╗███╗   ███╗███████╗
 ████╗ ████║████╗ ████║██╔════╝
 ██╔████╔██║██╔████╔██║███████╗
 ██║╚██╔╝██║██║╚██╔╝██║╚════██║
 ██║ ╚═╝ ██║██║ ╚═╝ ██║███████║
 ╚═╝     ╚═╝╚═╝     ╚═╝╚══════╝

===============================
 MOD_CLUSTER MANAGEMENT SCRIPT
===============================

EOF

show_nodes()
{
    MCM=`wget -qO- http://${HOST}:${PORT}/mcm | tail -n +7`  
    echo "Nodes:";
    nodeid=1
    echo "$MCM" | while read -r line; do
        if echo "$line" | grep -q "<h1> Node"; then 
            echo $line | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' | awk -v nodeid="$nodeid" '{ print "\n" nodeid ") " $0}'
	    nodeid=$((nodeid+1))
        fi
     	  
	if echo "$line" | grep -q "/mcm?nonce"; then
	    echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/([\/A-Za-z\-]*), Status\: ([A-Z]+)(.*)$/\1\t[\2]/p' | awk '{ print "  > " $0}'
        fi
    done

    echo "";
}

perform_action()
{
    URL=$1
    ACTION=$2
    if [ ! -z "$URL" ]; then
        echo "\n$ACTION from: $URL\n"
        wget -q $URL

        show_nodes
	exit 0
    fi
}

TEMP=`getopt -o h:,p:,n:,s --long host:,port:,node:,show-nodes,context-stop:,context-disable:,context-enable:,help \
	             -n '/opt/mod_cluster.sh' -- "$@"`
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

usage="usage:	./$(basename "$0") [-h|--host <ip address>] [-p|--port <port>] [-s|--show-nodes]
	./$(basename "$0") [-h|--host <ip address>] [-p|--port <port>] [-n|--node <node>] { [--context-stop] | [--context-disable] | [--context-enable] } [<Context>]

where:
    (-h|--host)			set the apache mcm host
    (-p|--port)			set the apache mcm port
    (-n|--node)			set the apache mcm node
    (-s|--show-nodes)		list all the nodes
    (--context-enable)		enable a context
    (--context-disable)		disable a context
    (--context-stop)		stop a context
    
    --help			show this help text
"

HOST='localhost'
PORT='5555'
NODE=''
while true; do
  case "$1" in
    -h | --host )
      HOST=$2;
      shift 2 ;;
    -p | --port )
      PORT=$2;
      shift 2 ;;
    -n | --node )
      NODE=$2;
      shift 2 ;;
    --context-stop | --context-disable | --context-enable )

      [ -z "$NODE" ] && echo "--node parameter is missing\n" && exit 0
      action=`echo "$1" | awk -F '-' '{print $4}'`;
      context="$2"

      MCM=`wget -qO- http://${HOST}:${PORT}/mcm | tail -n +7`
      [ "$action" = "stop" ] && echo "Stopping:" 
      [ "$action" = "disable" ] && echo "Disabling:" 
      [ "$action" = "enable" ] && echo "Enabling:" 

      prevnodeid=0
      nodeid=1
      echo "$MCM" | while read -r line; do
     	  if echo "$line" | grep -q "<h1> Node"; then 
              if [ $nodeid -eq $NODE ]; then
                  echo $line | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' | awk -v nodeid="$nodeid" '{ print "\n" nodeid ") " $0}'
	      fi
	      prevnodeid=$nodeid
	      nodeid=$((nodeid+1))
          fi

	  if [ $prevnodeid -eq $NODE ]; then
	      if echo "$line" | grep -q "/mcm?nonce"; then
	          echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/'"$context"', Status\: ([A-Z]+)(.*)$/'"$context"'\t[\1]/p' | awk '{ print "  > " $0}'

     	          if echo "$line" | grep -q "$context"; then 
		      if [ "$action" = "enable" ]; then
			  url=`echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(.*) <a href="(.*)">Enable<\/a>(.*)/\2/p' | awk -v host="$HOST" -v port="$PORT" '{ print "http://" host ":" port $0}'`

			  perform_action "$url" "Enabling"
		      fi
		      
		      if [ "$action" = "disable" ]; then
			  url=`echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(.*) <a href="(.*)">Disable<\/a>(.*)/\2/p' | awk -v host="$HOST" -v port="$PORT" '{ print "http://" host ":" port $0}'`

			  perform_action "$url" "Disabling"
		      fi
		      
		      if [ "$action" = "stop" ]; then
		          url=`echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(.*) <a href="(.*)">Stop/\2/p' | awk -v host="$HOST" -v port="$PORT" '{ print "http://" host ":" port $0}'`
			  
			  perform_action "$url" "Stopping"
		      fi
		  fi
	      fi
          fi
      done

      shift 2 ;;
    -s | --show-nodes )
      show_nodes;
      shift ;;
    -- ) shift; break ;;
    --help | * ) echo "$usage"; break ;;
  esac
done

