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
                            [receive
                                 {Index, Res} ->
                                     io:format("Index ~p: ~p\n", [Index, Res]),
                                     Res
                             end
                             || Index <- lists:seq(0, N - 1)]}
               end).

worker_pool(Funs) ->
    CollectorPid = create_collector(length(Funs), self()),
    NodeCount = length(nodes()),
    {InitialFuns, LaterFuns} = lists:split(NodeCount, Funs),
    % Spawn initial workers
    io:format("Self() of worker_pool: ~p\n", [self()]),
    io:format("Fun length: ~p\n", [length(Funs)]),
    io:format("Initial length: ~p\n",
              [length(InitialFuns)]),
    io:format("Later length: ~p\n", [length(LaterFuns)]),
    % Start server with remainder
    spawn_link(fun () ->
                       [spawn_link(Node,
                                   worker_pool,
                                   worker_wrapper,
                                   [Fun, Index, CollectorPid, self()])
                        || {{Fun, Node}, Index}
                               <- zip(zip(InitialFuns, nodes()),
                                      lists:seq(0, NodeCount))],
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
    io:format("Spawning index: ~p\n", [Index]),
    io:format("CollectorPid: ~p\n", [CollectorPid]),
    io:format("Self(): ~p\n", [self()]),
    worker_queue(Funs, Index + 1, CollectorPid).

worker_wrapper(Fun, Index, CollectorPid, PoolPid) ->
    io:format("Starting work on index ~p on node ~p \n",
              [Index, node()]),
    % Do work
    Res = Fun(),
    % Send result
    CollectorPid ! {Index, Res},
    % Request more work
    PoolPid ! {node(), done}.

zip([F], [S | _]) -> [{F, S}];
zip([F | Fs], [S | Ss]) -> [{F, S}] ++ zip(Fs, Ss).
