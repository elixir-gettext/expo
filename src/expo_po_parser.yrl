Nonterminals grammar messages message pluralizations pluralization
             strings comments maybe_msgctxt.
Terminals str msgid msgid_plural msgctxt msgstr plural_form comment.
Rootsymbol grammar.

grammar ->
  messages : '$1'.

% A series of messages. It can be just comments (which are discarded and can
% be empty anyways) or comments followed by a message followed by other
% messages; in the latter case, comments are attached to the message
% that follows them.
messages ->
  comments : [{comments, '$1'}].
messages ->
  comments message messages : [add_comments_to_message('$2', '$1')|'$3'].

message ->
  maybe_msgctxt msgid strings msgstr strings : {message, #{
    comments       => [],
    msgctxt        => '$1',
    msgid          => '$3',
    msgstr         => '$5',
    po_source_line => extract_line('$2')
  }}.
message ->
  maybe_msgctxt msgid strings msgid_plural strings pluralizations : {plural_message, #{
    comments       => [],
    msgctxt        => '$1',
    msgid          => '$3',
    msgid_plural   => '$5',
    msgstr         => plural_forms_map_from_list('$6'),
    po_source_line => extract_line('$2')
  }}.

pluralizations ->
  pluralization : ['$1'].
pluralizations ->
  pluralization pluralizations : ['$1'|'$2'].

pluralization ->
  msgstr plural_form strings : {'$2', '$3'}.

strings ->
  str : [extract_simple_token('$1')].
strings ->
  str strings : [extract_simple_token('$1')|'$2'].

comments ->
  '$empty' : [].
comments ->
  comment comments : [extract_simple_token('$1')|'$2'].

maybe_msgctxt ->
  '$empty' : nil.
maybe_msgctxt ->
  msgctxt strings : '$2'.

Erlang code.

extract_simple_token({_Token, _Line, Value}) ->
  Value.

extract_line({_Token, Line}) ->
  Line.

plural_forms_map_from_list(Pluralizations) ->
  Tuples = lists:map(fun extract_plural_form/1, Pluralizations),
  maps:from_list(Tuples).

extract_plural_form({{plural_form, _Line, PluralForm}, String}) ->
  {PluralForm, String}.

add_comments_to_message({MessageType, Message}, Comments) ->
  {MessageType, maps:put(comments, Comments, Message)}.