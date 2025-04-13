module regex;

import std::collections::list;
import std::collections::map;
import std::core::dstring;
import std::core::string;
import std::io;
import std::os;

alias StringList = List { String };

struct RepeatPayload {
    int min;
    int max;
    Token* token;
}

fn ParseContext parse(String regex)
{
    ParseContext ctx;

    while (ctx.pos < regex.len)
    {
        process(regex, &ctx);
        ctx.pos++;
    }

    return ctx;
}

fn void process(String regex, ParseContext* ctx)
{
    char ch = regex[ctx.pos];

    switch (ch)
    {
        case '(':
            ParseContext group_ctx =
            {
                .pos = ctx.pos
            };

            parse_group(regex, &group_ctx);
            ctx.tokens.push({
                .token_type = TokenType.GROUP,
                .value      = { .arr = group_ctx.tokens }
            });
        case '[':
            parse_bracket(regex, ctx);
        case '|':
            parse_or(regex, ctx);
        case '*':
        case '?':
        case '+':
            parse_repeat(regex, ctx);
        case '{':
            parse_repeat_specified(regex, ctx);
        default:
            ctx.tokens.push({
                .token_type = TokenType.LITERAL,
                .value      = { .ch = ch }
            });
    }
}

fn void parse_group(String regex, ParseContext* ctx)
{
   ctx.pos++;

   while (regex[ctx.pos] != ')')
   {
    process(regex, ctx);
    ctx.pos++;
   }
}

fn void parse_bracket(String regex, ParseContext* ctx)
{
    ctx.pos++;
    StringList literals;

    while (regex[ctx.pos] != ']')
    {
        char ch = regex[ctx.pos];

        if (ch == '-')
        {
            char next = regex[ctx.pos + 1];
            char prev = literals[literals.len() - 1][0];

            literals.set_at(literals.len() - 1, string::tformat("%c%c", prev, next));
        } else
        {
            literals.push(string::tformat("%c", ch));
        }

        ctx.pos++;
    }

    LiteralMap literals_set;

    foreach (l : literals)
    {
        for (char i = l[0]; i <= l[l.len - 1]; i++)
        {
            literals_set.set(i, true);
        }
    }

    ctx.tokens.push({
        .token_type = TokenType.BRACKET,
        .value = { .map = literals_set }
    });
}

fn void parse_or(String regex, ParseContext* ctx)
{
    ParseContext rhs_context =
    {
        .pos = ctx.pos + 1
    };

    while (rhs_context.pos < regex.len && regex[rhs_context.pos] != ')')
    {
        process(regex, &rhs_context);
        rhs_context.pos++;
    }

    Token left =
    {
        .token_type = TokenType.GROUP_UNCAPTURED,
        .value = { .arr = ctx.tokens }
    };

    Token right =
    {
        .token_type = TokenType.GROUP_UNCAPTURED,
        .value = { .arr = rhs_context.tokens }
    };

    ctx.pos = rhs_context.pos;

    TokenList new;
    TokenList new2;
    new.push(left);
    new.push(right);

    new.push({
        .token_type = TokenType.OR,
        .value = { .arr = new2 }
    });

    ctx.tokens = new;
}

const int REPEAT_INFINITY = -1;

fn void parse_repeat(String regex, ParseContext* ctx)
{
    char ch = regex[ctx.pos];
    int min, max;

    if (ch == '*')
    {
        min = 0;
        max = REPEAT_INFINITY;
    } else if (ch == '?')
    {
        min = 0;
        max = 1;
    } else
    {
        min = 1;
        max = REPEAT_INFINITY;
    }

    Token last_token = ctx.tokens.last()!!;

    ctx.tokens.set_at(ctx.tokens.len() - 1, {
        .token_type = TokenType.REPEAT,
        .value = { .rep = { min, max, &last_token } }
    });
}

fn void parse_repeat_specified(String regex, ParseContext* ctx)
{
    int start = ctx.pos + 1;

    while (regex[ctx.pos] != '}')
    {
        ctx.pos++;
    }

    String boundaries_str = regex[start..ctx.pos];
    String[] pieces = boundaries_str.tsplit(",");
    int min, max;

    if (pieces.len == 1)
    {
        int value = pieces[0].to_int()!!;
        min = max = value;
    } else if (pieces.len == 2)
    {
        int value = pieces[0].to_int()!!;
        min = value;

        if (pieces[1].trim() == "}")
        {
            max = REPEAT_INFINITY;
        } else
        {
            io::printn(pieces[1]);
            int value2 = pieces[1].to_int()!!;
            max = value2;
        }
    } else
    {
        io::eprintfn("There must be either 1 or 2 values specified for the quantifier: provided '%s'", boundaries_str);
        os::exit(1);
    }

//    if (pieces.len != 0)
//    {
//        min = pieces[0].to_integer(int)!!;
//
//        if (pieces.len == 1)
//        {
//
//        }
//
//        if (pieces.len > 1)
//        {
//            if (pieces[1] == "")
//            {
//                max = min;
//            } else
//            {
//                max = pieces[1].to_integer(int)!!;
//            }
//        } else
//        {
//            max = min;
//        }
//    }

    Token last_token = ctx.tokens.last()!!;

    ctx.tokens.set_at(ctx.tokens.len() - 1, {
        .token_type = TokenType.REPEAT,
        .value = { .rep = { min, max, &last_token } }
    });
}