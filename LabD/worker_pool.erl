-module(worker_pool).

-compile([export_all, nowarn_export_all]).

get_nodes() ->
    ['n0@MacBook-Pro.local',
     'n1@MacBook-Pro.local',
     'n2@MacBook-Pro.local'].

factorial(0) -> 1;
factorial(N) -> N * factorial(N - 1).

test() ->
    net_adm:ping('n0@MacBook-Pro.local'),
    Funs = [fun () -> factorial(N) end
            || N <- lists:seq(0, 10)],
    Res = worker_pool(Funs),
    io:format(Res).

create_collector(N, Callback) ->
    spawn_link(fun () ->
                       Callback !
                           [receive {Index, Res} -> Res end
                            || Index <- lists:seq(0, N - 1)]
               end).

worker_pool(Funs) ->
    CollectorPid = create_collector(length(Funs), self()),
    NodeCount = length(get_nodes()),
    {InitialFuns, LaterFuns} = lists:split(NodeCount, Funs),
    % Spawn initial workers
    io:format("FUN"),
    io:format(integer_to_list(length(Funs))),
    io:format("FIRST"),
    io:format(integer_to_list(length(InitialFuns))),
    io:format("LAST"),
    io:format(integer_to_list(length(LaterFuns))),
    [spawn_link(Node,
                worker_wrapper(Fun, Index, CollectorPid, self()))
     || {{Fun, Node}, Index}
            <- zip(zip(InitialFuns, get_nodes()),
                   lists:seq(0, NodeCount))],
    % Start server with remainder
    worker_queue(LaterFuns,
                 length(InitialFuns),
                 CollectorPid),
    % Await result
    receive Res -> Res end.

worker_queue([F], Index, CollectorPid) ->
    WorkerFun = worker_wrapper(F,
                               Index,
                               CollectorPid,
                               self()),
    receive {Node, free} -> spawn_link(Node, WorkerFun) end;
worker_queue([F | Funs], Index, CollectorPid) ->
    WorkerFun = worker_wrapper(F,
                               Index,
                               CollectorPid,
                               self()),
    receive {Node, free} -> spawn_link(Node, WorkerFun) end,
    worker_queue(Funs, Index + 1, CollectorPid).

worker_wrapper(Fun, Index, CollectorPid, PoolPid) ->
    fun () ->
            % Do work
            Res = Fun(),
            % Send result
            % Question: Can other nodes find the PID?
            CollectorPid ! {Index, Res},
            % Request more work
            PoolPid ! {node(), free}
    end.

zip([F], [S | _]) -> [{F, S}];
zip([F | Fs], [S | Ss]) -> [{F, S}] ++ zip(Fs, Ss).
