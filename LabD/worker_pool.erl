worker_pool(Funs) ->
    Nodes = nodes(),
    CollectorPid = create_collector(length(Funs)),
    Pids = [spawn_link(Node, Fun)
        || {Fun, Node} <- zip(Funs, get_nodes())],
    
    Key = rpc:async_call(Node, map_reduce_dist, mapper_dist, [Map,R,Split]),
    case catch rpc:yield(Key) of
        {badrpc, Reason} -> [];
        Result -> Result    
    end.
    Mappeds = 
        [map_async(Node,Map,R,Split)
        || {Split, Node} <- rotate_zip(Splits, get_nodes())],

create_collector(N) -> 
    spawn_link(fun () -> 
        [receive {Index, Res} -> Res end
        || Index <- lists:seq(0, 100)],
    ).

worker_queue([F], Index, CollectorPid) ->
    WorkerFun = worker_wrapper(F, Index, CollectorPid, self()),
    receive
        {Node, free} -> spawn_link(Node, WorkerFun)
    end;

worker_queue([F|Funs], Index, CollectorPid) ->
    WorkerFun = worker_wrapper(F, Index, CollectorPid, self()),
    receive
        {Node, free} -> spawn_link(Node, WorkerFun)
    end,
    worker_queue(Funs, Index+1, CollectorPid).

worker_wrapper(Fun, Index, CollectorPid, PoolPid) ->
   fun() ->
        % Do work
        Res = Fun(),
        % Send result
        % Question: Can other nodes find the PID?
        CollectorPid ! {Index, Res},
        % Request more work
        PoolPid ! {node(), free}
    end.

rotate([F], [S|_]) ->
    [{F, S}];
rotate([F|Fs], [S|Ss]) ->
    [{F, S}] ++ rotate(Fs, Ss).


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