module BuildAST

import AST;
import Parser;
import ParseTree;

// Construye el AST a partir del árbol sintáctico.
public AST::Init buildAST(Tree tree) =
    implode(#AST::Init, tree);

// Lee un archivo Objectilang (.ol) y construye su AST.
public AST::Init loadAST(loc source) =
    buildAST(parsearObjectilang(source));