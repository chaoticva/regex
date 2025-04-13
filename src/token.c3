module regex;

import std::collections::list;
import std::collections::map;

alias TokenList = List { Token };
alias LiteralMap = HashMap { char, bool };

enum TokenType
{
    GROUP,
    BRACKET,
    OR,
    REPEAT,
    LITERAL,
    GROUP_UNCAPTURED
}

struct Token
{
    TokenType token_type;
    union value
    {
        TokenList arr;
        char ch;
        LiteralMap map;
        RepeatPayload rep;
    }
}

struct ParseContext
{
    int pos;
    TokenList tokens;
}