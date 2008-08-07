%%%-------------------------------------------------------------------
%%% File    : store_worker_fsm.erl
%%% Author  : Matt Williamson <mwilliamson@mwvmubhhlap>
%%% Description : This module takes care of storing and retrieving 
%%% file chunks from the local filesystem.
%%%
%%% Created :  1 Aug 2008 by Matt Williamson <mwilliamson@mwvmubhhlap>
%%%-------------------------------------------------------------------
-module(erlfs.store_worker_fsm).

-include("erlfs.hrl").

-behaviour(gen_fsm).

%% API
-export([start_link/1]).

%% gen_fsm callbacks
-export([init/1, handle_event/3,
	 handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

%% STATES
%% Store chunk
-export([storing_chunk/2, notifying_tracker/2]).

%% Get Chunk
-export([getting_chunk/2]).

%% Common
-export([done/2]).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> ok,Pid} | ignore | {error,Error}
%% Description:Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this function
%% does not return until Module:init/1 has returned.  
%%--------------------------------------------------------------------
start_link(FileChunk) ->
    gen_fsm:start_link(?MODULE, FileChunk, []).

%%====================================================================
%% gen_fsm callbacks
%%====================================================================
%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, StateName, State} |
%%                         {ok, StateName, State, Timeout} |
%%                         ignore                              |
%%                         {stop, StopReason}                   
%% Description:Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/3,4, this function is called by the new process to 
%% initialize. 
%%--------------------------------------------------------------------
init(StartArg) ->
    case StartArg of
	{store_chunk, Chunk} ->
	    {ok, storing_chunk, Chunk};
	{get_chunk, Args} ->
	    {ok, getting_chunk, Args}
    end.

%%--------------------------------------------------------------------
%% Function: 
%% state_name(Event, State) -> {next_state, NextStateName, NextState}|
%%                             {next_state, NextStateName, 
%%                                NextState, Timeout} |
%%                             {stop, Reason, NewState}
%% Description:There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same name as
%% the current state name StateName is called to handle the event. It is also 
%% called if a timeout occurs. 
%%--------------------------------------------------------------------

%% States to store a chunk
storing_chunk(_Event, Chunk) ->
    case erlfs.store_lib:store_chunk() of
	ok ->
	    {next_state, notifying_tracker, Chunk};
	{error, Reason} ->
	    {stop, {file, Reason}, Chunk#chunk.chunk_meta}
    end.

notifying_tracker(_Event, ChunkMeta) ->
    %% Tell a tracker that we have stored the chunk
    Trackers = erlfs.util:whereis_gen_server(erlfs.tracker_svr),
    case notify_tracker(Trackers, ChunkMeta) of
	ok -> {next_state, done, nostate};
	%% Try to alert a tracker until successful
	{error, notrackers} ->
	    {next_state, notifying_tracker, ChunkMeta}
    end.

%% States to get a chunk
getting_chunk(_Event, {From, Ref, ChunkMeta}) ->
    case erlfs.store_lib:get_chunk(ChunkMeta) of
	{ok, Chunk} ->
	    From ! {get_chunk, Ref, Chunk},
	    {ok, done, nostate};
	Error = {error, _Reason} -> 
	    From ! {error, Ref, Error},
	    {stop, Error, nostate}
    end.

%% Common states
done(_Event, State) ->
    {stop, done, State}.

%%--------------------------------------------------------------------
%% Function:
%% state_name(Event, From, State) -> {next_state, NextStateName, NextState} |
%%                                   {next_state, NextStateName, 
%%                                     NextState, Timeout} |
%%                                   {reply, Reply, NextStateName, NextState}|
%%                                   {reply, Reply, NextStateName, 
%%                                    NextState, Timeout} |
%%                                   {stop, Reason, NewState}|
%%                                   {stop, Reason, Reply, NewState}
%% Description: There should be one instance of this function for each
%% possible state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/2,3, the instance of this function with the same
%% name as the current state name StateName is called to handle the event.
%%--------------------------------------------------------------------
						%state_name(_Event, _From, State) ->
						%    Reply = ok,
						%    {reply, Reply, state_name, State}.

%%--------------------------------------------------------------------
%% Function: 
%% handle_event(Event, StateName, State) -> {next_state, NextStateName, 
%%						  NextState} |
%%                                          {next_state, NextStateName, 
%%					          NextState, Timeout} |
%%                                          {stop, Reason, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function: 
%% handle_sync_event(Event, From, StateName, 
%%                   State) -> {next_state, NextStateName, NextState} |
%%                             {next_state, NextStateName, NextState, 
%%                              Timeout} |
%%                             {reply, Reply, NextStateName, NextState}|
%%                             {reply, Reply, NextStateName, NextState, 
%%                              Timeout} |
%%                             {stop, Reason, NewState} |
%%                             {stop, Reason, Reply, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/2,3, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% Function: 
%% handle_info(Info,StateName,State)-> {next_state, NextStateName, NextState}|
%%                                     {next_state, NextStateName, NextState, 
%%                                       Timeout} |
%%                                     {stop, Reason, NewState}
%% Description: This function is called by a gen_fsm when it receives any
%% other message than a synchronous or asynchronous event
%% (or a system message).
%%--------------------------------------------------------------------
handle_info(_Info, StateName, State) ->
    {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, StateName, State) -> void()
%% Description:This function is called by a gen_fsm when it is about
%% to terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Function:
%% code_change(OldVsn, StateName, State, Extra) -> {ok, StateName, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
notify_tracker([Node|Trackers], ChunkMeta) ->
    %% Notify a tracker that this node has stored a chunk
    %% Try until we get a good tracker or we run out
    Message = {stored_chunk, ChunkMeta, node()},
    case gen_server:call({erlfs.tracker_svr, Node}, Message) of
	{ok, stored_chunk} ->
	    ok;
	_ ->
	    notify_tracker(Trackers, ChunkMeta)
    end;
notify_tracker([], _FileChunk) ->
    {error, notrackers}.