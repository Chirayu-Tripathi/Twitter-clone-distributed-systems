# Twitter-clone-distributed-systems
Repository containing Erlang implementation of the final project for the distributed operating system principles course at the University of Florida.
This project's objective was to develop an Erlang Twitter clone along with a client that could test the server with millions of request at a particular time-stamp.

-------------------------------------------------------
 COP5615 : DISTRIBUTED SYSTEMS - TWITTER CLONE 
-------------------------------------------------------
The objective of this project was to implement following concepts -
 - A Twitter like api with the following functionality:
	* Register account
	* Send tweet. Tweets can have hashtags (e.g. #COP5615isgreat) and mentions (@bestuser)
	* Subscribe to user's tweets
	* Re-tweets (so that your subscribers get an interesting tweet you got by other means)
	* Allow querying tweets subscribed to, tweets with specific hashtags, tweets in which the user is mentioned (my mentions)
	* If the user is connected, deliver the above types of tweets live (without querying)
 - Implement a tester/simulator to test the above
	* Simulate as many users as possible
	* Simulate periods of live connection and disconnection for users
	* Simulate a Zipf distribution on the number of subscribers. For accounts with a lot of subscribers, increase the number of tweets. Make some of these messages re-tweets
 - Measure various aspects of the simulator and report performance
  * The client part (send/receive tweets) and the engine (distribute tweets) have to be in separate processes. Preferably, you use multiple independent client processes that simulate thousands of clients and a single-engine process.
  
