for I in $(seq 1 $1);
do
    echo "spawning n$I"
    # nohup erl -sname "n$I" &>/dev/null &
    erl -sname "n$I" -detached -noshell
done