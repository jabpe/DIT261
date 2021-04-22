-module(par).
-compile(export_all).

speculate(F) ->
    process_flag(trap_exit,true),
    Parent = self(),
    Pid = spawn_link(fun() -> Parent ! {self(),F()} end),
    {speculating, Pid}.

await({speculating, Pid}) ->
    receive
        {Pid, Res} ->
            Res;
        {'EXIT',Pid, Reason} ->
            exit(Reason)
    end.

cancel({speculating, Pid}) ->
    unlink(Pid),
    exit(Pid, kill).