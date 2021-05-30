%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% This implements a page rank algorithm using map-reduce
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-module(page_rank).

-compile([export_all, nowarn_export_all]).

%% Use map_reduce to count word occurrences

map(Url, ok) ->
    [{Url, Body}] = dets:lookup(web, Url),
    Urls = crawl:find_urls(Url, Body),
    [{U, 1} || U <- Urls].

reduce(Url, Ns) -> [{Url, lists:sum(Ns)}].

page_rank() ->
    {ok, web} = dets:open_file(web, [{file, "web.dat"}]),
    Urls = dets:foldl(fun ({K, _}, Keys) -> [K | Keys] end,
                      [],
                      web),
    map_reduce:map_reduce_seq(fun map/2,
                              fun reduce/2,
                              [{Url, ok} || Url <- Urls]).

page_rank_par() ->
    dets:open_file(web, [{file, "web.dat"}]),
    Urls = dets:foldl(fun ({K, _}, Keys) -> [K | Keys] end,
                      [],
                      web),
    map_reduce:map_reduce_par(fun map/2,
                              32,
                              fun reduce/2,
                              32,
                              [{Url, ok} || Url <- Urls]).

page_rank_dist() ->
    dets:open_file(web, [{file, "web.dat"}]),
    Urls = dets:foldl(fun ({K, _}, Keys) -> [K | Keys] end,
                      [],
                      web),
    map_reduce_dist:map_reduce_dist(fun map/2,
                                    32,
                                    fun reduce/2,
                                    32,
                                    [{Url, ok} || Url <- Urls]).

page_rank_pool() ->
    dets:open_file(web, [{file, "web.dat"}]),
    Urls = dets:foldl(fun ({K, _}, Keys) -> [K | Keys] end,
                      [],
                      web),
    map_reduce_worker_pool:map_reduce_worker_pool(fun map/2,
                                                  32,
                                                  fun reduce/2,
                                                  32,
                                                  [{Url, ok} || Url <- Urls]).

page_rank_failsafe() ->
    dets:open_file(web, [{file, "web.dat"}]),
    Urls = dets:foldl(fun ({K, _}, Keys) -> [K | Keys] end,
                      [],
                      web),
    map_reduce_failsafe:map_reduce_failsafe(fun map/2,
                                            32,
                                            fun reduce/2,
                                            32,
                                            [{Url, ok} || Url <- Urls]).

benchmark_par() ->
    timer:tc(?MODULE, page_rank_pool, []).

benchmark_dist() ->
    timer:tc(?MODULE, page_rank_dist, []).

benchmark_pool() ->
    timer:tc(?MODULE, page_rank_pool, []).

benchmark_failsafe() ->
    timer:tc(?MODULE, page_rank_failsafe, []).
