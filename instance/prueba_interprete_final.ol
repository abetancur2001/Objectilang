object Animal
object Dog extends Animal
object Food
object DogFood extends Food
object Cat

object Persona[T](val nombre: String, val inicial: Char, val edad: Integer, val dato: T)
object Transformer[-In, +Out]

Transformer.transform = method(input: In): Out

Cat.talk = method(): String {
    println("Cats meow")
}

method main {
    println("=== OBJETOS Y CAMPOS ===")
    val persona: Persona[Integer] = new Persona[Integer]("Ana", 'A', 19, 5)
    println(persona.nombre)
    println(persona.inicial)
    println(persona.edad)
    println(persona.dato)

    println("=== METODO DEFINIDO EN OBJETO ===")
    val gato = new Cat
    gato.talk()

    println("=== EXPRESIONES Y OPERADORES ===")
    val base: Integer = 4
    val total: Integer = base * 3 + 2
    println(total)
    println(total > base)
    println(2 ** 3)
    println(true and neg false)
    println(if total > 10 then "Mayor" else "Menor")

    println("=== FOR E INTERPOLACION ===")
    val ratings: String = "Inception:9,Interstellar:10,Avatar:8"
    for ((name, rating) <- ratings)
        println("Movie: $name, Rating: $rating")

    println("=== OVERRIDE Y RETORNO DE METODO ===")
    val feeder: Transformer[Animal, DogFood] = new Transformer[Animal, DogFood] {
        override transform(animal: Animal): DogFood = {
            println("Preparing specialized food for an animal...")
            new DogFood
        }
    }

    val resultantFood: Food = feeder.transform(new Dog)
    println("Resulting food type: ${resultantFood.getClass.getSimpleName}")
}
