-module(worker_pool).

-compile([export_all, nowarn_export_all]).

create_collector(N, Callback) ->
    spawn_link(fun () ->
                       Callback !
                           [receive {Index, Res} -> Res end
                            || Index <- lists:seq(0, N)]
               end).

worker_pool(Funs) ->
    Nodes = nodes(),
    CollectorPid = create_collector(length(Funs), self()),
    {InitialFuns, LaterFuns} = lists:split(length(nodes()),
                                           Funs),
    % Spawn initial workers
    [spawn_link(Node,
                worker_wrapper(Fun, Index, CollectorPid, self()))
     || {Fun, Node, Index}
            <- lists:zip(InitialFuns,
                         nodes(),
                         lists:seq(0, length(Nodes())))],
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

% How do we solve the callback?
% It's unary functions. How do we distribute them across nodes?

% (Funs) -> [Fun() || Fun <- Funs]
% Pseudocode
% For each connected node, send work and uuid for that work package
% Gather all answers
% We can provide a callback to each worker with what to call when they're done?
% We can use message passing to avoid blocking?
% We have one process gathering the data. We have one process handling the work. One accumulator, one distributor.

% Worker
% Register_worker
% Await a work package
% Call do_work with the package

% Do_work
% Conduct the work
% Send the result to master
% Ask for new work
% Call do_work with the work package

