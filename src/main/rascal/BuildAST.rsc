module BuildAST

import AST;
import Syntax;
import ParseTree;
import IO;

// Construye el AST a partir del árbol sintáctico.
public AST::Init buildAST(Tree tree) =
    implode(#AST::Init, tree);

// Lee un archivo Objectilang y construye su AST.
public AST::Init loadAST(loc source) =
    buildAST(
        parse(#start[Init], readFile(source))
    );