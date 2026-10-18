module Plugin

import ParseTree;
import util::Reflective;
import util::LanguageServer;
import Syntax;

PathConfig pcfg = getProjectPathConfig(|project://Objectilang|);

Language objLang = language(
    pcfg,
    "Objectilang",
    {"objl"},
    "Plugin",
    "contribs"
);

set[LanguageService] contribs() = {
    parsing(parser(#start[Init]))
};

void main() {
    registerLanguage(objLang);
}