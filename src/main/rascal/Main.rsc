module Main

import AST;
import BuildAST;
import IO;
import String;

data RuntimeMethod
    = metodoRuntime(list[AST::Parameter] parameters, list[AST::Instruction] body)
    | metodoNoEncontrado();

data RuntimeValue
    = rvInt(int numero)
    | rvBool(bool booleano)
    | rvString(str texto)
    | rvChar(str caracter)
    | rvObject(str className, map[str, RuntimeValue] fields, map[str, RuntimeMethod] methods)
    | rvNull();

alias Environment = map[str, RuntimeValue];

public void ejecutar(loc archivo) {
    AST::Init programa = BuildAST::loadAST(archivo);
    println("Ejecutando programa Objectilang");
    ejecutarMain(programa);
}

public void ejecutarMain(AST::Init programa) {
    switch (programa) {
        case AST::init(AST::objs(objetos, metodos), AST::main(AST::instructions(instrucciones))): {
            Environment entorno = ();
            RuntimeValue resultado = rvNull();
            <entorno, resultado> = ejecutarInstrucciones(instrucciones, entorno, objetos, metodos);
        }
        default: {
            println("No se encontro el metodo main.");
        }
    }
}


tuple[Environment, RuntimeValue] ejecutarInstrucciones(
    list[AST::Instruction] instrucciones,
    Environment entorno,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    RuntimeValue ultimo = rvNull();
    for (AST::Instruction instruccion <- instrucciones) {
        <entorno, ultimo> = ejecutarInstruccion(instruccion, entorno, objetos, metodos);
    }
    return <entorno, ultimo>;
}

tuple[Environment, RuntimeValue] ejecutarInstruccion(
    AST::Instruction instruccion,
    Environment entorno,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    switch (instruccion) {
        case AST::declarationInstruction(AST::declaration(_, nombre, _, expresion)): {
            RuntimeValue valor = evaluarExpresion(expresion, entorno, objetos, metodos);
            entorno = entorno + (nombre: valor);
            return <entorno, valor>;
        }
        case AST::assignmentInstruction(AST::assignment(nombre, expresion)): {
            RuntimeValue valor = evaluarExpresion(expresion, entorno, objetos, metodos);
            entorno = entorno + (nombre: valor);
            return <entorno, valor>;
        }
        case AST::methodCallInstruction(llamada): {
            RuntimeValue valor = invocarMetodo(llamada, entorno, objetos, metodos);
            return <entorno, valor>;
        }
        case AST::printInstruction(AST::print(tipo, expresion)): {
            RuntimeValue valor = evaluarExpresion(expresion, entorno, objetos, metodos);
            switch (tipo) {
                case AST::printKind(): print(representar(valor));
                case AST::printlnKind(): println(representar(valor));
            }
            return <entorno, valor>;
        }
        case AST::ifInstruction(AST::ifExpr(condicion, entonces, sino)): {
            RuntimeValue prueba = evaluarExpresion(condicion, entorno, objetos, metodos);
            if (esVerdadero(prueba)) {
                RuntimeValue resultado = evaluarExpresion(entonces, entorno, objetos, metodos);
                return <entorno, resultado>;
            }
            RuntimeValue resultado = evaluarExpresion(sino, entorno, objetos, metodos);
            return <entorno, resultado>;
        }
        case AST::forInstruction(AST::forLoop(clave, valor, coleccion, cuerpo)): {
            RuntimeValue contenido = evaluarExpresion(coleccion, entorno, objetos, metodos);
            str texto = representar(contenido);
            list[str] pares = dividir(texto, ",");
            RuntimeValue ultimo = rvNull();
            for (str par <- pares) {
                list[str] partes = dividir(par, ":");
                if (contarStrings(partes) >= 2) {
                    entorno = entorno + (clave: rvString(String::trim(partes[0])));
                    entorno = entorno + (valor: rvString(String::trim(partes[1])));
                    <entorno, ultimo> = ejecutarInstruccion(cuerpo, entorno, objetos, metodos);
                }
            }
            return <entorno, ultimo>;
        }
        case AST::newInstruction(creationExpr): {
            RuntimeValue valor = crearInstancia(creationExpr, entorno, objetos, metodos);
            return <entorno, valor>;
        }
    }
    return <entorno, rvNull()>;
}


RuntimeValue evaluarExpresion(
    AST::Expression expresion,
    Environment entorno,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    switch (expresion) {
        case AST::literalExpr(literal):
            return evaluarLiteral(literal, entorno, objetos, metodos);

        case AST::variableExpr(nombre): {
            if (nombre in entorno) return entorno[nombre];
            return rvString(nombre);
        }

        case AST::newExpression(creationExpr):
            return crearInstancia(creationExpr, entorno, objetos, metodos);

        case AST::methodCallExpr(llamada):
            return invocarMetodo(llamada, entorno, objetos, metodos);

        case AST::paren(interna):
            return evaluarExpresion(interna, entorno, objetos, metodos);

        case AST::fieldAccess(objeto, campo): {
            RuntimeValue receptor = evaluarExpresion(objeto, entorno, objetos, metodos);
            return obtenerCampo(receptor, campo);
        }

        case AST::neg(argumento): {
            RuntimeValue valor = evaluarExpresion(argumento, entorno, objetos, metodos);
            switch (valor) {
                case rvBool(b): return rvBool(!b);
                default: return rvInt(-aEntero(valor));
            }
        }

        case AST::pow(izquierda, derecha): {
            int base = aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos));
            int exponente = aEntero(evaluarExpresion(derecha, entorno, objetos, metodos));
            return rvInt(potenciaEntera(base, exponente));
        }

        case AST::mul(izquierda, derecha):
            return rvInt(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) * aEntero(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::div(izquierda, derecha): {
            int divisor = aEntero(evaluarExpresion(derecha, entorno, objetos, metodos));
            if (divisor == 0) {
                println("Error: division por cero.");
                return rvNull();
            }
            return rvInt(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) / divisor);
        }

        case AST::modulo(izquierda, derecha): {
            int divisor = aEntero(evaluarExpresion(derecha, entorno, objetos, metodos));
            if (divisor == 0) {
                println("Error: modulo por cero.");
                return rvNull();
            }
            return rvInt(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) % divisor);
        }

        case AST::add(izquierda, derecha): {
            RuntimeValue izq = evaluarExpresion(izquierda, entorno, objetos, metodos);
            RuntimeValue der = evaluarExpresion(derecha, entorno, objetos, metodos);
            if (esConcatenable(izq) || esConcatenable(der)) {
                return rvString(representar(izq) + representar(der));
            }
            return rvInt(aEntero(izq) + aEntero(der));
        }

        case AST::sub(izquierda, derecha):
            return rvInt(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) - aEntero(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::lt(izquierda, derecha):
            return rvBool(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) < aEntero(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::gt(izquierda, derecha):
            return rvBool(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) > aEntero(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::le(izquierda, derecha):
            return rvBool(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) <= aEntero(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::ge(izquierda, derecha):
            return rvBool(aEntero(evaluarExpresion(izquierda, entorno, objetos, metodos)) >= aEntero(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::eq(izquierda, derecha):
            return rvBool(representar(evaluarExpresion(izquierda, entorno, objetos, metodos)) == representar(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::ne(izquierda, derecha):
            return rvBool(representar(evaluarExpresion(izquierda, entorno, objetos, metodos)) != representar(evaluarExpresion(derecha, entorno, objetos, metodos)));

        case AST::inOp(izquierda, derecha): {
            str buscado = representar(evaluarExpresion(izquierda, entorno, objetos, metodos));
            str contenedor = representar(evaluarExpresion(derecha, entorno, objetos, metodos));
            return rvBool(String::contains(contenedor, buscado));
        }

        case AST::andOp(izquierda, derecha): {
            bool izq = esVerdadero(evaluarExpresion(izquierda, entorno, objetos, metodos));
            bool der = esVerdadero(evaluarExpresion(derecha, entorno, objetos, metodos));
            return rvBool(izq && der);
        }

        case AST::orOp(izquierda, derecha): {
            bool izq = esVerdadero(evaluarExpresion(izquierda, entorno, objetos, metodos));
            bool der = esVerdadero(evaluarExpresion(derecha, entorno, objetos, metodos));
            return rvBool(izq || der);
        }

        case AST::arrow(izquierda, derecha): {
            bool izq = esVerdadero(evaluarExpresion(izquierda, entorno, objetos, metodos));
            bool der = esVerdadero(evaluarExpresion(derecha, entorno, objetos, metodos));
            return rvBool(!izq || der);
        }

        case AST::implies(izquierda, derecha): {
            bool izq = esVerdadero(evaluarExpresion(izquierda, entorno, objetos, metodos));
            bool der = esVerdadero(evaluarExpresion(derecha, entorno, objetos, metodos));
            return rvBool(!izq || der);
        }

        case AST::conditionalExpr(condicion, entonces, sino): {
            if (esVerdadero(evaluarExpresion(condicion, entorno, objetos, metodos))) {
                return evaluarExpresion(entonces, entorno, objetos, metodos);
            }
            return evaluarExpresion(sino, entorno, objetos, metodos);
        }
    }
    return rvNull();
}

RuntimeValue evaluarLiteral(
    AST::Literal literal,
    Environment entorno,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    switch (literal) {
        case AST::intLit(valor):
            return rvInt(String::toInt(valor));
        case AST::boolLit(AST::trueLit()):
            return rvBool(true);
        case AST::boolLit(AST::falseLit()):
            return rvBool(false);
        case AST::charLit(valor):
            return rvChar(quitarComillas(valor));
        case AST::strLit(valor):
            return rvString(interpolar(quitarComillas(valor), entorno));
    }
    return rvNull();
}


RuntimeValue crearInstancia(
    AST::NewExpression creacion,
    Environment entorno,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    switch (creacion) {
        case AST::newExpr(nombre, _, argumentos, bloquesOverride): {
            list[str] atributos = atributosDeObjeto(nombre, objetos);
            list[RuntimeValue] valores = evaluarArgumentosConstructor(argumentos, entorno, objetos, metodos);
            map[str, RuntimeValue] campos = ();
            int indice = 0;
            for (str atributo <- atributos) {
                RuntimeValue valor = rvNull();
                if (indice < contarValores(valores)) valor = valores[indice];
                campos = campos + (atributo: valor);
                indice = indice + 1;
            }
            map[str, RuntimeMethod] sobrescritos = crearMetodosSobrescritos(bloquesOverride);
            return rvObject(nombre, campos, sobrescritos);
        }
    }
    return rvNull();
}

list[str] atributosDeObjeto(str nombre, list[AST::Obj] objetos) {
    list[str] resultado = [];
    for (AST::Obj objeto <- objetos) {
        switch (objeto) {
            case AST::obj(nombreObjeto, _, cosas): {
                if (nombreObjeto == nombre) {
                    for (AST::Thing cosa <- cosas) {
                        switch (cosa) {
                            case AST::thing(_, constructores): {
                                for (AST::ConsOp constructor <- constructores) {
                                    switch (constructor) {
                                        case AST::consOp(primerNombre, _, restantes): {
                                            resultado = resultado + [primerNombre];
                                            for (tuple[str, AST::Type] atributo <- restantes) {
                                                resultado = resultado + [atributo[0]];
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
    }
    return resultado;
}

list[RuntimeValue] evaluarArgumentosConstructor(
    list[AST::ConstructorArg] constructores,
    Environment entorno,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    list[RuntimeValue] resultado = [];
    for (AST::ConstructorArg constructor <- constructores) {
        switch (constructor) {
            case AST::consArg(argumentos): {
                list[AST::Expression] expresiones = extraerExpresionesArgumentos(argumentos);
                for (AST::Expression expresion <- expresiones) {
                    resultado = resultado + [evaluarExpresion(expresion, entorno, objetos, metodos)];
                }
            }
        }
    }
    return resultado;
}

list[AST::Expression] extraerExpresionesArgumentos(list[AST::Arguments] grupos) {
    list[AST::Expression] resultado = [];
    for (AST::Arguments grupo <- grupos) {
        switch (grupo) {
            case AST::arguments(primero, restantes):
                resultado = resultado + [primero] + restantes;
        }
    }
    return resultado;
}

map[str, RuntimeMethod] crearMetodosSobrescritos(list[AST::OverrideBlock] bloques) {
    map[str, RuntimeMethod] resultado = ();
    for (AST::OverrideBlock bloque <- bloques) {
        switch (bloque) {
            case AST::overrideBlock(sobrescrituras): {
                for (AST::Override sobrescritura <- sobrescrituras) {
                    switch (sobrescritura) {
                        case AST::overrideDef(nombre, gruposParametros, _, cuerpo): {
                            list[AST::Parameter] parametros = extraerParametros(gruposParametros);
                            list[AST::Instruction] instrucciones = extraerInstrucciones([cuerpo]);
                            resultado = resultado + (nombre: metodoRuntime(parametros, instrucciones));
                        }
                    }
                }
            }
        }
    }
    return resultado;
}

RuntimeValue obtenerCampo(RuntimeValue receptor, str campo) {
    switch (receptor) {
        case rvObject(nombreClase, campos, _): {
            if (campo == "getClass") return rvString(nombreClase);
            if (campo in campos) return campos[campo];
            return rvString(campo);
        }
        case rvString(texto): {
            if (campo == "getSimpleName") return rvString(texto);
            if (campo == "getClass") return rvString("String");
            return rvString(campo);
        }
        default:
            return rvString(campo);
    }
}

RuntimeValue invocarMetodo(
    AST::MethodCall llamada,
    Environment entorno,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    switch (llamada) {
        case AST::methodCall(receptor, nombreMetodo, gruposArgumentos): {
            RuntimeValue instancia = rvNull();
            if (receptor in entorno) {
                instancia = entorno[receptor];
            } else {
                instancia = crearInstancia(AST::newExpr(receptor, [], [], []), entorno, objetos, metodos);
            }

            switch (instancia) {
                case rvObject(nombreClase, _, metodosInstancia): {
                        RuntimeMethod metodo = metodoNoEncontrado();
                        if (nombreMetodo in metodosInstancia) {
                            metodo = metodosInstancia[nombreMetodo];
                        } else {
                            metodo = buscarMetodo(nombreClase, nombreMetodo, objetos, metodos);
                        }

                        switch (metodo) {
                            case metodoRuntime(parametros, cuerpo): {
                                list[AST::Expression] expresiones = extraerExpresionesArgumentos(gruposArgumentos);
                                list[RuntimeValue] valores = [];
                                for (AST::Expression expresion <- expresiones) {
                                    valores = valores + [evaluarExpresion(expresion, entorno, objetos, metodos)];
                                }

                                Environment entornoMetodo = entorno;
                                int i = 0;
                                for (AST::Parameter parametro <- parametros) {
                                    switch (parametro) {
                                        case AST::parameter(nombreParametro, _): {
                                            RuntimeValue valorParametro = rvNull();
                                            if (i < contarValores(valores)) valorParametro = valores[i];
                                            entornoMetodo = entornoMetodo + (nombreParametro: valorParametro);
                                            i = i + 1;
                                        }
                                    }
                                }

                                RuntimeValue retorno = rvNull();
                                <entornoMetodo, retorno> = ejecutarInstrucciones(cuerpo, entornoMetodo, objetos, metodos);
                                return retorno;
                            }
                            case metodoNoEncontrado(): {
                                println("Error: no se encontro el metodo " + nombreMetodo + " para " + nombreClase + ".");
                                return rvNull();
                            }
                        }
                }
                default: {
                    println("Error: el receptor " + receptor + " no es un objeto.");
                    return rvNull();
                }
            }
        }
    }
    return rvNull();
}

RuntimeMethod buscarMetodo(
    str clase,
    str nombreMetodo,
    list[AST::Obj] objetos,
    list[AST::Metho] metodos
) {
    for (AST::Metho metodo <- metodos) {
        switch (metodo) {
            case AST::metho(claseMetodo, nombre, gruposParametros, _, cuerpo): {
                if (claseMetodo == clase && nombre == nombreMetodo && cuerpo != []) {
                    return metodoRuntime(extraerParametros(gruposParametros), extraerInstrucciones(cuerpo));
                }
            }
        }
    }

    str padre = buscarPadre(clase, objetos);
    if (padre != "" && padre != clase) {
        return buscarMetodo(padre, nombreMetodo, objetos, metodos);
    }
    return metodoNoEncontrado();
}

str buscarPadre(str clase, list[AST::Obj] objetos) {
    for (AST::Obj objeto <- objetos) {
        switch (objeto) {
            case AST::obj(nombre, extensiones, _): {
                if (nombre == clase) {
                    for (AST::Ext extension <- extensiones) {
                        switch (extension) {
                            case AST::ext(padre): return padre;
                        }
                    }
                }
            }
        }
    }
    return "";
}

list[AST::Parameter] extraerParametros(list[AST::Parameters] grupos) {
    list[AST::Parameter] resultado = [];
    for (AST::Parameters grupo <- grupos) {
        switch (grupo) {
            case AST::parameters(primero, restantes):
                resultado = resultado + [primero] + restantes;
        }
    }
    return resultado;
}

list[AST::Instruction] extraerInstrucciones(list[AST::Instructions] bloques) {
    list[AST::Instruction] resultado = [];
    for (AST::Instructions bloque <- bloques) {
        switch (bloque) {
            case AST::instructions(instrucciones):
                resultado = resultado + instrucciones;
        }
    }
    return resultado;
}


str interpolar(str texto, Environment entorno) {
    str resultado = "";
    int i = 0;
    int n = String::size(texto);

    while (i < n) {
        if (texto[i] == "$" && i + 1 < n) {
            if (texto[i + 1] == "{") {
                int relativo = String::findFirst(String::substring(texto, i + 2), "}");
                if (relativo >= 0) {
                    int fin = i + 2 + relativo;
                    str expresion = String::substring(texto, i + 2, fin);
                    resultado = resultado + resolverInterpolacion(expresion, entorno);
                    i = fin + 1;
                } else {
                    resultado = resultado + texto[i];
                    i = i + 1;
                }
            } else {
                int fin = i + 1;
                while (fin < n && String::rexpMatch(texto[fin], "[a-zA-Z0-9_]")) {
                    fin = fin + 1;
                }
                if (fin > i + 1) {
                    str nombre = String::substring(texto, i + 1, fin);
                    if (nombre in entorno) resultado = resultado + representar(entorno[nombre]);
                    else resultado = resultado + nombre;
                    i = fin;
                } else {
                    resultado = resultado + texto[i];
                    i = i + 1;
                }
            }
        } else {
            resultado = resultado + texto[i];
            i = i + 1;
        }
    }
    return resultado;
}

str resolverInterpolacion(str expresion, Environment entorno) {
    list[str] partes = dividir(expresion, ".");
    if (contarStrings(partes) == 0) return expresion;

    RuntimeValue actual = rvString(partes[0]);
    if (partes[0] in entorno) actual = entorno[partes[0]];

    int i = 1;
    while (i < contarStrings(partes)) {
        actual = obtenerCampo(actual, partes[i]);
        i = i + 1;
    }
    return representar(actual);
}

str quitarComillas(str texto) {
    int n = String::size(texto);
    if (n >= 2) return String::substring(texto, 1, n - 1);
    return texto;
}

str representar(RuntimeValue valor) {
    switch (valor) {
        case rvInt(numero): return "<numero>";
        case rvBool(booleano): {
            if (booleano) return "true";
            return "false";
        }
        case rvString(texto): return texto;
        case rvChar(caracter): return caracter;
        case rvObject(nombreClase, _, _): return nombreClase;
        case rvNull(): return "null";
    }
    return "null";
}

int aEntero(RuntimeValue valor) {
    switch (valor) {
        case rvInt(numero): return numero;
        case rvBool(booleano): {
            if (booleano) return 1;
            return 0;
        }
        case rvString(texto): return String::toInt(texto);
        case rvChar(caracter): return String::toInt(caracter);
        default: return 0;
    }
}

bool esConcatenable(RuntimeValue valor) {
    switch (valor) {
        case rvString(_): return true;
        case rvChar(_): return true;
        default: return false;
    }
}

bool esVerdadero(RuntimeValue valor) {
    switch (valor) {
        case rvBool(booleano): return booleano;
        case rvInt(numero): return numero != 0;
        case rvString(texto): return texto == "true";
        default: return false;
    }
}

int potenciaEntera(int base, int exponente) {
    int resultado = 1;
    int i = 0;
    while (i < exponente) {
        resultado = resultado * base;
        i = i + 1;
    }
    return resultado;
}

int contarStrings(list[str] valores) {
    int cantidad = 0;
    for (str valor <- valores) cantidad = cantidad + 1;
    return cantidad;
}

int contarValores(list[RuntimeValue] valores) {
    int cantidad = 0;
    for (RuntimeValue valor <- valores) cantidad = cantidad + 1;
    return cantidad;
}

list[str] dividir(str texto, str separador) {
    list[str] resultado = [];
    int inicio = 0;
    int largo = String::size(texto);
    int largoSeparador = String::size(separador);

    if (largoSeparador == 0) return [texto];

    int relativo = String::findFirst(String::substring(texto, inicio), separador);
    while (relativo >= 0) {
        int posicion = inicio + relativo;
        resultado = resultado + [String::substring(texto, inicio, posicion)];
        inicio = posicion + largoSeparador;
        if (inicio > largo) inicio = largo;
        relativo = String::findFirst(String::substring(texto, inicio), separador);
    }
    resultado = resultado + [String::substring(texto, inicio, largo)];
    return resultado;
}
