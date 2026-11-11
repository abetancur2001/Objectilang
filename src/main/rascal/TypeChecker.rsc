module TypeChecker

extend analysis::typepal::TypePal;

import AST;
import Syntax;
import IO;
import ParseTree;
import BuildAST;

data AType
    = objectType(str nombre, list[AType] argumentos)
    | genericType(str nombre);

data IdRole
    = objectId()
    | typeParameterId();

// Referencias y tipos
set[str] referenciasTipo(AST::Type tipo, set[str] genericos) {
    switch (tipo) {
        case AST::basic(_):
            return {};

        case AST::named(nombre, argumentos): {
            set[str] referencias = {};

            if (!(nombre in genericos)) {
                referencias += {nombre};
            }

            for (AST::TypeArguments argumento <- argumentos) {
                switch (argumento) {
                    case AST::typeArgs(primero, restantes): {
                        referencias += referenciasTipo(primero, genericos);

                        for (AST::Type restante <- restantes) {
                            referencias += referenciasTipo(restante, genericos);
                        }
                    }
                }
            }

            return referencias;
        }
    }

    return {};
}

// Regla de existencia en atributos y herencia
public set[str] tiposAtributosInexistentes(AST::Init programa) {
    switch (programa) {
        case AST::init(AST::objs(objetos, _), _): {
            set[str] definidos = {};
            set[str] faltantes = {};

            for (AST::Obj objeto <- objetos) {
                switch (objeto) {
                    case AST::obj(nombre, _, _): {
                        definidos += {nombre};
                    }
                }
            }

            for (AST::Obj objeto <- objetos) {
                switch (objeto) {
                    case AST::obj(_, _, cosas): {
                        set[str] genericos = {};

                        for (AST::Thing contenido <- cosas) {
                            switch (contenido) {
                                case AST::thing(variancia, constructores): {
                                    switch (variancia) {
                                        case AST::variance(_, primero, restantes): {
                                            genericos += {primero};

                                            for (tuple[AST::Mod, str] parametro <- restantes) {
                                                genericos += {parametro[1]};
                                            }
                                        }
                                    }

                                    for (AST::ConsOp constructor <- constructores) {
                                        switch (constructor) {
                                            case AST::consOp(_, primerTipo, restantes): {
                                                faltantes += referenciasTipo(primerTipo, genericos) - definidos;

                                                for (tuple[str, AST::Type] atributo <- restantes) {
                                                    faltantes += referenciasTipo(atributo[1], genericos) - definidos;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            return faltantes;
        }
    }

    return {};
}

public set[str] padresInexistentes(AST::Init programa) {
    switch (programa) {
        case AST::init(AST::objs(objetos, _), _): {
            set[str] definidos = {};
            set[str] faltantes = {};

            for (AST::Obj objeto <- objetos) {
                switch (objeto) {
                    case AST::obj(nombre, _, _): {
                        definidos += {nombre};
                    }
                }
            }

            for (AST::Obj objeto <- objetos) {
                switch (objeto) {
                    case AST::obj(_, padres, _): {
                        for (AST::Ext padre <- padres) {
                            switch (padre) {
                                case AST::ext(nombrePadre): {
                                    if (!(nombrePadre in definidos)) {
                                        faltantes += {nombrePadre};
                                    }
                                }
                            }
                        }
                    }
                }
            }

            return faltantes;
        }
    }

    return {};
}

// Validacion de tipos declarados
set[str] genericosDeObjeto(str nombreObjeto, list[AST::Obj] objetos) {
    set[str] genericos = {};

    for (AST::Obj objeto <- objetos) {
        switch (objeto) {
            case AST::obj(nombre, _, cosas): {
                if (nombre == nombreObjeto) {
                    for (AST::Thing contenido <- cosas) {
                        switch (contenido) {
                            case AST::thing(variancia, _): {
                                switch (variancia) {
                                    case AST::variance(_, primero, restantes): {
                                        genericos += {primero};

                                        for (tuple[AST::Mod, str] parametro <- restantes) {
                                            genericos += {parametro[1]};
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return genericos;
}

set[str] tiposEnParametros(
    list[AST::Parameters] parametros,
    set[str] genericos
) {
    set[str] encontrados = {};

    for (AST::Parameters grupo <- parametros) {
        switch (grupo) {
            case AST::parameters(AST::parameter(_, primero), restantes): {
                encontrados += referenciasTipo(primero, genericos);

                for (AST::Parameter parametro <- restantes) {
                    switch (parametro) {
                        case AST::parameter(_, tipo): {
                            encontrados += referenciasTipo(tipo, genericos);
                        }
                    }
                }
            }
        }
    }

    return encontrados;
}

set[str] tiposEnInstruccion(
    AST::Instruction instruccion,
    set[str] genericos
) {
    set[str] encontrados = {};

    switch (instruccion) {
        case AST::declarationInstruction(
            AST::declaration(_, _, anotaciones, _)
        ): {
            for (AST::Type tipo <- anotaciones) {
                encontrados += referenciasTipo(tipo, genericos);
            }
        }

        case AST::forInstruction(
            AST::forLoop(_, _, _, cuerpo)
        ): {
            encontrados += tiposEnInstruccion(cuerpo, genericos);
        }
    }

    return encontrados;
}

set[str] tiposEnBloque(
    AST::Instructions bloque,
    set[str] genericos
) {
    set[str] encontrados = {};

    switch (bloque) {
        case AST::instructions(instrucciones): {
            for (AST::Instruction instruccion <- instrucciones) {
                encontrados += tiposEnInstruccion(instruccion, genericos);
            }
        }
    }

    return encontrados;
}

public set[str] tiposDeclaradosInexistentes(AST::Init programa) {
    switch (programa) {
        case AST::init(
            AST::objs(objetos, metodos),
            AST::main(AST::instructions(instruccionesMain))
        ): {
            set[str] definidos = {};
            set[str] faltantes = {};

            for (AST::Obj objeto <- objetos) {
                switch (objeto) {
                    case AST::obj(nombre, _, _): {
                        definidos += {nombre};
                    }
                }
            }

            for (AST::Instruction instruccion <- instruccionesMain) {
                faltantes += tiposEnInstruccion(instruccion, {});
            }

            for (AST::Metho metodo <- metodos) {
                switch (metodo) {
                    case AST::metho(
                        objeto,
                        _,
                        parametros,
                        retorno,
                        cuerpo
                    ): {
                        set[str] genericos = genericosDeObjeto(objeto, objetos);

                        faltantes += referenciasTipo(retorno, genericos);

                        faltantes += tiposEnParametros(parametros, genericos);

                        for (AST::Instructions bloque <- cuerpo) {
                            faltantes += tiposEnBloque(bloque, genericos);
                        }
                    }
                }
            }

            return faltantes - definidos;
        }
    }

    return {};
}

// Colectores de TypePal
void collect(
    current: (Obj) `object <Word name> <Ext? ext> <Thing? thing>`,
    Collector c
) {
    c.define(
        "<name>",
        objectId(),
        name,
        defType(objectType("<name>", []))
    );

    for (Ext padre <- ext) {
        collect(padre, c);
    }

    for (Thing contenido <- thing) {
        collect(contenido, c);
    }
}

void collect(
    current: (Ext) `extends <Word parent>`,
    Collector c
) {
    c.use(parent, {objectId()});
}

void collect(
    current: (Thing) `<Variance variance> <ConsOp? consOp>`,
    Collector c
) {
    c.enterScope(current);

    visit (variance) {
        case (Word) `<Word parametro>`: {
            c.define(
                "<parametro>",
                typeParameterId(),
                parametro,
                defType(genericType("<parametro>"))
            );
        }
    }

    for (ConsOp constructor <- consOp) {
        visit (constructor) {
            case (Type) `<Word nombreTipo> <TypeArguments? argumentos>`: {
                c.use(
                    nombreTipo,
                    {objectId(), typeParameterId()}
                );
            }
        }
    }

    c.leaveScope(current);
}

void collect(
    current: (Type) `<BasicType tipo>`,
    Collector c
) {
}

void collect(
    current: (Type) `<Word nombreTipo> <TypeArguments? argumentos>`,
    Collector c
) {
    c.use(
        nombreTipo,
        {objectId(), typeParameterId()}
    );

    visit (argumentos) {
        case (Type) `<Word nombreInterno> <TypeArguments? argumentosInternos>`: {
            c.use(
                nombreInterno,
                {objectId(), typeParameterId()}
            );
        }
    }
}

// Compatibilidad de tipos
str tipoConocidoExpresion(AST::Expression expresion) {
    switch (expresion) {
        case AST::literalExpr(AST::intLit(_)):
            return "Integer";

        case AST::literalExpr(AST::boolLit(_)):
            return "Boolean";

        case AST::literalExpr(AST::strLit(_)):
            return "String";

        case AST::literalExpr(AST::charLit(_)):
            return "Char";

        case AST::newExpression(AST::newExpr(nombre, _, _, _)):
            return nombre;

        case AST::paren(interno):
            return tipoConocidoExpresion(interno);
    }

    return "";
}

str nombreTipoDeclarado(AST::Type tipo) {
    switch (tipo) {
        case AST::basic(AST::integer()): return "Integer";
        case AST::basic(AST::boolean()): return "Boolean";
        case AST::basic(AST::string()): return "String";
        case AST::basic(AST::char()): return "Char";
        case AST::named(nombre, _): return nombre;
    }

    return "";
}

set[str] incompatibilidadesEnInstruccion(
    AST::Instruction instruccion,
    set[str] definidos
) {
    switch (instruccion) {
        case AST::declarationInstruction(
            AST::declaration(_, nombre, anotaciones, valor)
        ): {
            if (anotaciones != []) {
                str esperado = nombreTipoDeclarado(anotaciones[0]);
                str recibido = tipoConocidoExpresion(valor);

                bool tipoDefinido =
                    esperado in {"Integer", "Boolean", "String", "Char"}
                    || esperado in definidos;

                if (tipoDefinido && recibido != "" && esperado != recibido) {
                    return {
                        "<nombre>: se esperaba <esperado>, pero se recibió <recibido>"
                    };
                }
            }
        }

        case AST::forInstruction(AST::forLoop(_, _, _, cuerpo)):
            return incompatibilidadesEnInstruccion(cuerpo, definidos);
    }

    return {};
}


public set[str] declaracionesIncompatibles(AST::Init programa) {
    set[str] errores = {};

    switch (programa) {
        case AST::init(
            AST::objs(objetos, _),
            AST::main(AST::instructions(instrucciones))
        ): {
            set[str] definidos = {};

            for (AST::Obj objeto <- objetos) {
                switch (objeto) {
                    case AST::obj(nombre, _, _):
                        definidos += {nombre};
                }
            }

            for (AST::Instruction instruccion <- instrucciones) {
                errores += incompatibilidadesEnInstruccion(instruccion, definidos);
            }
        }
    }

    return errores;
}

// Compatibilidad de asignaciones
tuple[map[str,str], set[str]] revisarSecuenciaAsignaciones(
    list[AST::Instruction] instrucciones,
    map[str,str] entorno
) {
    set[str] errores = {};

    for (AST::Instruction instruccion <- instrucciones) {
        switch (instruccion) {
            case AST::declarationInstruction(
                AST::declaration(_, nombre, anotaciones, valor)
            ): {
                str tipo = "";

                if (anotaciones != []) {
                    tipo = nombreTipoDeclarado(anotaciones[0]);
                } else {
                    tipo = tipoConocidoExpresion(valor);
                }

                if (tipo != "") {
                    entorno[nombre] = tipo;
                }
            }

            case AST::assignmentInstruction(
                AST::assignment(nombre, valor)
            ): {
                if (nombre in entorno) {
                    str esperado = entorno[nombre];
                    str recibido = tipoConocidoExpresion(valor);

                    if (recibido != "" && esperado != recibido) {
                        errores += {
                            "<nombre>: se esperaba <esperado>, pero se recibió <recibido>"
                        };
                    }
                }
            }

            case AST::forInstruction(
                AST::forLoop(_, _, _, cuerpo)
            ): {
                tuple[map[str,str], set[str]] resultado =
                    revisarSecuenciaAsignaciones([cuerpo], entorno);

                entorno = resultado[0];
                errores += resultado[1];
            }
        }
    }

    return <entorno, errores>;
}

public set[str] asignacionesIncompatibles(AST::Init programa) {
    switch (programa) {
        case AST::init(
            _,
            AST::main(AST::instructions(instrucciones))
        ): {
            tuple[map[str,str], set[str]] resultado =
                revisarSecuenciaAsignaciones(instrucciones, ());

            return resultado[1];
        }
    }

    return {};
}

// Construccion del modelo TypePal
public TModel TModelFromTree(Tree pt) {
    if (pt has top) {
        pt = pt.top;
    }

    TypePalConfig config = tconfig();

    Collector collector = newCollector(
        "Objectilang",
        pt,
        config
    );

    // TypePal registra los genericos globalmente; el alcance real se valida desde el AST.
    set[str] genericosGlobales = {};

    visit (pt) {
        case (Thing) `<Variance variance> <ConsOp? consOp>`: {
            visit (variance) {
                case (Word) `<Word parametro>`: {
                    str nombreParametro = "<parametro>";

                    if (!(nombreParametro in genericosGlobales)) {
                        genericosGlobales += {nombreParametro};

                        collector.predefine(
                            nombreParametro,
                            typeParameterId(),
                            parametro,
                            defType(genericType(nombreParametro))
                        );
                    }
                }
            }
        }
    }

    collect(pt, collector);

    TModel modeloInicial = collector.run();

    Solver solver = newSolver(pt, modeloInicial);

    return solver.run();
}

// Analisis de archivos Objectilang
public void revisarArchivo(loc archivo) {
    println("=== ANALIZANDO OBJECTILANG ===");

    str codigo = readFile(archivo);

    Tree arbol = parse(
        #start[Init],
        codigo,
        archivo
    );

    TModel modelo = TModelFromTree(arbol);

    AST::Init programa = BuildAST::loadAST(archivo);

    set[str] faltantes = tiposAtributosInexistentes(programa);

    set[str] tiposFaltantes = tiposDeclaradosInexistentes(programa);

    set[str] padresFaltantes = padresInexistentes(programa);

    set[str] incompatibilidades = declaracionesIncompatibles(programa);

    set[str] erroresAsignacion = asignacionesIncompatibles(programa);

    println("=== REFERENCIAS EN ATRIBUTOS ===");

    if (faltantes == {}) {
        println("No se encontraron tipos inexistentes en atributos.");
    } else {
        for (str nombreTipo <- faltantes) {
            println("ERROR: Undefined object `<nombreTipo>` in attribute type.");
        }
    }

    println("=== REFERENCIAS EN HERENCIA ===");

    if (padresFaltantes == {}) {
        println("No se encontraron objetos padre inexistentes.");
    } else {
        for (str nombrePadre <- padresFaltantes) {
            println("ERROR: Undefined parent object `<nombrePadre>`.");
        }
    }

    println("=== TIPOS EN VARIABLES Y METODOS ===");

    if (tiposFaltantes == {}) {
        println("No se encontraron tipos inexistentes en declaraciones.");
    } else {
        for (str nombreTipo <- tiposFaltantes) {
            println("ERROR: Undefined type `<nombreTipo>` in declaration or method.");
        }
    }

    println("=== COMPATIBILIDAD DE TIPOS ===");

    if (incompatibilidades == {}) {
        println("No se encontraron incompatibilidades.");
    } else {
        for (str error <- incompatibilidades) {
            println("ERROR: <error>");
        }
    }

    println("=== COMPATIBILIDAD DE ASIGNACIONES ===");

    if (erroresAsignacion == {}) {
        println("No se encontraron incompatibilidades en asignaciones.");
    } else {
        for (str error <- erroresAsignacion) {
            println("ERROR: <error>");
        }
    }

    println("=== RESULTADOS DE TYPEPAL ===");
    println(getMessages(modelo));
}
