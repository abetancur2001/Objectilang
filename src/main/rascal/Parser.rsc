module Parser

import Syntax;
import ParseTree;

start[Init] parsearObjectilang(loc archivo) = parse(#start[Init], archivo);