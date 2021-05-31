-module(map_reduce_failsafe).

-compile([export_all, nowarn_export_all]).

get_nodes(N) ->
    lists:map(fun (Num) ->
                      list_to_atom(atom_to_list(n) ++
                                       integer_to_list(Num) ++
                                           atom_to_list('@cli-a-177.wlcli.tugraz.at'))
              end,
              lists:seq(0, N)).

get_nodes() -> get_nodes(node_count()).

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

map_reduce_failsafe(Map, M, Reduce, R, Input) ->
    ping_nodes(),
    Splits = split_into(M, Input),
    Files = [rpc:async_call(Node,
                            dets,
                            open_file,
                            [web, [{file, "web.dat"}]])
             || Node <- nodes()],
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
                       % Start node monitor
                       monitor_nodes(),
                       % Spawn initial workers
                       [spawn_link(Node,
                                   map_reduce_failsafe,
                                   worker_wrapper,
                                   [Fun, Index, self()])
                        || {{Fun, Node}, Index}
                               <- zip(zip(InitialFuns, nodes()),
                                      lists:seq(0, NodeCount))],
                       Work = [{Node, Index, Fun}
                               || {{Fun, Node}, Index}
                                      <- zip(zip(InitialFuns, nodes()),
                                             lists:seq(0, NodeCount))],
                       % Start the pool for the rest
                       worker_queue(LaterFuns,
                                    length(InitialFuns),
                                    CollectorPid,
                                    Work,
                                    length(InitialFuns))
               end),
    % Await result
    receive {result, Res} -> Res end.

worker_queue([], _, _, [], _) -> [];
worker_queue([], Index, CollectorPid, CurrentWork,
             IndexOverride) ->
    receive
        {done, Node, I, Res} ->
            io:format("Sending result ~p to collector\n", [I]),
            CollectorPid ! {I, Res},
            FilteredWork = lists:filter(fun ({K, _V, _F}) ->
                                                K =/= Node
                                        end,
                                        CurrentWork),
            io:format("Starting queue at ~p\n", [Index]),
            worker_queue([],
                         Index,
                         CollectorPid,
                         FilteredWork,
                         Index);
        {nodedown, FailedNode} ->
            NextWork = lists:filter(fun ({K, _V, _F}) ->
                                            K =/= FailedNode
                                    end,
                                    CurrentWork),
            {_, I, Fold} = lists:filter(fun ({K, _V, _F}) ->
                                                K == FailedNode
                                        end,
                                        CurrentWork),
            io:format("Starting queue at ~p\n", [Index]),
            worker_queue([Fold], Index, CollectorPid, NextWork, I)
    end;
worker_queue(Fs, Index, CollectorPid, CurrentWork,
             IndexOverride) ->
    % F is the first function, Funs are the rest.
    % Note that Funs may be empty
    {First, Funs} = lists:split(1, Fs),
    F = lists:nth(1, First),
    receive
        {done, Node, I, Res} ->
            io:format("Sending result ~p to collector\n", [I]),
            CollectorPid ! {I, Res},
            FilteredWork = lists:filter(fun ({K, _V, _F}) ->
                                                K =/= Node
                                        end,
                                        CurrentWork),
            if IndexOverride =/= Index ->
                   % There was a problem. Need to reattempt a failed execution
                   io:format("index ~p, override index ~p\n",
                             [Index, IndexOverride]),
                   spawn_link(Node,
                              map_reduce_failsafe,
                              worker_wrapper,
                              [F, IndexOverride, self()]),
                   NextWork = FilteredWork ++ [{Node, IndexOverride, F}],
                   io:format("Starting queue at ~p\n", [Index + 1]),
                   worker_queue([F | Funs],
                                Index,
                                CollectorPid,
                                NextWork,
                                Index);
               true ->
                   spawn_link(Node,
                              map_reduce_failsafe,
                              worker_wrapper,
                              [F, Index, self()]),
                   NextWork = FilteredWork ++ [{Node, Index, F}],
                   io:format("Starting queue at ~p\n", [Index + 1]),
                   worker_queue(Funs,
                                Index + 1,
                                CollectorPid,
                                NextWork,
                                Index + 1)
            end;
        {nodedown, FailedNode} ->
            NextWork = lists:filter(fun ({K, _V, _F}) ->
                                            K =/= FailedNode
                                    end,
                                    CurrentWork),
            {_, I, Fold} = lists:filter(fun ({K, _V, _F}) ->
                                                K == FailedNode
                                        end,
                                        CurrentWork),
            io:format("Starting queue at ~p\n", [Index]),
            worker_queue([Fold] ++ [F] ++ Funs,
                         Index,
                         CollectorPid,
                         NextWork,
                         I)
    end.

worker_wrapper(Fun, Index, PoolPid) ->
    io:format("~p: Starting work on index ~p\n",
              [node(), Index]),
    % Do work
    Res = Fun(),
    % Send result
    PoolPid ! {done, node(), Index, Res}.

zip([F], [S | _]) -> [{F, S}];
zip([F | Fs], [S | Ss]) -> [{F, S}] ++ zip(Fs, Ss).

node_count() -> 3.

monitor_nodes() ->
    Parent = self(),
    Ref = make_ref(),
    spawn_link(fun () ->
                       monitor_nodes(Parent, get_nodes(), Ref)
               end),
    receive
        {Ref, init_done} ->
            io:format("Initialised all nodes.\n", [])
    end.

monitor_nodes(Parent, Ns, Ref) ->
    PingPangPong = lists:map(fun (Node) ->
                                     case net_adm:ping(Node) of
                                         pong ->
                                             io:format("Init and monitor node ~p\n",
                                                       [Node]),
                                             monitor_node(Node, true),
                                             rpc:call(Node,
                                                      dets,
                                                      open_file,
                                                      ["web.dat"]),
                                             {pong, Node};
                                         pang -> {pang, Node}
                                     end
                             end,
                             Ns),
    Pangs = lists:filter(fun ({P, _}) -> P == pang end,
                         PingPangPong),
    if length(Pangs) > 0 ->
           monitor_nodes(Parent,
                         lists:map(fun ({_, Node}) -> Node end, Pangs),
                         Ref);
       true ->
           Parent ! {Ref, init_done},
           receive
               {nodedown, Node} ->
                   io:format("Reconnecting to ~p\n", [Node]),
                   Parent ! {nodedown, Node},
                   monitor_nodes(Parent, [Node], Ref);
               notalive -> exit(no_local_node)
           end
    end.
