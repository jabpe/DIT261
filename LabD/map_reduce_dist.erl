-module(map_reduce_dist).
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

map_reduce_dist(Map,M,Reduce,R,Input) ->
    ping_nodes(),
    Splits = split_into(M,Input),
    Files = 
        [rpc:async_call(Node, dets, open_file, [web,[{file,"web.dat"}]])
        || Node <- get_nodes()],
    yields_async(Files),
    Mappers = 
        [map_async(Node,Map,R,Split)
        || {Split, Node} <- rotate_zip(Splits, get_nodes())],
    Mappeds = yields_async(Mappers),
    io:format("Map phase complete\n"),
    Reducers =
        [reduce_async(Node,Reduce,I,Mappeds) 
        || {I, Node} <- rotate_zip(lists:seq(0,R-1), get_nodes())],
    Reduceds = yields_async(Reducers),
    io:format("Reduce phase complete\n"),
    lists:sort(lists:flatten(Reduceds)).

get_nodes() -> [ 'n1@MacBook-Pro.local'].

ping_nodes([]) -> ok;
ping_nodes([N]) -> 
    case net_adm:ping(N) of
        pong -> ok;
        pang -> exit(ping_failed, N)
    end;
ping_nodes([N|Ns]) ->
    case net_adm:ping(N) of
        pong -> ping_nodes(Ns);
        pang -> exit(ping_failed, N)
    end.
ping_nodes() -> ping_nodes(get_nodes()).

map_async(Node,Map,R,Split) ->
    rpc:async_call(Node, map_reduce_dist, mapper_dist, [Map,R,Split]).

mapper_dist(Map,R,Split) ->
    Mapped = [{erlang:phash2(K2,R),{K2,V2}}
				  || {K,V} <- Split,
				    {K2,V2} <- Map(K,V)],
                    io:format(user, ".", []),
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
    Inputs = [KV
	      || Mapped <- Mappeds,
		 {J,KVs} <- Mapped,
		 I==J,
		 KV <- KVs],
    rpc:async_call(Node, map_reduce_dist, reducer_dist, [Reduce,Inputs]).

reducer_dist(Reduce,Inputs) ->
    Result = reduce_seq(Reduce,Inputs),
    io:format(user,".",[]),
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