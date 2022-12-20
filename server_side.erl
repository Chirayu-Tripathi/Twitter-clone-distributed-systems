-module(server_side).
-export([new/0,loop/1,find_user/1,user_register/2,disconnectUser/1,fetch_tweets/1,my_Tweets/1,fetch_follow/1,add_follower/2,fetch_subscribers/1,add_following/2,tweet/2,send_to_subscribers/2,
    get_hash_mentions/3,get_hash_mentions/4,insert_tags/2,usersSubscribedTo/1,create_tweet_data/2,hashtagTweets/2,mentionTweets/1,start_server/0]).

new() ->
  spawn(fun() -> loop(0) end).

loop(N) ->
  receive
    {registerTheUser,UserId,Pid} ->
       user_register(UserId,Pid),
       Pid ! {registered},
      loop(N + 1);

    {tweet,Tweet,UserId} ->
        tweet(Tweet,UserId),
        loop(N+1);

    {usersSubscribedTo,UserId} ->
        usersSubscribedTo(UserId),
        loop(N+1);

    {hashtagTweets,HashTag,UserId} ->
        hashtagTweets(HashTag,UserId),
        loop(N+1);

    {mentionTweets,UserId} ->
        mentionTweets(UserId),
        loop(N+1);
        
    {myTweets,UserId} -> 
        my_Tweets(UserId),
        loop(N+1);

    {addFollower,UserId,FollowId} -> 
        add_follower(UserId,FollowId),
        add_following(FollowId,UserId),
        loop(N+1);

    {disconnectUser,UserId} -> 
        disconnectUser(UserId),
        loop(N+1);
    {userLogin,UserId,Pid} -> 
        ets:insert(registry,{UserId,Pid}),
        loop(N+1);
    {rephashtagTweets,Data} ->
        erlang:display(Data),
        loop(N+1)
    end.

find_user(UserId) ->
    Check = ets:lookup(registry,UserId),
    if 
       Check == [] ->
            [];
       true ->
            [Tuple] = ets:lookup(registry, UserId),
            element(2,Tuple)
    end.
    % [Tuple] = ets:lookup(registry,UserId),
    % element(2,Tuple).

user_register(UserId,Pid)->
    
        ets:insert(registry, {UserId,Pid}),
        ets:insert(tweets, {UserId, []}),
        ets:insert(followingto, {UserId, []}),
        Check = ets:lookup(subscribers, UserId),
        if  
            Check == [] ->
                 ets:insert(subscribers, {UserId, []});
            true -> pass
        end.

disconnectUser(UserId) ->
    
      ets:insert(registry, {UserId, undefined}).

fetch_tweets(UserId) ->
    Check = ets:lookup(tweets,UserId),
    if 
       Check == [] ->
            [];
        true ->
            [Tuple] = ets:lookup(tweets, UserId),
            element(2,Tuple)
    end.

my_Tweets(UserId) ->
    [Tuple] = ets:lookup(tweets,UserId),
    Data = element(2,Tuple),
    Receiver = find_user(UserId),
    % Data.
    Receiver ! {repmyTweets,Data}. % to be implemented

fetch_follow(UserId) ->
    [Tuple] = ets:lookup(followingto, UserId),
    element(2,Tuple).

add_follower(UserId,FollowId) ->
        [Tuple] = ets:lookup(followingto, UserId),
        Following = element(2,Tuple),
        Data = [FollowId | Following],
        ets:insert(followingto, {UserId, Data}).

fetch_subscribers(UserId) ->
    [Tuple] = ets:lookup(subscribers, UserId),
    element(2,Tuple).

add_following(FollowId,UserId) ->
    Check = ets:lookup(subscribers, FollowId),
    if 
         Check == [] ->
            ets:insert(subscribers, {FollowId, []});
        true -> pass
    end,
    [Tuple] = ets:lookup(subscribers,FollowId),
    Followers = element(2,Tuple),
    Data = [UserId | Followers],
    ets:insert(subscribers, {FollowId, Data}).

tweet(Tweet,UserId)->
    [Tuple] = ets:lookup(tweets, UserId),
    List = element(2,Tuple),
    List_updated = [Tweet | List],
    io:format("~s", ["\n"]),
    io:format([Tweet]),
    io:format("~s", ["\n"]),
    ets:insert(tweets,{UserId,List_updated}),
    Check= re:run(Tweet,"#[a-zA-Z0-9_]+",[global]),
    if 
        Check /= nomatch ->
                {match , All_hashtags} = Check,
                get_hash_mentions(All_hashtags,length(All_hashtags),Tweet);
        true -> ok
    end,
    
    Check_@ = re:run(Tweet,"@[a-zA-Z0-9_]+",[global]),
    if 
        Check_@ /= nomatch ->
                {match , All_mentions} = Check_@,
                get_hash_mentions(All_mentions,length(All_mentions),Tweet,mentions),
                [{_,Subscribers}] = ets:lookup(subscribers, UserId),
                % [Tuple] = ets:lookup(subscribers, UserId),
                % Subscribers = element(2,Tuple),
                send_to_subscribers(Subscribers,Tweet);
        true -> ok
    end.


send_to_subscribers([],Tweet) -> pass;

send_to_subscribers([Subscriber | A],Tweet) ->
    Check = find_user(Subscriber),
    if 
        Check /= [] ->
                find_user(Subscriber) ! {live,Tweet};
        true ->
            pass
    end,
    send_to_subscribers(A,Tweet).



get_hash_mentions([],0,Str)-> pass;

get_hash_mentions([A | B],L,Str)->
    [C | D] = A,
    {Start,Length} = C,
    Sublist = lists:sublist(Str, Start+1, Length),
    % erlang:display(Sublist),
    insert_tags(Sublist,Str),
    get_hash_mentions(B,L-1,Str).

get_hash_mentions([],0,Str,mentions)-> pass;

get_hash_mentions([A | B],L,Str,mentions)->
    [C | D] = A,
    {Start,Length} = C,
    Sublist = lists:sublist(Str, Start+1, Length),
    % erlang:display(Sublist),
    Name = lists:sublist(Str, Start+2, Length-1),
    Check = find_user(Name),
    if 
        Check /= [] ->
                find_user(Name) ! {live,Str};
        true -> user_not_found
    end,
    insert_tags(Sublist,Str),
    get_hash_mentions(B,L-1,Str).

insert_tags(Tag,Tweet) ->
    Check = ets:lookup(hashtags_mentions, Tag),
    if 
        Check /= [] ->
                [Tuple] = ets:lookup(hashtags_mentions, Tag),
                All_tweet_data = element(2,Tuple),
                Data = [Tweet | All_tweet_data],
                ets:insert(hashtags_mentions,{Tag,Data});
                
        true ->
            ets:insert(hashtags_mentions,{Tag,[Tweet]})
    end.

usersSubscribedTo(UserId) ->
        Following = fetch_follow(UserId),
        Data = create_tweet_data(Following,[]),
        find_user(UserId) ! {repusersSubscribedTo,Data}.
        
create_tweet_data([],Tweetstr) -> Tweetstr;

create_tweet_data([A | B],Tweetstr) ->
    New = fetch_tweets(A) ++ Tweetstr,
    create_tweet_data(B,New).


hashtagTweets(HashTag,UserId) ->
    Check = ets:lookup(hashtags_mentions, HashTag),
    if 
        Check /= [] ->
                [Tuple] = Check;

        true ->
                [Tuple] = [{"#",[]}]
    end,
    Data = element(2,Tuple),
    Receiver = find_user(UserId),
    % Receiver.
    Receiver ! {rephashtagTweets,Data}.

mentionTweets(UserId) ->
    Q = "@"++integer_to_list(UserId),
    % erlang:display(Q),
    Check = ets:lookup(hashtags_mentions, Q),
    if 
         Check /= [] ->
                [Tuple] = Check;

        true ->
                [Tuple] = [{"#",[]}]
    end,
    Data = element(2,Tuple),
    find_user(UserId) ! {repmentionTweets,Data}.

start_server() ->
    %ets:new(ingredients, [set,public, named_table]),
    ets:new(registry, [set, public, named_table]),
    ets:new(tweets, [set, public, named_table]),
    ets:new(hashtags_mentions, [set, public, named_table]),
    ets:new(followingto, [set, public, named_table]),
    ets:new(subscribers, [set, public, named_table]),
    Pid = new(),
    global:register_name(server, Pid).

