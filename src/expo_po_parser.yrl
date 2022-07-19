Nonterminals
  grammar
  obsolete_plural_message
  obsolete_singular_message
  only_comments
  pluralization
  pluralizations
  plural_message
  singular_message
  message
  messages
  message_meta.
Terminals
  comment
  msgctxt
  msgid
  msgid_plural
  msgstr
  obsolete
  plural_form
  previous
  str_lines.
Rootsymbol grammar.
Endsymbol '$end'.

grammar ->
  only_comments : {only_comments, '$1'}.
grammar ->
  messages : {messages, '$1'}.
grammar ->
  '$empty' : empty.

only_comments ->
  comment only_comments : [extract_simple_token('$1') | '$2'].
only_comments ->
  comment : [extract_simple_token('$1')].

messages ->
  message messages : ['$1' | '$2'].
messages ->
  message : ['$1'].

message ->
  obsolete_singular_message : '$1'.
message ->
  singular_message : '$1'.
message ->
  obsolete_plural_message : '$1'.
message ->
  plural_message : '$1'.

singular_message ->
  message_meta msgid str_lines msgstr str_lines : {
    extract_line('$2'),
    to_singular_message([
      {msgid, extract_simple_token('$3')},
      {msgstr, extract_simple_token('$5')}
      | group_meta('$1')
    ])
  }.
singular_message ->
  message_meta msgctxt str_lines msgid str_lines msgstr str_lines : {
    extract_line('$4'),
    to_singular_message([
      {msgctxt, extract_simple_token('$3')},
      {msgid, extract_simple_token('$5')},
      {msgstr, extract_simple_token('$7')}
      | group_meta('$1')
    ])
  }.

obsolete_singular_message ->
  message_meta obsolete msgid str_lines obsolete msgstr str_lines : {
    extract_line('$3'),
    to_singular_message([
      {obsolete, true},
      {msgid, extract_simple_token('$4')},
      {msgstr, extract_simple_token('$7')}
      | group_meta('$1')
    ])
  }.
obsolete_singular_message ->
  message_meta obsolete msgctxt str_lines obsolete msgid str_lines obsolete msgstr str_lines : {
    extract_line('$6'),
    to_singular_message([
      {obsolete, true},
      {msgctxt, extract_simple_token('$4')},
      {msgid, extract_simple_token('$7')},
      {msgstr, extract_simple_token('$10')}
      | group_meta('$1')
    ])
  }.

plural_message ->
  message_meta msgid str_lines msgid_plural str_lines pluralizations : {
    extract_line('$2'),
    to_plural_message([
      {msgid, extract_simple_token('$3')},
      {msgid_plural, extract_simple_token('$5')},
      {msgstr, maps:from_list('$6')}
      | group_meta('$1')
    ])
  }.
plural_message ->
  message_meta msgctxt str_lines msgid str_lines msgid_plural str_lines pluralizations : {
    extract_line('$4'),
    to_plural_message([
      {msgctxt, extract_simple_token('$3')},
      {msgid, extract_simple_token('$5')},
      {msgid_plural, extract_simple_token('$7')},
      {msgstr, maps:from_list('$8')}
      | group_meta('$1')
    ])
  }.

obsolete_plural_message ->
  message_meta obsolete msgid str_lines obsolete msgid_plural str_lines pluralizations : {
    extract_line('$3'),
    to_plural_message([
      {obsolete, true},
      {msgid, extract_simple_token('$4')},
      {msgid_plural, extract_simple_token('$7')},
      {msgstr, maps:from_list('$8')}
      | group_meta('$1')
    ])
  }.
obsolete_plural_message ->
  message_meta obsolete msgctxt str_lines obsolete msgid str_lines obsolete msgid_plural str_lines pluralizations : {
    extract_line('$6'),
    to_plural_message([
      {obsolete, true},
      {msgctxt, extract_simple_token('$4')},
      {msgid, extract_simple_token('$7')},
      {msgid_plural, extract_simple_token('$10')},
      {msgstr, maps:from_list('$11')}
      | group_meta('$1')
    ])
  }.

pluralizations ->
  pluralization : ['$1'].
pluralizations ->
  pluralization pluralizations : ['$1'|'$2'].

pluralization ->
  msgstr plural_form str_lines : {extract_simple_token('$2'), extract_simple_token('$3')}.

message_meta ->
  '$empty': [].
message_meta ->
  comment message_meta : [
    {comments, extract_simple_token('$1')}
    | '$2'
  ].
message_meta ->
  previous msgid str_lines previous msgid_plural str_lines message_meta : [
    {previous_messages, to_plural_message([{msgid, extract_simple_token('$3')}, {msgid_plural, extract_simple_token('$6')}])}
    | '$7'
  ].
message_meta ->
  previous msgid str_lines message_meta : [
    {previous_messages, to_singular_message([{msgid, extract_simple_token('$3')}])}
    | '$4'
  ].

Erlang code.

extract_simple_token({_Token, _Line, Value}) ->
  Value.

extract_line({_Token, Line}) ->
  Line.

to_singular_message(Fields) ->
  'Elixir.Kernel':struct('Elixir.Expo.Message.Singular', Fields).

to_plural_message(Fields) ->
  'Elixir.Kernel':struct('Elixir.Expo.Message.Plural', Fields).

group_meta(MetaFields) ->
  maps:to_list(
    % Use maps:groups_from_list when supporting OTP >= 25 exclusively
    lists:foldr(
      fun({Key, Value}, Acc) ->
        maps:update_with(Key, fun(Cur) -> [Value | Cur] end, [Value], Acc)
      end,
      #{},
      MetaFields
    )
  ).
