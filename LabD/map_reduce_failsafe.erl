-module(map_reduce_failsafe).
-compile([export_all,nowarn_export_all]).

%% We begin with a simple sequential implementation, just to define
%% the semantics of map-reduce. 

%% The input is a collection of key-value pairs. The map function maps
%% each key value pair to a list of key-value pairs. The reduce
%% function is then applied to each key and list of corresponding
%% values, and generates in turn a list of key-value pairs. These are
%% the result.

map_reduce_seq(Map,Reduce,Input) ->
    Mapped = [{K2,V2}
	      || {K,V} <- Input,
		 {K2,V2} <- Map(K,V)],
    io:format("Map phase complete\n"),
    reduce_seq(Reduce,Mapped).

reduce_seq(Reduce,KVs) ->
    [KV || {K,Vs} <- group(lists:sort(KVs)),
	   KV <- Reduce(K,Vs)].

group([]) ->
    [];
group([{K,V}|Rest]) ->
    group(K,[V],Rest).

group(K,Vs,[{K,V}|Rest]) ->
    group(K,[V|Vs],Rest);
group(K,Vs,Rest) ->
    [{K,lists:reverse(Vs)}|group(Rest)].

map_reduce_failsafe(Map,M,Reduce,R,Input) ->
    monitor_nodes_init(),
    Splits = split_into(M,Input),
    Mappeds = 
        [map_async(Node,Map,R,Split)
        || {Split, Node} <- rotate_zip(Splits, get_nodes())],
    io:format("Map phase complete\n"),
    Len = length(Mappeds),
    io:format("MAPPEDS LEN: ~p\n", [Len]),
    io:format("MAPPEDS: ~p\n", [Mappeds]),
    Reduceds =
        [reduce_async(Node,Reduce,I,Mappeds) 
        || {I, Node} <- rotate_zip(lists:seq(0,R-1), get_nodes())],
    io:format("Reduce phase complete\n"),
    io:format("REDUCEDS: ~p\n", [Reduceds]),
    close_file_nodes(),
    lists:sort(lists:flatten(Reduceds)).

node_count() -> 2.
get_nodes(N) -> lists:map(fun (Num) -> list_to_atom(atom_to_list('n') ++ integer_to_list(Num) ++ atom_to_list('@pbs-iMac')) end, lists:seq(1,N)).
get_nodes() -> get_nodes(node_count()).

monitor_nodes_init() ->
    Parent = self(),
    Ref = make_ref(),
    spawn_link(fun () -> monitor_nodes_init(Parent, get_nodes(), Ref) end),
    receive
        {Ref, init_done} -> io:format("Initialised all nodes.\n", [])
    end.
    %c:nl(map_reduce_failsafe).

monitor_nodes_init(Parent, Ns, Ref) ->
    PingPangPong = lists:map(fun(Node) ->
        case net_adm:ping(Node) of
            pong ->
                io:format("Init and monitor node ~p\n", [Node]),
                monitor_node(Node, true),
                rpc:call(Node,dets,open_file,["web.dat"]),
                {pong, Node};
            pang ->
                {pang, Node}
        end
    end, Ns),
    Pangs = lists:filter(fun ({P, _}) -> P == pang end, PingPangPong),
    if
        length(Pangs) > 0 ->
            monitor_nodes_init(Parent, lists:map(fun ({_, Node}) -> Node end, Pangs), Ref);
        true -> 
            Parent ! {Ref, init_done},
            monitor_nodes([])
    end.

monitor_nodes([]) ->
    receive
        {nodedown, Node} -> 
            io:format("Reconnecting to ~p\n", [Node]),
            monitor_nodes([Node]);
        notalive -> exit(no_local_node)
    end;

monitor_nodes(Ns) ->
    PingPangPong = lists:map(fun(Node) ->
        case net_adm:ping(Node) of
            pong ->
                io:format("Init and monitor node ~p\n", [Node]),
                monitor_node(Node, true),
                rpc:call(Node,dets,open_file,["web.dat"]),
                {pong, Node};
            pang ->
                {pang, Node}
        end
    end, Ns),
    Pangs = lists:filter(fun ({P, _}) -> P == pang end, PingPangPong),
    if
        length(Pangs) > 0 ->
            monitor_nodes(lists:map(fun ({_, Node}) -> Node end, Pangs));
        true ->
            receive
                {nodedown, Node} -> 
                    io:format("Reconnecting to ~p\n", [Node]),
                    monitor_nodes([Node]);
                notalive -> exit(no_local_node)
            end
    end.


% open_file_nodes() -> lists:map(fun(Node) -> rpc:call(Node,dets,open_file,["web.dat"]) end, get_nodes()).
close_file_nodes() -> lists:map(fun(Node) -> rpc:call(Node,dets,close,["web.dat"]) end, get_nodes()).

map_async(Node,Map,R,Split) ->
    Key = rpc:async_call(Node, map_reduce_failsafe, mapper_dist, [Map,R,Split]),
    case catch rpc:yield(Key) of
        {badrpc, Reason} -> [];
        Result -> Result    
    end.

mapper_dist(Map,R,Split) ->
    Mapped = [{erlang:phash2(K2,R),{K2,V2}}
				  || {K,V} <- Split,
				     {K2,V2} <- catch Map(K,V)],
                        io:format("."),
    group(lists:sort(Mapped)).

split_into(N,L) ->
    split_into(N,L,length(L)).

split_into(1,L,_) ->
    [L];
split_into(N,L,Len) ->
    {Pre,Suf} = lists:split(Len div N,L),
    [Pre|split_into(N-1,Suf,Len-(Len div N))].

rotate_zip([F], [S|_]) ->
    [{F, S}];
rotate_zip([F|Fs], [S|Ss]) ->
    [{F, S}] ++ rotate_zip(Fs, Ss ++ [S]).

reduce_async(Node,Reduce,I,Mappeds) ->
    Key = rpc:async_call(Node, map_reduce_failsafe, reducer_dist, [Reduce,I,Mappeds]),
    case catch rpc:yield(Key) of
        {badrpc, Reason} -> [];
        Result -> Result    
    end.

reducer_dist(Reduce,I,Mappeds) ->
    Inputs = [KV
	      || Mapped <- Mappeds,
		 {J,KVs} <- Mapped,
		 I==J,
		 KV <- KVs],
    Result = reduce_seq(Reduce,Inputs),
    io:format("."),
    Result.

yields_async([]) -> [];
yields_async([K]) ->
    case catch rpc:yield(K) of
        {badrpc, R} -> [{badrpc, R}];
        Res -> [Res]
    end;
yields_async([K|Ks]) ->
    case catch rpc:yield(K) of
        {badrpc, R} -> [{badrpc, R}] ++ yields_async(Ks);
        Res -> [Res] ++ yields_async(Ks)
    end.