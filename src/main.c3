module test;

import std::io;
import regex;

fn int main(String[] args)
{
    String test = "valid_email@example.com";
    String regex = "[a-zA-Z][a-zA-Z0-9_.]+@[a-zA-Z0-9]+.[a-zA-Z]{2,}";

    regex::ParseContext ctx = regex::parse(regex);

    State nfa = regex::to_nfa(&ctx);
    bool t = nfa.check(test, -1);

    io::printn(t);

    return 0;
}
