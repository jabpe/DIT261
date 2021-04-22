-module(par).
-compile(export_all).

% Initialise the worker pool
start() ->
    spawn_link(fun() -> 
        % Flag as system process: if a worker crashes, we don't wanna crash
        process_flag(trap_exit,true),
        % Register as 'throttle' so other can access the process
        register(workerpool,self()),
        % initialize empty worker pool
        pool([])
    end).

% Return "speculating" or "not speculating" to tell the caller if they can
% use the resource or not based on the amount of workers
pool(Workers) ->
    receive 
        {'EXIT', Pid, Reason} ->
            case lists:member(Pid, Workers) of
                true ->
                    pool(lists:delete(Pid, Workers));
                false ->
                    exit(normal)
            end;
        % Client is the process requesting something to be put in the pool
        {spawn, Client} ->
            % Reserving one thread for the main thread to not block the depth first search
            Limit = erlang:system_info(schedulers) - 1,
            if length(workers) < Limit ->
                    W = spawn_link(fun () -> worker(Client) end),
                    Client ! {ok, W},
                    pool([W|Workers]);
                true ->
                % Return "full"
                Client ! full,
                pool(Workers)
                end
            end.

% Send a PID to a worker
worker(Client) ->
    receive
        {work, F} -> Client ! F()
    end.

speculate(F) ->
    workerpool ! {spawn, self()},
    receive 
        {ok, W} ->
            link(W),
            W ! {work, F},
            {working, W};
        full -> 
            {full, F}
    end.

await({full, F}) ->
    F();
await({working, W}) ->
    receive
        {W, Res} ->
            Res;
        {'EXIT',W, Reason} ->
            exit(Reason)
    end.

cancel({full, F}) ->
    ok;

cancel({working, Pid}) ->
    unlink(Pid),
    exit(Pid, kill).