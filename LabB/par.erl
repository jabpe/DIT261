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
        {'EXIT', Pid, _Reason} ->
            case lists:member(Pid, Workers) of
                true ->
                    pool(lists:delete(Pid, Workers));
                false ->
                    ok
            end;
        % Client is the process requesting something to be put in the pool
        {spawn, Client, Ref} ->
            % Reserving one thread for the main thread to not block the depth first search
            Limit = erlang:system_info(schedulers) - 1,
            if
                length(Workers) < Limit ->
                    W = spawn_link(fun () -> worker(Client, Ref) end),
                    Client ! {ok, W, Ref},
                    pool([W|Workers]);
                true ->
                % Return "full"
                    Client ! {full, Ref},
                    pool(Workers)
                end
            end.

% Send a PID to a worker
worker(Client, Ref) ->
    receive
        {work, F, Ref} -> Client ! {value, F(), Ref}
    end.

speculate(F) ->
    Ref = make_ref(),
    workerpool ! {spawn, self(), Ref},
    receive 
        {ok, W, Ref} ->
            % Don't crash on spawned process crash. Delay it until await.
            process_flag(trap_exit,true),
            link(W),
            W ! {work, F, Ref},
            {working, W, Ref};
        {full, Ref} -> 
            {full, F}
    end.

await({full, F}) ->
    F();
await({working, W, Ref}) ->
    receive
        {value, Res, Ref} ->
            Res;
        {'EXIT',W, Reason} ->
            exit(Reason)
    end.

cancel({full, _F}) ->
    ok;

cancel({working, Pid, _Ref}) ->
    unlink(Pid),
    exit(Pid, kill).