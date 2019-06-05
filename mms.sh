#!/bin/bash

show_logo() {
  cat <<EOF

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
}

show_nodes() {
  MCM=$(wget -qO- http://${HOST}:${PORT}/mcm | tail -n +7)
  if $NOJSON && $NOTSILENT; then echo -e "\nNodes:"; fi
  if $JSON; then echo "[{"; fi

  nodeid=1

  if $JSON; then
    prevline=""
  fi

  echo "$MCM" | while read -r line; do
    if $JSON; then

      if [ $nodeid -gt 1 ]; then
        if echo "$prevline" | grep -q "<h1> Node"; then
          echo -e "},\n{"
        fi
      fi

      if echo "$prevline" | grep -q "<h1> Node"; then
        echo $prevline | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' |
          awk -F ' [(]ajp' '{print $1}' |
          awk -v nodeid="$nodeid" '{ print "\t\"id\": " nodeid ",\n\t\"name\": \"" $0 "\","}'
        echo $prevline | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' |
          awk -F ' [(]ajp' '{print "ajp" $2}' |
          awk -F '[)]' '{print $1}' | awk '{ print "\t\"url\": \"" $0 "\","}'
        nodeid=$((nodeid + 1))
      fi

      if echo "$prevline" | grep -q "Balancer:"; then
        echo $prevline | sed -rn 's/Balancer: ([A-Za-z0-9]+),LBGroup: ([A-Za-z0-9]+),(.*)Ping: ([0-9]+),(.*)Status: ([A-Za-z]+),(.*)Read: ([0-9]+),Transferred: ([0-9]+),(.*)/\t\"ping\": \4,\n\t\"status\": \"\6\",\n\t\"read\": \8,\n\t\"transferred\": \9,\n\t\"contexts\": [{/p'
      fi

      if echo "$prevline" | grep -q "/mcm?nonce"; then
        echo $prevline | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' |
          sed -rn 's/([\/A-Za-z\-]*), Status\: ([A-Z]+)(.*)$/\1/p' |
          awk '{ print "\t\t\"name\": \"" $0 "\","}'
        echo $prevline | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' |
          sed -rn 's/([\/A-Za-z\-]*), Status\: ([A-Z]+) Request: ([0-9]+)(.*)$/\3/p' |
          awk '{ print "\t\t\"requests\": " $0 ","}'

        if echo $line | grep -q "</pre><h3>Aliases:</h3><pre>"; then
          echo $prevline | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' |
            sed -rn 's/([\/A-Za-z\-]*), Status\: ([A-Z]+)(.*)$/\"status\": \"\2\"/p' |
            awk '{ print "\t\t"$0 "\n\t}]"}'
        else
          echo $prevline | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' |
            sed -rn 's/([\/A-Za-z\-]*), Status\: ([A-Z]+)(.*)$/\"status\": \"\2\"/p' |
            awk '{ print "\t\t"$0 "\n\t}, {"}'
        fi
      fi
    else
      if echo "$line" | grep -q "<h1> Node"; then
        echo $line | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' | awk -v nodeid="$nodeid" '{ print "\n" nodeid ") " $0 "\n"}'
        nodeid=$((nodeid + 1))
      fi

      if echo "$line" | grep -q "Balancer:"; then
        echo $line | sed -rn 's/Balancer: ([A-Za-z0-9]+),LBGroup: ([A-Za-z0-9]+),(.*)Ping: ([0-9]+),(.*)Status: ([A-Za-z]+),(.*)Read: ([0-9]+),Transferred: ([0-9]+),(.*)/   Ping: \4\tStatus: \6\tRead: \8\t Transferred: \9\n/p'
      fi

      if echo "$line" | grep -q "/mcm?nonce"; then
        echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/([\/A-Za-z\-]*), Status\: ([A-Z]+) Request\: ([0-9]+)(.*)$/\1\t[\2]\tRequests: \3/p' | awk '{ print "   > " $0}'
      fi
    fi

    prevline=$(echo "$line")
  done

  if $JSON; then echo "}]"; else echo ""; fi
}

perform_action() {
  URL=$1
  ACTION=$2
  if [ ! -z "$URL" ]; then
    if $NOJSON && $NOTSILENT; then
      echo -e "\n$ACTION from: $URL\n"
    fi

    wget -qO /dev/null $URL

    if $NOTSILENT; then
      show_nodes
    fi
    exit 0
  fi
}

TEMP=$(getopt -o h:,p:,n:,s --long host:,port:,node:,silent,json,show-nodes,context-stop:,context-disable:,context-enable:,get-status,get-requests:,help \
  -n '/opt/mod_cluster.sh' -- "$@")
if [ $? != 0 ]; then
  echo "Terminating..." >&2
  exit 1
fi
eval set -- "$TEMP"

usage="usage:	./$(basename "$0") [-h|--host <ip address>] [-p|--port <port>] [-s|--show-nodes]
	./$(basename "$0") [-h|--host <ip address>] [-p|--port <port>] [-n|--node <node>] { [--context-stop] | [--context-disable] | [--context-enable] } [<Context>]
	./$(basename "$0") [-h|--host <ip address>] [-p|--port <port>] [-n|--node <node>] [--get-status]
	./$(basename "$0") [-h|--host <ip address>] [-p|--port <port>] [-n|--node <node>] [--get-requests] [<Context>]

where:
    (-h|--host)			set the apache mcm host
    (-p|--port)			set the apache mcm port
    (-n|--node)			set the apache mcm node
    (-s|--show-nodes)		list all the nodes
    (--context-enable)		enable a context
    (--context-disable)		disable a context
    (--context-stop)		stop a context
    (--get-status)		  get the status of a node
    (--get-requests)		get the number of requests for a context
    
    --silent		silent mode
    --json		 json output
    --help			show this help text
"

HOST='localhost'
PORT='5555'
NODE=''
NOTSILENT=true
JSON=false
NOJSON=true
while true; do
  case "$1" in
  -h | --host)
    HOST=$2
    shift 2
    ;;
  -p | --port)
    PORT=$2
    shift 2
    ;;
  -n | --node)
    NODE=$2
    shift 2
    ;;
  --silent)
    NOTSILENT=false
    shift
    ;;
  --json)
    JSON=true
    NOJSON=false
    shift
    ;;
  --context-stop | --context-disable | --context-enable)
    if $NOJSON && $NOTSILENT; then show_logo; fi

    [ -z "$NODE" ] && echo "--node parameter is missing\n" && exit 0
    action=$(echo "$1" | awk -F '-' '{print $4}')
    context="$2"

    MCM=$(wget -qO- http://${HOST}:${PORT}/mcm | tail -n +7)
    if $NOJSON && $NOTSILENT; then
      [ "$action" = "stop" ] && echo "Stopping:"
      [ "$action" = "disable" ] && echo "Disabling:"
      [ "$action" = "enable" ] && echo "Enabling:"
    fi

    prevnodeid=0
    nodeid=1
    echo "$MCM" | while read -r line; do
      if echo "$line" | grep -q "<h1> Node"; then
        if [ $nodeid -eq $NODE ]; then
          if $NOJSON && $NOTSILENT; then echo $line | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' | awk -v nodeid="$nodeid" '{ print "\n" nodeid ") " $0}'; fi
        fi
        prevnodeid=$nodeid
        nodeid=$((nodeid + 1))
      fi

      if [ $prevnodeid -eq $NODE ]; then
        if echo "$line" | grep -q "/mcm?nonce"; then
          if $NOJSON && $NOTSILENT; then
            echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/'"$context"', Status\: ([A-Z]+)(.*)$/'"$context"'\t[\1]/p' | awk '{ print "   > " $0 "\n"}'
          fi

          if echo "$line" | grep -q "$context"; then
            if [ "$action" = "enable" ]; then
              url=$(echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(.*) <a href="(.*)">Enable<\/a>(.*)/\2/p' | awk -v host="$HOST" -v port="$PORT" '{ print "http://" host ":" port $0}')

              perform_action "$url" "Enabling"
            fi

            if [ "$action" = "disable" ]; then
              url=$(echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(.*) <a href="(.*)">Disable<\/a>(.*)/\2/p' | awk -v host="$HOST" -v port="$PORT" '{ print "http://" host ":" port $0}')

              perform_action "$url" "Disabling"
            fi

            if [ "$action" = "stop" ]; then
              url=$(echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(.*) <a href="(.*)">Stop/\2/p' | awk -v host="$HOST" -v port="$PORT" '{ print "http://" host ":" port $0}')

              perform_action "$url" "Stopping"
            fi
          fi
        fi
      fi
    done

    shift 2
    ;;
  --get-status)
    if $NOJSON && $NOTSILENT; then show_logo; fi

    [ -z "$NODE" ] && echo "--node parameter is missing\n" && exit 0

    MCM=$(wget -qO- http://${HOST}:${PORT}/mcm | tail -n +7)

    prevnodeid=0
    nodeid=1
    echo "$MCM" | while read -r line; do
      if echo "$line" | grep -q "<h1> Node"; then
        if [ $nodeid -eq $NODE ]; then
          if $NOJSON && $NOTSILENT; then
            echo $line | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' | awk -v nodeid="$nodeid" '{ print "\n" nodeid ") " $0}'
          fi
        fi
        prevnodeid=$nodeid
        nodeid=$((nodeid + 1))
      fi

      if [ $prevnodeid -eq $NODE ]; then
        if echo "$line" | grep -q "Balancer:"; then
          if $JSON; then
            echo $line | sed -rn 's/(.*)Status: ([A-Za-z]+),(.*)/{"status": "\2"}/p'
          else
            if $NOTSILENT; then
              echo $line | sed -rn 's/(.*)Status: ([A-Za-z]+),(.*)/Status: \2/p' | awk '{ print "   > " $0 "\n"}'
            else
              echo $line | sed -rn 's/(.*)Status: ([A-Za-z]+),(.*)/\2/p'
            fi
          fi
        fi
      fi
    done

    shift
    ;;
  --get-requests)
    if $NOJSON && $NOTSILENT; then show_logo; fi

    [ -z "$NODE" ] && echo "--node parameter is missing\n" && exit 0
    context="$2"

    MCM=$(wget -qO- http://${HOST}:${PORT}/mcm | tail -n +7)

    prevnodeid=0
    nodeid=1
    echo "$MCM" | while read -r line; do
      if echo "$line" | grep -q "<h1> Node"; then
        if [ $nodeid -eq $NODE ]; then
          if $NOJSON && $NOTSILENT; then
            echo $line | sed -rn 's/^(<\/pre>){0,1}<h1> Node (.*)\: <\/h1>/\2/p' | awk -v nodeid="$nodeid" '{ print "\n" nodeid ") " $0}'
          fi
        fi
        prevnodeid=$nodeid
        nodeid=$((nodeid + 1))
      fi

      if [ $prevnodeid -eq $NODE ]; then
        if echo "$line" | grep -q "/mcm?nonce"; then
          if $JSON; then
            echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(\/)+'"$context"', Status\: ([A-Z]+) Request\: ([0-9]+)(.*)$/{"requests": "\3"}/p'
          else
            if $NOTSILENT; then
              echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/'"$context"', Status\: ([A-Z]+)(.*)$/'"$context"'\t[\1]/p' | awk '{ print "   > " $0}'
              echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(\/)+'"$context"', Status\: ([A-Z]+) Request\: ([0-9]+)(.*)$/\3/p' | awk '{ print "   > Requests: " $0}'
            else
              echo $line | sed -rn 's/^(<h2> Virtual Host [[:digit:]]+\:<\/h2><h3>Contexts\:<\/h3><pre>)*(.*)<\/a>/\2/p' | sed -rn 's/(\/)+'"$context"', Status\: ([A-Z]+) Request\: ([0-9]+)(.*)$/\3/p'
            fi
          fi
        fi
      fi
    done

    shift 2
    ;;
  -s | --show-nodes)
    if $NOJSON && $NOTSILENT; then show_logo; fi
    show_nodes
    shift
    ;;
  --)
    shift
    break
    ;;
  --help | *)
    echo "$usage"
    break
    ;;
  esac
done
