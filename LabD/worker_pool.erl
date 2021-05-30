-module(worker_pool).

-compile([export_all, nowarn_export_all]).

get_nodes() ->
    ['n0@MacBook-Pro.local',
     'n1@MacBook-Pro.local',
     'n2@MacBook-Pro.local'].

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
