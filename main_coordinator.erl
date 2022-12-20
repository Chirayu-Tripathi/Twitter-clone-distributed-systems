-module(main_coordinator).
-export([initiate/3,check_convergence/7,spawnUsers/3,find_user/1,disconnection_simulator/2,spawn_up/1,disconnection_handler/4]).

% -import(server,[]).
-import(client_side,[]).

initiate(NumClients,MaxSubcribers,DisconnectClients) ->
    NoUsersToDisconnect = DisconnectClients * (0.01) * NumClients,
    ets:new(mainregistry, [set, public, named_table]),
    Pid = spawn(fun() ->  check_convergence(NumClients,NumClients,0,0,0,0,0) end),
    global:register_name(coordinator,Pid),
    Start_time = erlang:system_time(millisecond),
    spawnUsers(1,NumClients,MaxSubcribers),
    disconnection_simulator(NumClients,NoUsersToDisconnect).

check_convergence(0,TotalClients,Time_difference_tweets,Time_diff_Queries_subscribedto,Time_diff_Queries_hashtag,Time_diff_Queries_mention,Time_diff_Queries_myTweets) ->
        io:format("Average time taken to tweet in milliseconds ~f~n.",[Time_difference_tweets/TotalClients]),
        io:format("Average time taken to query subscribed tweets in milliseconds ~f~n.", [Time_diff_Queries_subscribedto/TotalClients]),
        io:format("Average time taken to query hashtags tweets in milliseconds ~f~n.", [Time_diff_Queries_hashtag/TotalClients]),
        io:format("Average time taken to query mention tweets in milliseconds ~f~n.", [Time_diff_Queries_mention/TotalClients]),
        io:format("Average time taken to query all relevant(self) tweets in milliseconds ~f~n.", [Time_diff_Queries_myTweets/TotalClients]);

check_convergence(NumClients,TotalClients,Time_difference_tweets,Time_diff_Queries_subscribedto,Time_diff_Queries_hashtag,Time_diff_Queries_mention,Time_diff_Queries_myTweets) ->
    receive 
        {performanceMetrics,A,B,C,D,E} -> check_convergence(NumClients-1,TotalClients,Time_difference_tweets+A,Time_diff_Queries_subscribedto+B,Time_diff_Queries_hashtag+C,Time_diff_Queries_mention+D,Time_diff_Queries_myTweets+E)
    end.

spawnUsers(Count,NoOfClients,TotalSubscribers) ->
    UserName = Count,
    NoOfTweets = round(math:floor(TotalSubscribers/Count)),
    NoToSubscribe = round(math:floor(TotalSubscribers/(NoOfClients-Count+1))) - 1,
    % Pid = client_side:start([UserName,NoOfTweets,NoToSubscribe,false]),
    Pid = spawn(fun() -> client_side:start([UserName,NoOfTweets,NoToSubscribe,false]) end),
    ets:insert(mainregistry, {UserName, Pid}),
    if 
        Count /= NoOfClients ->
                spawnUsers(Count+1,NoOfClients,TotalSubscribers);
        true -> pass
    end.

find_user(UserId) ->
    Check = ets:lookup(mainregistry,UserId),
    [Tuple] = ets:lookup(mainregistry, UserId),
    X = element(2,Tuple),
    if 
       Check == [] ->
            [];
            
       X == undefined ->
            [];
       true ->
            X
            
            
    end.

disconnection_simulator(NumClients,NoUsersToDisconnect) ->
    timer:sleep(1000),
    DisconnectList = disconnection_handler(NumClients,NoUsersToDisconnect,0,[]),
    timer:sleep(1000),
    spawn_up(DisconnectList),
    disconnection_simulator(NumClients,NoUsersToDisconnect).

spawn_up([]) ->
    pass;

spawn_up([A | B]) ->
    Pid = spawn(fun() -> client_side:start([A,-1,-1,true]) end),
    ets:insert(mainregistry, {A, Pid}),
    spawn_up(B).

disconnection_handler(NumClients,NoUsersToDisconnect,UsersDisconnected,DisconnectList) ->
        if 
            UsersDisconnected < NoUsersToDisconnect ->
                DisconnectClient = rand:uniform(NumClients),
                DisconnectClientId = find_user(DisconnectClient),
                erlang:display(DisconnectClientId),
                if DisconnectClientId /= [] ->
                    UserId = DisconnectClient,
                    DisconnectList2 = [UserId | DisconnectList],
                    global:whereis_name(server) ! {disconnectUser,UserId},
                    ets:insert(mainregistry, {UserId, undefined}),
                    exit(DisconnectClientId, "Disconnected"++DisconnectClientId),
                    io:format("User got Disconnected : ~p.", [UserId]),
                    % IO.puts "Simulator :- User #{userId} has been disconnected"
                    disconnection_handler(NumClients,NoUsersToDisconnect,UsersDisconnected+1,DisconnectList2);

                true ->
                disconnection_handler(NumClients,NoUsersToDisconnect,UsersDisconnected,DisconnectList)
            end;
        true ->
            DisconnectList
        
    end.


