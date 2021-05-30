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
                       [spawn_link(worker_wrapper(Fun,
                                                  Index,
                                                  CollectorPid,
                                                  self()))
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
    WorkerFun = worker_wrapper(F,
                               Index,
                               CollectorPid,
                               self()),
    receive {Node, done} -> spawn_link(Node, WorkerFun) end;
worker_queue([F | Funs], Index, CollectorPid) ->
    io:format("Spawning index: ~p\n", [Index]),
    io:format("CollectorPid: ~p\n", [CollectorPid]),
    io:format("Self(): ~p\n", [self()]),
    WorkerFun = worker_wrapper(F,
                               Index,
                               CollectorPid,
                               self()),
    receive {Node, done} -> spawn_link(Node, WorkerFun) end,
    worker_queue(Funs, Index + 1, CollectorPid).

worker_wrapper(Fun, Index, CollectorPid, PoolPid) ->
    fun () ->
            io:format("Starting work on index: ~p\n", [Index]),
            % Do work
            Res = Fun(),
            % Send result
            % Question: Can other nodes find the PID?
            io:format("Sending result to: ~p\n", [CollectorPid]),
            CollectorPid ! {Index, Res},
            % Request more work
            io:format("Sending done signal to: ~p\n", [PoolPid]),
            PoolPid ! {node(), done}
    end.

zip([F], [S | _]) -> [{F, S}];
zip([F | Fs], [S | Ss]) -> [{F, S}] ++ zip(Fs, Ss).
