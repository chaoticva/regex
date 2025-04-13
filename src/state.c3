module regex;

import std::collections::list;
import std::collections::map;
import std::io;
import std::os;

alias StateList = List { State* };
alias StateMap  = HashMap { char, StateList };

const char START_OF_TEXT = 1;
const char END_OF_TEXT   = 2;

fn char get_char(String input, int pos)
{
    if (pos >= input.len)
    {
        return END_OF_TEXT;
    }

    if (pos < 0)
    {
        return START_OF_TEXT;
    }

    return input[pos];
}

fn bool State.check(&self, String input, int pos)
{
    char ch = get_char(input, pos);

    if (ch == END_OF_TEXT && self.terminal)
    {
        return true;
    }

    StateList states = self.transitions.get(ch)!!;

    if (states.len() > 0)
    {
        State* next_state = states[0];

        if (next_state.check(input, pos + 1))
        {
            return true;
        }
    }

    StateList epsilon_states = self.transitions.get(EPSILON_CHAR)!!;
    foreach (state : epsilon_states)
    {
        if (state.check(input, pos))
        {
            return true;
        }

        if (ch == START_OF_TEXT && state.check(input, pos + 1))
        {
            return true;
        }
    }

    return false;
}

struct State
{
    bool start;
    bool terminal;
    StateMap transitions;
}

const char EPSILON_CHAR = 0;

fn State to_nfa(ParseContext* ctx)
{
    State[] states = token_to_nfa(&ctx.tokens[0]);
    State start_state = states[0];
    State end_state   = states[1];

    for (int i = 1; i < ctx.tokens.len(); i++)
    {
        State[] next = token_to_nfa(&ctx.tokens[i]);
        State start_next = states[0];
        State end_next   = states[1];

        end_state.transitions.get(EPSILON_CHAR).push(&start_next)!!;
        end_state = end_next;
    }

    StateList tmp_list;
    StateMap  tmp_map;
    tmp_list.push(&start_state);
    tmp_map.set(EPSILON_CHAR, tmp_list);

    State start =
    {
        .transitions = tmp_map,
        .start = true
    };
    State end =
    {
        .terminal = true
    };

    end_state.transitions.get(EPSILON_CHAR).push(&end)!!;

    return start;
}

fn State[] token_to_nfa(Token* t)
{
    State start;
    State end;

    io::printn(*t);

    switch (t.token_type)
    {
        case TokenType.LITERAL:
            char ch = t.value.ch;
            StateList tmp;
            tmp.push(&end);
            start.transitions.set(ch, tmp);
            break;
        case TokenType.OR:
            TokenList values = t.value.arr;
            Token left = values[0];
            Token right = values[1];

            State[] state1 = token_to_nfa(&left);
            State[] state2 = token_to_nfa(&right);

            StateList list1;
            list1.push(&state1[0]);
            list1.push(&state2[0]);

            StateList list2;
            list2.push(&end);

            start.transitions.set(EPSILON_CHAR, list1);
            state1[1].transitions.set(EPSILON_CHAR, list2);
            state2[1].transitions.set(EPSILON_CHAR, list2);

            break;
        case TokenType.BRACKET:
            LiteralMap literals = t.value.map;

            StateList list;
            list.push(&end);

            foreach (l : literals.keys(tmem))
            {
                start.transitions.set(l, list);
            }

            break;
        case TokenType.GROUP:
            TokenList tokens = t.value.arr;
            State[] states = token_to_nfa(&tokens[0]);
            start = states[0];
            end = states[1];

            for (int i = 1; i < tokens.len(); i++)
            {
                State[] new_states = token_to_nfa(&tokens[i]);
                State token_start = new_states[0];
                State token_end = new_states[1];

                end.transitions.get(EPSILON_CHAR).push(&token_start)!!;
                end = token_end;
            }
            break;
//        case TokenType.GROUP_UNCAPTURED:
//            TokenList tokens = t.value.arr;
//                State*[] states = token_to_nfa(&tokens[0]);
//                start = *states[0];
//                end = *states[1];
//
//                for (int i = 1; i < tokens.len(); i++)
//                {
//                    State*[] new_states = token_to_nfa(&tokens[i]);
//                    State* token_start = new_states[0];
//                    State* token_end = new_states[1];
//
//                    end.transitions.get(EPSILON_CHAR).push(token_start)!!;
//                    end = *token_end;
//                }
//            break;
        case TokenType.REPEAT:
            RepeatPayload p = t.value.rep;

            StateList list;
            list.push(&end);

            if (p.min == 0)
            {
                start.transitions.set(EPSILON_CHAR, list);
            }

            int copy_count;

            if (p.max == REPEAT_INFINITY)
            {
                if (p.min == 0)
                {
                    copy_count = 1;
                } else
                {
                    copy_count = p.min;
                }
            } else
            {
                copy_count = p.max;
            }

            State[] range = token_to_nfa(p.token);
            State from = range[0];
            State to = range[1];
            start.transitions.get(EPSILON_CHAR).push(&from)!!;

            for (int i = 2; i <= copy_count; i++)
            {
                State[] states = token_to_nfa(p.token);
                State s = states[0];
                State e = states[1];

                to.transitions.get(EPSILON_CHAR).push(&s)!!;

                from = s;
                to = e;

                if (i > p.min)
                {
                    s.transitions.get(EPSILON_CHAR).push(&end)!!;
                }
            }

            to.transitions.get(EPSILON_CHAR).push(&end)!!;

            if (p.max == REPEAT_INFINITY)
            {
                end.transitions.get(EPSILON_CHAR).push(&from)!!;
            }

            break;
        default:
            io::eprintn("unknown type of token");
            os::exit(1);
            break;
    }

    return { start, end };
}

fn void group(Token* t)
{
    TokenList tokens = t.value.arr;
    State[] states = token_to_nfa(&tokens[0]);
    State start = states[0];
    State end = states[1];

    for (int i = 1; i < tokens.len(); i++)
    {
        State[] new_states = token_to_nfa(&tokens[i]);
        State token_start = new_states[0];
        State token_end = new_states[1];

        end.transitions.get(EPSILON_CHAR).push(&token_start)!!;
        end = token_end;
    }
}