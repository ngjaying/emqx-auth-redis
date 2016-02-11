%%--------------------------------------------------------------------
%% Copyright (c) 2015-2016 Feng Lee <feng@emqtt.io>.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
%%--------------------------------------------------------------------

%% @doc Authentication with Redis.
-module(emqttd_auth_redis).

-behaviour(emqttd_auth_mod).

-include("../../../include/emqttd.hrl").

-export([init/1, check/3, description/0]).

-record(state, {auth_cmd, hash_type}).

-define(UNDEFINED(S), (S =:= undefined orelse S =:= <<>>)).

init({AuthCmd, HashType}) -> 
    {ok, #state{auth_cmd = AuthCmd, hash_type = HashType}}.

check(#mqtt_client{username = Username}, Password, _State)
    when ?UNDEFINED(Username) orelse ?UNDEFINED(Password) ->
    {error, username_or_passwd_undefined};

check(#mqtt_client{username = Username}, Password,
      #state{auth_cmd = AuthCmd, hash_type = HashType}) ->
    case emqttd_redis_client:query(repl_var(AuthCmd, Username)) of
        {ok, undefined} ->
            {error, not_found};
        {ok, HashPass} ->
            check_pass(HashPass, Password, HashType);
        {error, Error} ->
            {error, Error}
    end.

description() -> "Authentication with Redis".

check_pass(PassHash, Password, HashType) ->
    case PassHash =:= hash(HashType, Password) of
        true  -> ok;
        false -> {error, password_error}
    end.

hash(Type, Password) ->
    emqttd_auth_mod:passwd_hash(Type, Password).

repl_var(AuthCmd, Username) ->
    [re:replace(Token, "%u", Username, [global, {return, binary}]) || Token <- AuthCmd].

