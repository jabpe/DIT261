-module(tmp).
%-include_lib("eqc/include/eqc.hrl").
-compile(export_all).

spawn_map(Pid, F, XS) ->
    lists:map(fun(X) ->
            ChildPid = spawn_link(fun () -> 
                % io:format("starting: ~p\n", [self()]),
                % receive Msg -> Msg end,
                case catch F(X) of
                    {'EXIT', no_solution} -> Pid ! no_solution;
                    Solution -> Pid ! Solution
                end
                % io:format("done: ~p\n", [self()])
            end),
            ChildPid
        end, 
        XS).

%% c(tmp). c(sudoku). sudoku:benchmarks().

receive_map(F, XS, Pid) ->
    Parent = self(),
    Refs = spawn_map(Parent, F, XS),
    lists:map(fun (_) ->
            receive
                no_solution ->
                    no_solution;
                Solution ->
                    Pid ! Solution,
                    Solution
                end
            end,
        Refs).
    % lists:any(fun(X) -> X end, ps).

on_exit(Pid,Fun) ->
    spawn(fun() ->
        process_flag(trap_exit,true),
        link(Pid),
        receive {'EXIT',Pid,Why} ->
            io:format("is this printed?\n"),
            Fun(Why)
        end,
        io:format("This will never be printed\n")
    end).

% test_errror() ->
%     Parent = self(),
%     Pid = spawn_link(fun () -> receive Something -> Something end, Parent ! solution end),
%     on_exit(Pid, fun(Why) -> io:format("Caught exit: ~p\n", [Why]) end),
%     Pid ! 1,
%     io:format("anything\n"),
%     receive Msg -> 
%         io:format("anything\n"),
%         case catch Msg of
%             {'EXIT', invalid_solution} ->
%                 io:format("caught it"),
%                 [];
%             Solution ->
%                 [1]
%         end
%     end,
%     io:format("END\n").

% refs = spawn_map()
% len = refs.len
% map((r) =>
%     receive msg ->
%         if(isSolution(msg))
%             return msg
%         len--;
%         if len == 0
%             error "no solution";
%         , refs)x