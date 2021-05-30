-module(worker_pool).

-compile([export_all, nowarn_export_all]).

get_nodes() ->
    ['n0@MacBook-Pro.local',
     'n1@MacBook-Pro.local',
     'n2@MacBook-Pro.local',
     'n3@MacBook-Pro.local'].

map_reduce_seq(Map, Reduce, Input) ->
    Mapped = [{K2, V2}
              || {K, V} <- Input, {K2, V2} <- Map(K, V)],
    io:format("Map phase complete\n"),
    reduce_seq(Reduce, Mapped).

reduce_seq(Reduce, KVs) ->
    [KV
     || {K, Vs} <- group(lists:sort(KVs)),
        KV <- Reduce(K, Vs)].

group([]) -> [];
group([{K, V} | Rest]) -> group(K, [V], Rest).

group(K, Vs, [{K, V} | Rest]) ->
    group(K, [V | Vs], Rest);
group(K, Vs, Rest) ->
    [{K, lists:reverse(Vs)} | group(Rest)].

map_reduce_dist(Map, M, Reduce, R, Input) ->
    ping_nodes(),
    Splits = split_into(M, Input),
    Files = [rpc:async_call(Node,
                            dets,
                            open_file,
                            [web, [{file, "web.dat"}]])
             || Node <- get_nodes()],
    yields_async(Files),
    Mappers = [map_async(Map, R, Split) || Split <- Splits],
    Mappeds = worker_pool(Mappers),
    io:format("Map phase complete\n"),
    Reducers = [reduce_async(Reduce, I, Mappeds)
                || I <- lists:seq(0, R - 1)],
    Reduceds = worker_pool(Reducers),
    io:format("Reduce phase complete\n"),
    lists:sort(lists:flatten(Reduceds)).

ping_nodes([]) -> ok;
ping_nodes([N]) ->
    case net_adm:ping(N) of
        pong -> ok;
        pang -> exit(ping_failed, N)
    end;
ping_nodes([N | Ns]) ->
    case net_adm:ping(N) of
        pong -> ping_nodes(Ns);
        pang -> exit(ping_failed, N)
    end.

ping_nodes() -> ping_nodes(get_nodes()).

map_async(Map, R, Split) ->
    fun () ->
            Mapped = [{erlang:phash2(K2, R), {K2, V2}}
                      || {K, V} <- Split, {K2, V2} <- Map(K, V)],
            io:format(user, ".", []),
            group(lists:sort(Mapped))
    end.

split_into(N, L) -> split_into(N, L, length(L)).

split_into(1, L, _) -> [L];
split_into(N, L, Len) ->
    {Pre, Suf} = lists:split(Len div N, L),
    [Pre | split_into(N - 1, Suf, Len - Len div N)].

reduce_async(Reduce, I, Mappeds) ->
    fun () ->
            Inputs = [KV
                      || Mapped <- Mappeds, {J, KVs} <- Mapped, I == J,
                         KV <- KVs],
            Result = reduce_seq(Reduce, Inputs),
            io:format(user, ".", []),
            Result
    end.

yields_async([]) -> [];
yields_async([K]) ->
    case catch rpc:yield(K) of
        {badrpc, R} -> [{badrpc, R}];
        Res -> [Res]
    end;
yields_async([K | Ks]) ->
    case catch rpc:yield(K) of
        {badrpc, R} -> [{badrpc, R}] ++ yields_async(Ks);
        Res -> [Res] ++ yields_async(Ks)
    end.

factorial(0) -> 1;
factorial(N) -> N * factorial(N - 1).

test() ->
    [net_adm:ping(E) || E <- get_nodes()],
    Funs = [fun () -> factorial(N) end
            || N <- lists:seq(0, 10)],
    worker_pool(Funs).

create_collector(N, Callback) ->
    spawn_link(fun () ->
                       Callback !
                           {result,
                            [receive {Index, Res} -> Res end
                             || Index <- lists:seq(0, N - 1)]}
               end).

worker_pool(Funs) ->
    CollectorPid = create_collector(length(Funs), self()),
    NodeCount = length(nodes()),
    {InitialFuns, LaterFuns} = lists:split(NodeCount, Funs),
    spawn_link(fun () ->
                       % Spawn initial workers
                       [spawn_link(Node,
                                   worker_pool,
                                   worker_wrapper,
                                   [Fun, Index, CollectorPid, self()])
                        || {{Fun, Node}, Index}
                               <- zip(zip(InitialFuns, nodes()),
                                      lists:seq(0, NodeCount))],
                       % Start the pool for the rest
                       worker_queue(LaterFuns,
                                    length(InitialFuns),
                                    CollectorPid)
               end),
    % Await result
    receive {result, Res} -> Res end.

worker_queue([F], Index, CollectorPid) ->
    receive
        {Node, done} ->
            spawn_link(Node,
                       worker_pool,
                       worker_wrapper,
                       [F, Index, CollectorPid, self()])
    end;
worker_queue([F | Funs], Index, CollectorPid) ->
    receive
        {Node, done} ->
            spawn_link(Node,
                       worker_pool,
                       worker_wrapper,
                       [F, Index, CollectorPid, self()])
    end,
    worker_queue(Funs, Index + 1, CollectorPid).

worker_wrapper(Fun, Index, CollectorPid, PoolPid) ->
    % Do work
    Res = Fun(),
    % Send result
    CollectorPid ! {Index, Res},
    % Request more work
    PoolPid ! {node(), done}.

zip([F], [S | _]) -> [{F, S}];
zip([F | Fs], [S | Ss]) -> [{F, S}] ++ zip(Fs, Ss).
