-module(client_side).
-export([start/1,login_operator/1,send_tweet/2, client_operator/3, generate_partlist/3, zipf_subscribe_handler/2, retweet_handler/1, get_my_tweets_handler/1, queries_subscribedto_handler/1,
    queries_hashtag_handler/2,queries_mention_handler/1,get_random_string/1,liveFeed_handler/1,format_data/1]).

start([UserId,TweetCount,SubscribeNo,UserAlreadyPresent]) ->
        % erlang:display([UserId,TweetCount,SubscribeNo,UserAlreadyPresent]),
        if 
        UserAlreadyPresent ->
            % io:format("User got reconnected : ~p.", UserId),
            io:fwrite("User got reconnected : ~w.",[UserId]),
            io:format("~s", ["\n"]),
            login_operator(UserId);

        true ->
                pass
        end,
        % erlang:display(global:whereis_name(server)),
        global:whereis_name(server) ! {registerTheUser,UserId,self()},
        receive 
            {registered} -> 
                io:format("User got registered : ~w.", [UserId]),
                io:format("~s", ["\n"])
        end,
        client_operator(UserId,TweetCount,SubscribeNo).

login_operator(UserId) ->
        global:whereis_name(server) ! {userLogin,UserId,self()},
        send_tweet(5,UserId),
        liveFeed_handler(UserId).


send_tweet(1,UserId) ->
    % Q = "@"++integer_to_list(UserId),
    Q = integer_to_list(UserId),
    global:whereis_name(server) ! {tweet,"user "++Q++" tweeting a string that is "++get_random_string(8)++" which is randomly generated",UserId};
send_tweet(N,UserId) ->
    To_send = get_random_string(8),
    % Q = "@"++integer_to_list(UserId),
    Q = integer_to_list(UserId),
    global:whereis_name(server) ! {tweet,"user "++Q++" tweeting a string that is "++To_send++" which is randomly generated",UserId},
    send_tweet(N-1,UserId).

client_operator(UserId,TweetCount,SubscribeNo) ->
        if 
        SubscribeNo > 0 ->
            SubList = generate_partlist(1,SubscribeNo,[]),
            % erlang:display(SubList),
            zipf_subscribe_handler(UserId,SubList);

        true ->
                pass
        end,
        Start_time_tweet = erlang:system_time(millisecond),
        UserToMention = integer_to_list(UserId),
        global:whereis_name(server) ! {tweet,"user "++UserToMention++" is tweeting about the @"++UserToMention,UserId},
        global:whereis_name(server) ! {tweet,"user "++UserToMention++" is tweeting that #DOSP and #TA's are great",UserId},

        send_tweet(TweetCount,UserId),
        retweet_handler(UserId),
        Time_difference_tweets = erlang:system_time(millisecond) - Start_time_tweet,

        Start_time_query = erlang:system_time(millisecond),
        queries_subscribedto_handler(UserId),
        Time_diff_Queries_subscribedto = erlang:system_time(millisecond) - Start_time_query,

        Start_time_hash_search = erlang:system_time(millisecond),
        queries_hashtag_handler("#DOSP",UserId),
        Time_diff_Queries_hashtag = erlang:system_time(millisecond) - Start_time_hash_search,

        Start_time_mention = erlang:system_time(millisecond),
        queries_mention_handler(UserId),
        Time_diff_Queries_mention = erlang:system_time(millisecond) - Start_time_mention,

        Start_time_my_tweets = erlang:system_time(millisecond),
        get_my_tweets_handler(UserId),
        Time_diff_Queries_myTweets = erlang:system_time(millisecond) - Start_time_my_tweets,

        Tweets_time_diff_modi = Time_difference_tweets/(TweetCount+3),
        global:whereis_name(coordinator) ! {performanceMetrics,Time_difference_tweets,Time_diff_Queries_subscribedto,Time_diff_Queries_hashtag,Time_diff_Queries_mention,Time_diff_Queries_myTweets},
        % send(:global.whereis_name(:coordinator),)

        liveFeed_handler(UserId).

generate_partlist(Count,Subs,Li) ->
    if
        Count == Subs ->  
            [Count | Li];
        true -> 
            generate_partlist(Count+1,Subs,[Count | Li]) 
    end.

zipf_subscribe_handler(UserId,[]) -> pass;
    

zipf_subscribe_handler(UserId,[A | B]) ->
    global:whereis_name(server) ! {addFollower,UserId,A},
    zipf_subscribe_handler(UserId,B).

retweet_handler(UserId) ->
    global:whereis_name(server) ! {usersSubscribedTo,UserId},
    receive 
        {repusersSubscribedTo,Data} ->
            Pass = Data
    end,
    if Pass /= [] ->
        [Retweet | B] = Pass,
        global:whereis_name(server) ! {tweet,Retweet++" -RT",UserId};
    true ->
        nothing_to_retweet
    end.

liveFeed_handler(UserId) ->
    receive 
        {live,St} ->
            io:format("Live Feed of User : ~w.", [UserId]),
            io:format("~s", ["\n"]),
            io:format([St]),
            io:format("~s", ["\n"])
    end,
    liveFeed_handler(UserId).

get_my_tweets_handler(UserId) ->
    global:whereis_name(server) ! {myTweets,UserId},
    receive 
        {repmyTweets,Data} ->
            io:format("All Tweets of User : ~w.", [UserId]),
            io:format("~s", ["\n"]),
            format_data(Data),
            io:format("~s", ["\n"])
    end.

queries_subscribedto_handler(UserId) ->
    global:whereis_name(server) ! {usersSubscribedTo,UserId},
    receive
        {repusersSubscribedTo,Data} ->
            io:format("All Tweets subscribed by User : ~w.", [UserId]),
            io:format("~s", ["\n"]),
            format_data(Data),
            io:format("~s", ["\n"])
    end.

format_data([]) -> end_reached;
format_data([A | B]) ->
    io:format("~s", ["\n"]),
    io:format(A),
    % io:format("~s", ["\n"]),
    format_data(B).

queries_hashtag_handler(Tag,UserId) ->
    global:whereis_name(server) ! {hashtagTweets,Tag,UserId},
    receive
        {rephashtagTweets,Data} ->
            io:format("All "++Tag++" Tweets requested by User : ~w.", [UserId]),
            io:format("~s", ["\n"]),
            % io:format(Data),
            format_data(Data),
            io:format("~s", ["\n"])
    end.

queries_mention_handler(UserId) ->
    Q = "@"++integer_to_list(UserId),
    global:whereis_name(server) ! {mentionTweets,UserId},
    receive
        {repmentionTweets,Data} ->
            io:format("All Tweets mentioning "++Q++" requested by User : ~w.", [UserId]),
            io:format("~s", ["\n"]),
            format_data(Data),
            io:format("~s", ["\n"])
    end.


get_random_string(Total_length) ->
    Chars_allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
    lists:foldl(fun(_, Accumulator) ->
                       [lists:nth(rand:uniform(length(Chars_allowed)),
                                   Chars_allowed)]
                            ++ Accumulator
                end, [], lists:seq(1, Total_length)).






