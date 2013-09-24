. .bashrc
cd /home/clauz/repo_$HOSTNAME/
( while true; do ccnr; sleep 1; done ) &
sleep 3
/usr/bin/wget -q -O - "http://127.0.0.1:2012/reg/add/mega1"
sleep 3
/usr/bin/wget -q -O - "http://127.0.0.1:2012/reg/add/tests"
sleep 3

